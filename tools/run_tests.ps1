#Requires -Version 5.1
<#
.SYNOPSIS
    run_tests.ps1 - headless test harness for Ruta Fragil (Godot 4.7.2 + gdUnit4).
.DESCRIPTION
    Implements plan M0-T0.1 v1.1, section 5, step 6:
      1. Resolve GODOT_BIN (env var, then tools\godot_bin.local, then OS default)
         and verify the engine version starts with "4.7.2.stable".
      2. Clean reports\ and ensure reports\.gdignore exists BEFORE the import:
         gdUnit4 exits 0 and writes NO report when it discovers zero tests
         ("No test cases found, abort test run!"), so a stale results.xml from a
         previous run would fool the exact-count guard into accepting a no-op run;
         and without .gdignore Godot imports the report HTML PNGs on every
         --import pass.
      3. Run a headless import TWICE and strongly verify the global script
         class cache: it must exist, be non-empty and contain the gdUnit4
         runner/suite class entries (an empty cache once passed the old bare
         existence check and the runner then died with 'Could not find type
         "GdUnitTestCIRunner"'). If the check fails, run ONE extra import
         pass, re-verify, then fail pointing at the cache file.
         A non-zero import exit code is logged as a finding (with its exact
         output), not trusted as a failure: in 4.7 the shutdown with editor
         plugins enabled can return != 0 although the import completed
         (engine fix #120976 only landed in 4.8).
      4. Run gdUnit4 headless against res://tests. The command carries no -d /
         --remote-debug flags (decision D40): port 0 produced two ERROR lines
         per run, and script errors are still reported with their backtrace and
         exit code 105 without them.
      5. Map the gdUnit4 exit code to a human-readable meaning.
      6. Fail if the runner output contains "No test cases found", and parse the
         (fresh) JUnit results.xml under reports\ requiring EXACTLY
         EXPECTED_TESTS discovered tests (r2.1: gdUnit4 returns 0 even when it
         discovers nothing, and fresh clones have silently dropped tests).
      7. Exit 0 only if every step passed.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
.NOTES
    Exit codes: 0 = success; 1 = harness/infrastructure failure; otherwise the
    gdUnit4 runner exit code is propagated RAW: mapped codes (100, 101, 103,
    104, 105) and unmapped ones alike (e.g. 444, 134) pass through unchanged,
    never normalized to 1. Windows preserves the full 32-bit exit code.
#>

# PowerShell 5.1: never leave this at the user/profile default (m4).
# M0-T0.4 (D57): the network multi-instance scenario runs as a final step;
# -SkipNet skips it to iterate over the unit tests only.
param([switch]$SkipNet)

$ErrorActionPreference = "Continue"



# Reprinted Godot output must stay valid UTF-8 in captured evidence (m-2.1):
# PS 5.1 writes redirected output using the OEM console codepage (e.g. CP850),
# which would re-corrupt the accents that the -Encoding UTF8 reads below just
# decoded. Only touch the encoding when redirected, so an interactive console
# keeps rendering with its own codepage.
if ([Console]::IsOutputRedirected) {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
}

$exit_infra_failure = 1

# r2.1 (M2-GATE): the harness asserts the EXACT discovered test count, never
# a floor — gdUnit in fresh clones has silently dropped a suite's last test
# three times (T2.2 reviews 04/05, T2.3 review 02), and a ">= N" guard cannot
# see that. Bump this constant in the SAME commit that adds or removes a test.
$expected_tests = 257

function write_step([string]$message) {
    Write-Host ""
    Write-Host "=== $message ==="
}

function fail([string]$message) {
    Write-Host "ERROR: $message"
    exit $exit_infra_failure
}

function strip_ansi([string]$text) {
    # The Godot console build emits ANSI color codes even when redirected;
    # the PS 5.1 console does not interpret them when re-printing captured text.
    if ($null -eq $text) { return "" }
    return $text -replace ([char]27 + '\[[0-9;?]*[A-Za-z]'), ''
}

function invoke_process([string]$exe, [string[]]$arguments) {
    # Captures stdout and stderr through temp files instead of 2>&1 | Out-String:
    # Windows PowerShell 5.1 wraps natively redirected stderr lines in
    # NativeCommandError records, corrupting the captured output.
    $stdout_file = [System.IO.Path]::GetTempFileName()
    $stderr_file = [System.IO.Path]::GetTempFileName()
    $argument_line = ($arguments | ForEach-Object {
        if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
    }) -join ' '
    try {
        $process = Start-Process -FilePath $exe -ArgumentList $argument_line -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdout_file -RedirectStandardError $stderr_file -ErrorAction Stop
        # The catch below covers a process that never started; this null check
        # covers a started process that reports no exit code. The [int] cast is
        # only a type guarantee: [int]$null is 0, so the cast alone would turn
        # a missing exit code into a silent exit 0.
        if ($null -eq $process.ExitCode) {
            fail "Process '$exe' returned no exit code"
        }
        $exit_code = [int]$process.ExitCode
        $output = ""
        # Godot writes UTF-8; without -Encoding, PS 5.1 decodes as Windows-1252
        # and mangles non-ASCII characters (accents in paths, test names).
        $stdout_content = Get-Content $stdout_file -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $stderr_content = Get-Content $stderr_file -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        # stdout and stderr are concatenated without relative order.
        if ($null -ne $stdout_content) { $output += $stdout_content }
        if ($null -ne $stderr_content) { $output += $stderr_content }
        return @{ exit_code = $exit_code; output = $output }
    }
    catch {
        # A process that never started must fail here, not fall through with a
        # null exit code that prints FAILURE and then exits 0.
        fail "Could not start process '$exe' ($argument_line): $($_.Exception.Message)"
    }
    finally {
        Remove-Item $stdout_file, $stderr_file -Force -ErrorAction SilentlyContinue
    }
}

function test_class_cache([string]$path) {
    # Strong check: the file must exist, be non-empty and contain the gdUnit4
    # runner/suite class entries. A bare existence check once passed an EMPTY
    # cache and the runner then died with 'Could not find type
    # "GdUnitTestCIRunner"'. No line counting: it changes when test/ goes.
    if (-not (Test-Path $path)) { return $false }
    if ((Get-Item $path).Length -eq 0) { return $false }
    $has_runner = Select-String -Path $path -SimpleMatch '"class": &"GdUnitTestCIRunner"' -Quiet
    $has_suite = Select-String -Path $path -SimpleMatch '"class": &"GdUnitTestSuite"' -Quiet
    return ($has_runner -and $has_suite)
}

# --- Locate the repo root (parent of tools\) -----------------------------------
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = Split-Path -Parent $script_dir
$cache_file = Join-Path $repo_root ".godot/global_script_class_cache.cfg"
$reports_dir = Join-Path $repo_root "reports"

# --- Step 1: resolve GODOT_BIN and verify the engine version -------------------
write_step "Step 1/7: Resolve Godot binary and verify version"

$godot_bin = $env:GODOT_BIN
if ([string]::IsNullOrWhiteSpace($godot_bin)) {
    $godot_bin_file = Join-Path $script_dir "godot_bin.local"
    if (Test-Path $godot_bin_file) {
        # Tolerate an empty file, a UTF-8 BOM, surrounding quotes and stray
        # whitespace; fall through to the OS default on any of them.
        # -Encoding UTF8: without it PS 5.1 decodes as ANSI and a BOM-less file
        # with a non-ASCII path (e.g. C:\Users\Jose with accents) reads as
        # mojibake; the Trim([char]0xFEFF) below already covers the BOM case.
        $raw = Get-Content $godot_bin_file -First 1 -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($null -ne $raw) {
            $candidate = "$raw".Trim().Trim([char]0xFEFF).Trim(@('"', "'")).Trim()
            if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                $godot_bin = $candidate
                Write-Host "GODOT_BIN read from tools\godot_bin.local"
            }
        }
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
        fail "No default Godot binary path for this OS (Linux). Set `$env:GODOT_BIN or create tools\godot_bin.local."
    }
    Write-Host "GODOT_BIN resolved to OS default"
}
Write-Host "Godot binary: $godot_bin"

if (-not (Test-Path $godot_bin)) {
    fail "Godot binary not found at '$godot_bin'. Set `$env:GODOT_BIN or create tools\godot_bin.local (decision D39)."
}

$version_result = invoke_process $godot_bin @("--version")
$version_output = ""
if ($null -ne $version_result.output) {
    $version_output = (($version_result.output -split "\r?\n") | Select-Object -First 1).Trim()
}
Write-Host "godot --version: $version_output"
if (-not $version_output.StartsWith("4.7.2.stable")) {
    fail "Engine version must start with '4.7.2.stable' but got '$version_output'. Aborting (rule: only 4.7.x patches, pinned to 4.7.2)."
}

# --- Step 2: clean reports\ and ensure reports\.gdignore ------------------------
write_step "Step 2/7: Clean reports directory"
# gdUnit4 exits 0 and writes NO report when it discovers zero tests; without a
# clean slate the exact-count guard below would read a stale results.xml from a
# previous run and approve a silent no-op (with an exact count a stale report
# from a bounded run would instead FAIL the run: keeping reports\ clean matters
# even more now).
if (Test-Path $reports_dir) {
    Remove-Item -Recurse -Force $reports_dir
    Write-Host "Deleted previous reports: $reports_dir"
    # Remove-Item does not stop on a locked file; the exact-count guard below
    # needs a guaranteed fresh report, so a surviving directory is fatal.
    if (Test-Path $reports_dir) {
        fail "Could not delete reports directory: $reports_dir (a locked file?). Delete it manually and re-run."
    }
}
New-Item -ItemType Directory -Force $reports_dir | Out-Null
# Without this marker Godot scans and imports reports\ (report HTML PNGs) on
# every --import pass.
$reports_gdignore = Join-Path $reports_dir ".gdignore"
if (-not (Test-Path $reports_gdignore)) {
    New-Item -ItemType File -Force $reports_gdignore | Out-Null
}
Write-Host "Reports directory ready: $reports_dir (with .gdignore)"

# --- Step 3: headless import, two passes (plus one retry) ----------------------
write_step "Step 3/7: Headless import (two passes)"

foreach ($import_pass in 1..2) {
    Write-Host "--- import pass $import_pass/2 ---"
    $import_result = invoke_process $godot_bin @("--headless", "--path", $repo_root, "--import")
    Write-Host (strip_ansi $import_result.output)
    Write-Host "import pass $import_pass exit code: $($import_result.exit_code)"
    if ($import_result.exit_code -ne 0) {
        Write-Host "FINDING: import pass $import_pass exited with code $($import_result.exit_code) (exact output above). Continuing: the strong class cache content check below is the source of truth."
    }
}

if (-not (test_class_cache $cache_file)) {
    Write-Host "Class cache check failed after two import passes; running one more import pass."
    $retry_result = invoke_process $godot_bin @("--headless", "--path", $repo_root, "--import")
    Write-Host (strip_ansi $retry_result.output)
    Write-Host "import pass 3 exit code: $($retry_result.exit_code)"
    if ($retry_result.exit_code -ne 0) {
        Write-Host "FINDING: import pass 3 exited with code $($retry_result.exit_code) (exact output above). Continuing: the strong class cache content check below is the source of truth."
    }
    if (-not (test_class_cache $cache_file)) {
        fail "Class cache invalid after three import passes: $cache_file (it must exist, be non-empty and contain the GdUnitTestCIRunner/GdUnitTestSuite class entries; gdUnit4 discovery would find no suites)."
    }
}
Write-Host "Class cache verified: $cache_file"

# --- Step 4: run gdUnit4 against res://tests -----------------------------------
write_step "Step 4/7: Run gdUnit4 test suites"

# No -d / --remote-debug on purpose (D40): script errors keep their backtrace
# and exit code 105 without them, and the run no longer prints two ERROR lines.
$runner_arguments = @("--headless", "--path", $repo_root, "-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd", "--ignoreHeadlessMode", "-c", "-a", "res://tests", "-rd", "res://reports")
Write-Host "Running: `"$godot_bin`" $($runner_arguments -join ' ')"
$runner_result = invoke_process $godot_bin $runner_arguments
$runner_exit_code = $runner_result.exit_code
$runner_output = $runner_result.output
Write-Host (strip_ansi $runner_output)

# --- Step 5: map the runner exit code ------------------------------------------
write_step "Step 5/7: gdUnit4 exit code"

switch ($runner_exit_code) {
    0       { $runner_meaning = "OK: all discovered tests passed" }
    100     { $runner_meaning = "TEST FAILURES: one or more tests failed" }
    101     { $runner_meaning = "ORPHANS: tests passed but orphan nodes were detected" }
    103     { $runner_meaning = "HEADLESS REJECTED: gdUnit4 refused to run in headless mode" }
    104     { $runner_meaning = "UNSUPPORTED GODOT VERSION for this gdUnit4 build" }
    105     { $runner_meaning = "SCRIPT ERRORS during test discovery/execution" }
    default { $runner_meaning = "INFRASTRUCTURE FAILURE (unexpected exit code)" }
}
Write-Host "gdUnit4 exit code ${runner_exit_code}: $runner_meaning"

# --- Step 6: verify the discovered test count ----------------------------------
write_step "Step 6/7: Verify discovered test count in the fresh JUnit report"

$results_xml = Get-ChildItem -Path $reports_dir -Recurse -Filter "results.xml" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName

$discovered_tests = 0
if (-not [string]::IsNullOrWhiteSpace($results_xml)) {
    Write-Host "JUnit report: $results_xml"
    # The attribute is literally named "tests" (verified against
    # addons/gdUnit4/src/reporters/xml/JUnitXmlReportWriter.gd, ATTR_TESTS).
    # Sum the "tests" attribute of every <testsuite> element.
    $junit_doc = $null
    try {
        # gdUnit4 writes the JUnit XML as UTF-8 (m-2.1).
        [xml]$junit_doc = Get-Content $results_xml -Raw -Encoding UTF8
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
Write-Host "Discovered tests: $discovered_tests (expected exactly: $expected_tests)"

# --- Step 7: final verdict ------------------------------------------------------
write_step "Step 7/7: Final verdict"

if ($runner_exit_code -ne 0) {
    Write-Host "FAILURE: $runner_meaning"
    exit $runner_exit_code
}
if ($runner_output -match 'No test cases found') {
    Write-Host "FAILURE: gdUnit4 reported 'No test cases found, abort test run!' (exit 0, no report written). Refusing to accept a silent no-op run."
    exit $exit_infra_failure
}
if ($discovered_tests -ne $expected_tests) {
    Write-Host "FAILURE: $discovered_tests tests discovered, expected exactly $expected_tests (EXPECTED_TESTS in this file). gdUnit in fresh clones has silently dropped a suite's last test three times (r2.1); if the suites were edited on purpose, bump EXPECTED_TESTS in the same commit."
    exit $exit_infra_failure
}
Write-Host "SUCCESS: all tests passed and $discovered_tests tests were discovered."

# --- Step 8: network multi-instance scenario (M0-T0.4, D57) -----------------
if ($SkipNet) {
    write_step "Step 8/8: Network scenario (SKIPPED via -SkipNet)"
    Write-Host "Skipping the network scenario (-SkipNet). Unit tests only."
    exit 0
}
write_step "Step 8/8: Network multi-instance scenario (1 host + 3 clients)"
# The scenario self-terminates on every path: each child has its own time cap
# and the launcher kills survivors at its deadline before aggregating (D58).
$net_result = invoke_process $godot_bin @("--headless", "--path", $repo_root, "-s", "res://src/tooling/run_net_scenario.gd", "++", "role=launcher")
$net_output = $net_result.output
$net_exit_code = $net_result.exit_code
Write-Host $net_output
Write-Host "net scenario exit code: $net_exit_code"
if ($net_exit_code -ne 0) {
    Write-Host "FAILURE: network scenario failed (exit $net_exit_code)."
    exit $net_exit_code
}
Write-Host "SUCCESS: network scenario passed (1 host + 3 clients)."
exit 0
