#Requires -Version 5.1
<#
.SYNOPSIS
    run_net_tests.ps1 - runs ONLY the M0-T0.4 network scenario (1 host + 3
    clients), without the unit suites. Wrapper for reviewers (D57); the full
    harness (tools/run_tests.ps1) runs this same scenario as its final step.
#>
$ErrorActionPreference = "Continue"
$repo_root = Split-Path -Parent $PSScriptRoot
$godot_bin = if ($env:GODOT_BIN) { $env:GODOT_BIN } else { "C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe" }
& $godot_bin --headless --path $repo_root -s res://src/tooling/run_net_scenario.gd ++ role=launcher
exit $LASTEXITCODE
