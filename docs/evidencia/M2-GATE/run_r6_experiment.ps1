param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9_]+$')][string]$Name,
    [ValidateSet('on','off')][string]$Cargo = 'off',
    [int]$Seconds = 60,
    [switch]$WalkOnly
)
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$enginePath = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' }
$outputPath = 'res://docs/evidencia/M2-GATE/22_raw/' + $Name
$arguments = @('--headless','--path',$repoPath,'-s','res://src/tooling/run_net_scenario.gd',
    '++','mode=gate','role=launcher','experiment=1',('seconds=' + $Seconds),
    ('cargo=' + $Cargo),('walk_only=' + [int]$WalkOnly.IsPresent),
    'vsync=off','human=none','windowed=both',('output=' + $outputPath))
$context = [ordered]@{source_commit=(git -C $repoPath rev-parse HEAD);arguments=$arguments}
$process = New-Object Diagnostics.Process
$process.StartInfo.FileName = $enginePath
$process.StartInfo.Arguments = ($arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
$process.StartInfo.WorkingDirectory = $repoPath
$process.StartInfo.UseShellExecute = $false
$process.StartInfo.CreateNoWindow = $true
$process.StartInfo.RedirectStandardOutput = $true
$process.StartInfo.RedirectStandardError = $true
[void]$process.Start()
$outTask = $process.StandardOutput.ReadToEndAsync()
$errTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(($Seconds + 140) * 1000)) {
    $process.Kill()
    $context.exit = 124
} else {
    $context.exit = $process.ExitCode
}
$process.WaitForExit()
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot ($Name + '_launcher.log')),$outTask.Result,$utf8)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot ($Name + '_stderr.log')),$errTask.Result,$utf8)
$process.Dispose()
$context | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 (Join-Path $PSScriptRoot ($Name + '_context.json'))
Write-Output ($Name + '_EXIT=' + $context.exit)
exit $context.exit
