#!/usr/bin/env bash
#
# run_tests.sh - headless test harness for Ruta Fragil (Godot 4.7.2 + gdUnit4).
#
# Implements plan M0-T0.1 v1.1, section 5, step 6:
#   1. Resolve GODOT_BIN (env var, then tools/godot_bin.local, then OS default)
#      and verify the engine version starts with "4.7.2.stable".
#   2. Clean reports/ and ensure reports/.gdignore exists BEFORE the import:
#      gdUnit4 exits 0 and writes NO report when it discovers zero tests
#      ("No test cases found, abort test run!"), so a stale results.xml from a
#      previous run would fool the >=3 test guard into accepting a no-op run;
#      and without .gdignore Godot imports the report HTML PNGs on every
#      --import pass.
#   3. Run a headless import TWICE and verify the global script class cache.
#      A non-zero import exit code is logged as a finding (with its exact
#      output), not trusted as a failure: in 4.7 the shutdown with editor
#      plugins enabled can return != 0 although the import completed
#      (engine fix #120976 only landed in 4.8).
#   4. Run gdUnit4 headless against res://tests. The command carries no -d /
#      --remote-debug flags (decision D40): port 0 produced two ERROR lines
#      per run, and script errors are still reported with their backtrace and
#      exit code 105 without them.
#   5. Map the gdUnit4 exit code to a human-readable meaning.
#   6. Fail if the runner output contains "No test cases found", and parse the
#      (fresh) JUnit results.xml under reports/ requiring at least 3
#      discovered tests (gdUnit4 returns 0 even when it discovers nothing).
#   7. Exit 0 only if every step passed.
#
# Exit codes: 0 = success; 1 = harness/infrastructure failure; otherwise the
# gdUnit4 runner exit code is propagated (100, 101, 103, 104, 105, ...).

exit_infra_failure=1

log_step() {
    printf '\n=== %s ===\n' "$1"
}

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit "$exit_infra_failure"
}

# --- Locate the repo root (parent of tools/) ----------------------------------
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "$script_dir")"
cache_file="$repo_root/.godot/global_script_class_cache.cfg"
reports_dir="$repo_root/reports"

# --- Step 1: resolve GODOT_BIN and verify the engine version ------------------
log_step "Step 1/7: Resolve Godot binary and verify version"

godot_bin="${GODOT_BIN:-}"
if [ -z "$godot_bin" ]; then
    godot_bin_file="$script_dir/godot_bin.local"
    if [ -f "$godot_bin_file" ]; then
        # Tolerate an empty file, a UTF-8 BOM, surrounding quotes, stray
        # whitespace and CRLF; fall through to the OS default on any of them.
        godot_bin="$(head -n 1 "$godot_bin_file" | tr -d '\r\n' | sed 's/^\xEF\xBB\xBF//' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sed "s/^[\"']//; s/[\"']\$//")"
        if [ -n "$godot_bin" ]; then
            printf 'GODOT_BIN read from tools/godot_bin.local\n'
        fi
    fi
fi
if [ -z "$godot_bin" ]; then
    case "$(uname -s)" in
        Darwin*)
            godot_bin="/Applications/Godot.app/Contents/MacOS/Godot"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            godot_bin='C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
            ;;
        *)
            fail "No default Godot binary path for this OS ($(uname -s)). Set GODOT_BIN or create tools/godot_bin.local."
            ;;
    esac
    printf 'GODOT_BIN resolved to OS default\n'
fi
printf 'Godot binary: %s\n' "$godot_bin"

if [ ! -f "$godot_bin" ]; then
    fail "Godot binary not found at '$godot_bin'. Set GODOT_BIN or create tools/godot_bin.local (decision D39)."
fi

version_output="$("$godot_bin" --version 2>/dev/null | head -n 1 | tr -d '\r')"
printf 'godot --version: %s\n' "$version_output"
case "$version_output" in
    4.7.2.stable*)
        ;;
    *)
        fail "Engine version must start with '4.7.2.stable' but got '$version_output'. Aborting (rule: only 4.7.x patches, pinned to 4.7.2)."
        ;;
esac

# --- Step 2: clean reports/ and ensure reports/.gdignore -----------------------
log_step "Step 2/7: Clean reports directory"
# gdUnit4 exits 0 and writes NO report when it discovers zero tests; without a
# clean slate the >=3 guard below would read a stale results.xml from a
# previous run and approve a silent no-op.
if [ -d "$reports_dir" ]; then
    rm -rf "$reports_dir"
    printf 'Deleted previous reports: %s\n' "$reports_dir"
fi
mkdir -p "$reports_dir"
# Without this marker Godot scans and imports reports/ (report HTML PNGs) on
# every --import pass.
if [ ! -f "$reports_dir/.gdignore" ]; then
    : > "$reports_dir/.gdignore"
fi
printf 'Reports directory ready: %s (with .gdignore)\n' "$reports_dir"

# --- Step 3: headless import, two passes --------------------------------------
log_step "Step 3/7: Headless import (two passes)"

for import_pass in 1 2; do
    printf -- '--- import pass %d/2 ---\n' "$import_pass"
    import_output="$("$godot_bin" --headless --path "$repo_root" --import 2>&1)"
    import_exit_code=$?
    printf '%s\n' "$import_output"
    printf 'import pass %d exit code: %d\n' "$import_pass" "$import_exit_code"
    if [ "$import_exit_code" -ne 0 ]; then
        printf 'FINDING: import pass %d exited with code %d (exact output above). Continuing: the class cache check below is the source of truth.\n' "$import_pass" "$import_exit_code"
    fi
done

if [ ! -f "$cache_file" ]; then
    fail "Class cache missing after two import passes: $cache_file (gdUnit4 discovery would find no suites)."
fi
printf 'Class cache found: %s\n' "$cache_file"

# --- Step 4: run gdUnit4 against res://tests ----------------------------------
log_step "Step 4/7: Run gdUnit4 test suites"

# No -d / --remote-debug on purpose (D40): script errors keep their backtrace
# and exit code 105 without them, and the run no longer prints two ERROR lines.
runner_args=(--headless --path "$repo_root" -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests -rd res://reports)
printf 'Running: "%s" %s\n' "$godot_bin" "${runner_args[*]}"
runner_output="$("$godot_bin" "${runner_args[@]}" 2>&1)"
runner_exit_code=$?
printf '%s\n' "$runner_output"

# --- Step 5: map the runner exit code -----------------------------------------
log_step "Step 5/7: gdUnit4 exit code"

case "$runner_exit_code" in
    0)   runner_meaning="OK: all discovered tests passed" ;;
    100) runner_meaning="TEST FAILURES: one or more tests failed" ;;
    101) runner_meaning="ORPHANS: tests passed but orphan nodes were detected" ;;
    103) runner_meaning="HEADLESS REJECTED: gdUnit4 refused to run in headless mode" ;;
    104) runner_meaning="UNSUPPORTED GODOT VERSION for this gdUnit4 build" ;;
    105) runner_meaning="SCRIPT ERRORS during test discovery/execution" ;;
    *)   runner_meaning="INFRASTRUCTURE FAILURE (unexpected exit code)" ;;
esac
printf 'gdUnit4 exit code %d: %s\n' "$runner_exit_code" "$runner_meaning"

# --- Step 6: verify the discovered test count ---------------------------------
log_step "Step 6/7: Verify discovered test count in the fresh JUnit report"

results_xml="$(ls -t "$reports_dir"/*/results.xml 2>/dev/null | head -n 1)"
if [ -z "$results_xml" ]; then
    results_xml="$(find "$reports_dir" -type f -name 'results.xml' 2>/dev/null | head -n 1)"
fi

discovered_tests=0
if [ -n "$results_xml" ] && [ -f "$results_xml" ]; then
    printf 'JUnit report: %s\n' "$results_xml"
    # The attribute is literally named "tests" (verified against
    # addons/gdUnit4/src/reporters/xml/JUnitXmlReportWriter.gd, ATTR_TESTS).
    # Sum the "tests" attribute of every <testsuite ...> element.
    discovered_tests="$(grep -oE '<testsuite [^>]*tests="[0-9]+"' "$results_xml" | grep -oE 'tests="[0-9]+"' | grep -oE '[0-9]+' | awk '{sum += $1} END {print sum + 0}')"
    if [ "$discovered_tests" -eq 0 ]; then
        # Fallback: the root <testsuites ...> element also carries the total.
        discovered_tests="$(grep -oE '<testsuites [^>]*tests="[0-9]+"' "$results_xml" | grep -oE 'tests="[0-9]+"' | grep -oE '[0-9]+' | head -n 1)"
        discovered_tests="${discovered_tests:-0}"
    fi
else
    printf 'WARNING: no results.xml found under %s\n' "$reports_dir"
fi
printf 'Discovered tests: %s (minimum required: 3)\n' "$discovered_tests"

# --- Step 7: final verdict -----------------------------------------------------
log_step "Step 7/7: Final verdict"

if [ "$runner_exit_code" -ne 0 ]; then
    printf 'FAILURE: %s\n' "$runner_meaning"
    exit "$runner_exit_code"
fi
if printf '%s' "$runner_output" | grep -qF 'No test cases found'; then
    printf "FAILURE: gdUnit4 reported 'No test cases found, abort test run!' (exit 0, no report written). Refusing to accept a silent no-op run.\n"
    exit "$exit_infra_failure"
fi
if [ "$discovered_tests" -lt 3 ]; then
    printf 'FAILURE: only %s tests discovered (< 3). gdUnit4 exits 0 even when it discovers nothing; refusing to accept a silent no-op run.\n' "$discovered_tests"
    exit "$exit_infra_failure"
fi
printf 'SUCCESS: all tests passed and %s tests were discovered.\n' "$discovered_tests"
exit 0
