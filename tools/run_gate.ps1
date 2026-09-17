#Requires -Version 5.1
param(
    [double]$Seconds = 300,
    [ValidateSet('client','host','none')][string]$Human = 'client',
    [ValidateSet('client','host','both','none')][string]$Windowed = 'both',
    [ValidateSet('on','off')][string]$VSync = 'off',
    [string]$Output = '',
    [string]$Precondition = '',
    [int]$Port = 47810
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$godotPath = $env:GODOT_BIN
if (-not $godotPath) {
    $localBin = Join-Path $PSScriptRoot 'godot_bin.local'
    if (Test-Path -LiteralPath $localBin) {
        $godotPath = (Get-Content -LiteralPath $localBin -Raw).Trim()
    } else {
        $godotPath = 'C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
    }
}
if (-not (Test-Path -LiteralPath $godotPath)) { throw "Godot binary missing: $godotPath" }
if (-not $Output) { $Output = 'user://gate/run_' + (Get-Date -Format 'yyyyMMdd_HHmmss') }
$gateArgs = @('--headless','--path',$projectPath,'--log-file','user://gate_launcher.log',
    '-s','res://src/tooling/run_net_scenario.gd','++','mode=gate','role=launcher',
    ('seconds=' + $Seconds.ToString([Globalization.CultureInfo]::InvariantCulture)),
    ('human=' + $Human),('windowed=' + $Windowed),('vsync=' + $VSync),('output=' + $Output),('port=' + $Port),
    ('precondition=' + $Precondition))
$quotedArgs = $gateArgs | ForEach-Object { '"' + $_.Replace('"','\"').TrimEnd('\') + '"' }
$gateProcess = Start-Process -FilePath $godotPath -ArgumentList $quotedArgs -WindowStyle Hidden -PassThru
try {
    # Retain the handle even if a short preflight exits before the first wait.
    $null = $gateProcess.Handle
    if (-not $gateProcess.WaitForExit([int](($Seconds + 140) * 1000))) {
        $gateProcess.Kill()
        throw 'Gate launcher exceeded the external deadline; see its log.'
    }
    $gateProcess.Refresh()
    if ($null -eq $gateProcess.ExitCode) { throw 'Gate launcher exit code unavailable; refusing an implicit success.' }
    Write-Output ('Gate output: ' + $Output)
    Write-Output ('Gate exit: ' + $gateProcess.ExitCode + ' (0 passed, 1 failed/unverified, 2 invalid, 3 D96 stop)')
    exit $gateProcess.ExitCode
} finally {
    $gateProcess.Dispose()
}
