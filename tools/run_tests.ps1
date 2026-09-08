#Requires -Version 5.1
<#
.SYNOPSIS
    run_tests.ps1 - headless test harness for Ruta Fragil (Godot 4.7.2 + gdUnit4).
.DESCRIPTION
    Implements plan M0-T0.1, section 5, step 6:
      1. Resolve GODOT_BIN (env var, then tools\godot_bin.local, then OS default)
         and verify the engine version starts with "4.7.2.stable".
      2. Run a headless import TWICE and verify the global script class cache.
         A non-zero import exit code is logged as a finding (with its exact
         output), not trusted as a failure: in 4.7 the shutdown with editor
         plugins enabled can return != 0 although the import completed
         (engine fix #120976 only landed in 4.8).
      3. Run gdUnit4 headless against res://tests with the exact plan command.
      4. Map the gdUnit4 exit code to a human-readable meaning.
      5. Parse the newest JUnit results.xml under reports\ and require at least
         3 discovered tests (gdUnit4 returns 0 even when it discovers nothing).
      6. Exit 0 only if every step passed.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
.NOTES
    Exit codes: 0 = success; 1 = harness/infrastructure failure; otherwise the
    gdUnit4 runner exit code is propagated (100, 101, 103, 104, 105, ...).
#>

$exit_infra_failure = 1

function Write-Step([string]$message) {
    Write-Host ""
    Write-Host "=== $message ==="
}

function Stop-WithError([string]$message) {
    Write-Host "ERROR: $message"
    exit $exit_infra_failure
}

# --- Locate the repo root (parent of tools\) -----------------------------------
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = Split-Path -Parent $script_dir
$cache_file = Join-Path $repo_root ".godot/global_script_class_cache.cfg"
$reports_dir = Join-Path $repo_root "reports"

# --- Step 1: resolve GODOT_BIN and verify the engine version -------------------
Write-Step "Step 1/6: Resolve Godot binary and verify version"

$godot_bin = $env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($godot_bin)) {
    $godot_bin_file = Join-Path $script_dir "godot_bin.local"
    if (Test-Path $godot_bin_file) {
        $godot_bin = (Get-Content $godot_bin_file -First 1).Trim()
        Write-Host "GODOT_BIN read from tools\godot_bin.local"
    }
}
if ([string]::IsNullOrWhiteSpace($godot_bin)) {
    $is_macos = $false
    $is_linux = $false
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $is_macos = $IsMacOS
        $is_linux = $IsLinux
    }
    if ($is_macos) {
        $godot_bin = "/Applications/Godot.app/Contents/MacOS/Godot"
    }
    elseif (-not $is_linux) {
        $godot_bin = "C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
    }
    else {
        Stop-WithError "No default Godot binary path for this OS (Linux). Set `$env:GODOT_BIN or create tools\godot_bin.local."
    }
    Write-Host "GODOT_BIN resolved to OS default"
}
Write-Host "Godot binary: $godot_bin"

if (-not (Test-Path $godot_bin)) {
    Stop-WithError "Godot binary not found at '$godot_bin'. Set `$env:GODOT_BIN or create tools\godot_bin.local (decision D39)."
}

$version_output = & $godot_bin --version 2>$null | Select-Object -First 1
if ($null -eq $version_output) {
    $version_output = ""
}
$version_output = "$version_output".Trim()
Write-Host "godot --version: $version_output"
if (-not $version_output.StartsWith("4.7.2.stable")) {
    Stop-WithError "Engine version must start with '4.7.2.stable' but got '$version_output'. Aborting (rule: only 4.7.x patches, pinned to 4.7.2)."
}

# --- Step 2: headless import, two passes ---------------------------------------
Write-Step "Step 2/6: Headless import (two passes)"

foreach ($import_pass in 1..2) {
    Write-Host "--- import pass $import_pass/2 ---"
    $import_output = & $godot_bin --headless --path $repo_root --import 2>&1 | Out-String
    $import_exit_code = $LASTEXITCODE
    Write-Host $import_output
    Write-Host "import pass $import_pass exit code: $import_exit_code"
    if ($import_exit_code -ne 0) {
        Write-Host "FINDING: import pass $import_pass exited with code $import_exit_code (exact output above). Continuing: the class cache check below is the source of truth."
    }
}

if (-not (Test-Path $cache_file)) {
    Stop-WithError "Class cache missing after two import passes: $cache_file (gdUnit4 discovery would find no suites)."
}
Write-Host "Class cache found: $cache_file"

# --- Step 3: run gdUnit4 against res://tests -----------------------------------
Write-Step "Step 3/6: Run gdUnit4 test suites"

Write-Host "Running: `"$godot_bin`" --headless --path `"$repo_root`" -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests -rd res://reports"
& $godot_bin --headless --path "$repo_root" -s -d --remote-debug "tcp://127.0.0.1:0" "res://addons/gdUnit4/bin/GdUnitCmdTool.gd" --ignoreHeadlessMode -c -a "res://tests" -rd "res://reports"
$runner_exit_code = $LASTEXITCODE

# --- Step 4: map the runner exit code ------------------------------------------
Write-Step "Step 4/6: gdUnit4 exit code"

switch ($runner_exit_code) {
    0       { $runner_meaning = "OK: all discovered tests passed" }
    100     { $runner_meaning = "TEST FAILURES: one or more tests failed" }
    101     { $runner_meaning = "WARNINGS: tests passed but warnings were reported" }
    103     { $runner_meaning = "HEADLESS REJECTED: gdUnit4 refused to run in headless mode" }
    104     { $runner_meaning = "UNSUPPORTED GODOT VERSION for this gdUnit4 build" }
    105     { $runner_meaning = "SCRIPT ERRORS during test discovery/execution" }
    default { $runner_meaning = "INFRASTRUCTURE FAILURE (unexpected exit code)" }
}
Write-Host "gdUnit4 exit code ${runner_exit_code}: $runner_meaning"

# --- Step 5: verify the discovered test count ----------------------------------
Write-Step "Step 5/6: Verify discovered test count in latest JUnit report"

$results_xml = $null
if (Test-Path $reports_dir) {
    $results_xml = Get-ChildItem -Path $reports_dir -Recurse -Filter "results.xml" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

$discovered_tests = 0
if (-not [string]::IsNullOrWhiteSpace($results_xml)) {
    Write-Host "Latest JUnit report: $results_xml"
    # The attribute is literally named "tests" (verified against
    # addons/gdUnit4/src/reporters/xml/JUnitXmlReportWriter.gd, ATTR_TESTS).
    # Sum the "tests" attribute of every <testsuite> element.
    $junit_doc = $null
    try {
        [xml]$junit_doc = Get-Content $results_xml -Raw
    }
    catch {
        Write-Host "WARNING: could not parse '$results_xml' as XML: $($_.Exception.Message)"
    }
    if ($null -ne $junit_doc) {
        $suite_nodes = $junit_doc.SelectNodes("//testsuite")
        foreach ($suite_node in $suite_nodes) {
            if ($null -ne $suite_node.tests) {
                $discovered_tests += [int]$suite_node.tests
            }
        }
        if ($discovered_tests -eq 0 -and $null -ne $junit_doc.testsuites -and $null -ne $junit_doc.testsuites.tests) {
            # Fallback: the root <testsuites> element also carries the total.
            $discovered_tests = [int]$junit_doc.testsuites.tests
        }
    }
}
else {
    Write-Host "WARNING: no results.xml found under $reports_dir"
}
Write-Host "Discovered tests: $discovered_tests (minimum required: 3)"

# --- Step 6: final verdict ------------------------------------------------------
Write-Step "Step 6/6: Final verdict"

if ($runner_exit_code -ne 0) {
    Write-Host "FAILURE: $runner_meaning"
    exit $runner_exit_code
}
if ($discovered_tests -lt 3) {
    Write-Host "FAILURE: only $discovered_tests tests discovered (< 3). gdUnit4 exits 0 even when it discovers nothing; refusing to accept a silent no-op run."
    exit $exit_infra_failure
}
Write-Host "SUCCESS: all tests passed and $discovered_tests tests were discovered."
exit 0
