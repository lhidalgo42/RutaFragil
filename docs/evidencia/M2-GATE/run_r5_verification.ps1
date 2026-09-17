param([ValidateSet('tests','strict','regressions')][string]$Mode = 'tests')
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$sourceCommit = (git -C $repoPath rev-parse HEAD)
$utf8 = New-Object Text.UTF8Encoding($false)
$results = @()

function Invoke-Recorded([string]$Name, [string]$Executable, [string[]]$Arguments, [int]$Deadline) {
    $child = New-Object Diagnostics.Process
    $child.StartInfo.FileName = $Executable
    $child.StartInfo.Arguments = ($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $child.StartInfo.WorkingDirectory = $repoPath
    $child.StartInfo.UseShellExecute = $false
    $child.StartInfo.CreateNoWindow = $true
    $child.StartInfo.RedirectStandardOutput = $true
    $child.StartInfo.RedirectStandardError = $true
    [void]$child.Start()
    $outTask = $child.StandardOutput.ReadToEndAsync()
    $errTask = $child.StandardError.ReadToEndAsync()
    $timedOut = -not $child.WaitForExit($Deadline * 1000)
    if ($timedOut) { $child.Kill() }
    $child.WaitForExit()
    $exitCode = if ($timedOut) { 124 } else { $child.ExitCode }
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot ($Name + '.log')), $outTask.Result, $utf8)
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot ($Name + '_stderr.log')), $errTask.Result, $utf8)
    $child.Dispose()
    return [ordered]@{ name=$Name; exit=$exitCode; timeout_s=$Deadline; timed_out=$timedOut; source_commit=$sourceCommit }
}

if ($Mode -eq 'tests') {
    foreach ($number in 1..3) {
        $result = Invoke-Recorded ('02_r5_run_' + $number) 'powershell.exe' @(
            '-NoProfile','-ExecutionPolicy','Bypass','-File','tools/run_tests.ps1') 700
        $results += $result
        [IO.File]::WriteAllText((Join-Path $PSScriptRoot '02_r5_runs.json'), ($results | ConvertTo-Json -Depth 5), $utf8)
        Write-Output ($result.name + '_EXIT=' + $result.exit)
        if ($result.exit -ne 0) { exit $result.exit }
    }
} elseif ($Mode -eq 'strict') {
    $projectPath = Join-Path $repoPath 'project.godot'
    $originalBytes = [IO.File]::ReadAllBytes($projectPath)
    try {
        $projectText = [IO.File]::ReadAllText($projectPath)
        $strictText = $projectText -replace '(gdscript/warnings/unsafe_(?:property_access|method_access|cast|call_argument))=1', '$1=2'
        if ([regex]::Matches($strictText, 'gdscript/warnings/unsafe_.*=2').Count -ne 4) { throw 'Expected four strict settings' }
        [IO.File]::WriteAllText($projectPath, $strictText, $utf8)
        $result = Invoke-Recorded '02_r5_unsafe' 'powershell.exe' @(
            '-NoProfile','-ExecutionPolicy','Bypass','-File','tools/run_tests.ps1') 700
        [IO.File]::WriteAllText((Join-Path $PSScriptRoot '02_r5_unsafe_result.json'), ($result | ConvertTo-Json), $utf8)
        Write-Output ('UNSAFE_EXIT=' + $result.exit)
    } finally {
        [IO.File]::WriteAllBytes($projectPath, $originalBytes)
    }
    exit $result.exit
} else {
    $enginePath = if ($env:GODOT_BIN) { $env:GODOT_BIN } elseif (Test-Path (Join-Path $repoPath 'tools/godot_bin.local')) {
        ([IO.File]::ReadAllText((Join-Path $repoPath 'tools/godot_bin.local'))).Trim()
    } else { 'C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' }
    foreach ($run in @(
        @{name='06_r5_demo'; args=@('--headless','--fixed-fps','60','--path','.','-s','res://src/tooling/run_demo.gd'); timeout=120},
        @{name='06_r5_handling'; args=@('--headless','--path','.','-s','res://src/tooling/probe_handling.gd'); timeout=120},
        @{name='06_r5_net_long'; args=@('--headless','--path','.','-s','res://src/tooling/run_net_scenario.gd','++','role=launcher','waypoints=16'); timeout=350}
    )) {
        $result = Invoke-Recorded $run.name $enginePath $run.args $run.timeout
        $results += $result
        [IO.File]::WriteAllText((Join-Path $PSScriptRoot '06_r5_results.json'), ($results | ConvertTo-Json -Depth 5), $utf8)
        Write-Output ($result.name + '_EXIT=' + $result.exit)
        if ($result.exit -ne 0) { exit $result.exit }
    }
}
exit 0
