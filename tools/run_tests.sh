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
#      previous run would fool the exact-count guard into accepting a no-op run;
#      and without .gdignore Godot imports the report HTML PNGs on every
#      --import pass.
#   3. Run a headless import TWICE and strongly verify the global script
#      class cache: it must exist, be non-empty and contain the gdUnit4
#      runner/suite class entries (an empty cache once passed the old bare
#      existence check and the runner then died with 'Could not find type
#      "GdUnitTestCIRunner"'). If the check fails, run ONE extra import
#      pass, re-verify, then fail pointing at the cache file.
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
#      (fresh) JUnit results.xml under reports/ requiring EXACTLY EXPECTED_TESTS
#      discovered tests (r2.1: gdUnit4 returns 0 even when it discovers nothing,
#      and fresh clones have silently dropped tests).
#   7. Exit 0 only if every step passed.
#
# Exit codes: 0 = success. All other codes are propagated as delivered by the
# shell; POSIX truncates them to 0-255 (an exit(444) from the runner arrives as
# 188; under Git Bash, Windows crashes appear as 128+signal). Only 1 is
# reserved for the harness itself.

exit_infra_failure=1

# r2.1 (M2-GATE): the harness asserts the EXACT discovered test count, never
# a floor: gdUnit in fresh clones has silently dropped a suite's last test
# three times (T2.2 reviews 04/05, T2.3 review 02), and a ">= N" guard cannot
# see that. Bump this constant in the SAME commit that adds or removes a test.
expected_tests=288

# M0-T0.4 (D57): the network multi-instance scenario runs as a final step;
# --skip-net skips it to iterate over the unit tests only.
skip_net=0
for arg in "$@"; do
    case "$arg" in
        --skip-net) skip_net=1 ;;
    esac
done

log_step() {
    printf '\n=== %s ===\n' "$1"
}

fail() {
    printf 'ERROR: %s\n' "$1" >&2
    exit "$exit_infra_failure"
}

# Strong check: the file must exist, be non-empty and contain the gdUnit4
# runner/suite class entries. A bare existence check once passed an EMPTY
# cache and the runner then died with 'Could not find type
# "GdUnitTestCIRunner"'. No line counting: it changes when test/ goes.
class_cache_ok() {
    [ -f "$cache_file" ] && [ -s "$cache_file" ] \
        && grep -qF '"class": &"GdUnitTestCIRunner"' "$cache_file" \
        && grep -qF '"class": &"GdUnitTestSuite"' "$cache_file"
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
        # The BOM strip is POSIX (printf octal + prefix removal): GNU sed's
        # \xHH escapes are not understood by the BSD sed on macOS (m-2.3).
        godot_bin="$(head -n 1 "$godot_bin_file" | tr -d '\r\n')"
        bom="$(printf '\357\273\277')"
        godot_bin="${godot_bin#"$bom"}"
        godot_bin="$(printf '%s' "$godot_bin" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s/^[\"']//; s/[\"']\$//")"
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
# clean slate the exact-count guard below would read a stale results.xml from a
# previous run and approve a silent no-op (with an exact count a stale report
# from a bounded run would instead FAIL the run: keeping reports/ clean matters
# even more now).
if [ -d "$reports_dir" ]; then
    rm -rf "$reports_dir"
    printf 'Deleted previous reports: %s\n' "$reports_dir"
    # rm -rf does not stop on a locked file; the exact-count guard below needs a
    # guaranteed fresh report, so a surviving directory is fatal.
    if [ -d "$reports_dir" ]; then
        fail "Could not delete reports directory: $reports_dir (a locked file?). Delete it manually and re-run."
    fi
fi
mkdir -p "$reports_dir"
# Without this marker Godot scans and imports reports/ (report HTML PNGs) on
# every --import pass.
if [ ! -f "$reports_dir/.gdignore" ]; then
    : > "$reports_dir/.gdignore"
fi
printf 'Reports directory ready: %s (with .gdignore)\n' "$reports_dir"

# --- Step 3: headless import, two passes (plus one retry) ---------------------
log_step "Step 3/7: Headless import (two passes)"

for import_pass in 1 2; do
    printf -- '--- import pass %d/2 ---\n' "$import_pass"
    import_output="$("$godot_bin" --headless --path "$repo_root" --import 2>&1)"
    import_exit_code=$?
    printf '%s\n' "$import_output"
    printf 'import pass %d exit code: %d\n' "$import_pass" "$import_exit_code"
    if [ "$import_exit_code" -ne 0 ]; then
        printf 'FINDING: import pass %d exited with code %d (exact output above). Continuing: the strong class cache content check below is the source of truth.\n' "$import_pass" "$import_exit_code"
    fi
done

if ! class_cache_ok; then
    printf 'Class cache check failed after two import passes; running one more import pass.\n'
    retry_output="$("$godot_bin" --headless --path "$repo_root" --import 2>&1)"
    retry_exit_code=$?
    printf '%s\n' "$retry_output"
    printf 'import pass 3 exit code: %d\n' "$retry_exit_code"
    if [ "$retry_exit_code" -ne 0 ]; then
        printf 'FINDING: import pass 3 exited with code %d (exact output above). Continuing: the strong class cache content check below is the source of truth.\n' "$retry_exit_code"
    fi
    if ! class_cache_ok; then
        fail "Class cache invalid after three import passes: $cache_file (it must exist, be non-empty and contain the GdUnitTestCIRunner/GdUnitTestSuite class entries; gdUnit4 discovery would find no suites)."
    fi
fi
printf 'Class cache verified: %s\n' "$cache_file"

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
printf 'Discovered tests: %s (expected exactly: %s)\n' "$discovered_tests" "$expected_tests"

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
if [ "$discovered_tests" -ne "$expected_tests" ]; then
    printf 'FAILURE: %s tests discovered, expected exactly %s (EXPECTED_TESTS in this file). gdUnit in fresh clones has silently dropped a suite'"'"'s last test three times (r2.1); if the suites were edited on purpose, bump EXPECTED_TESTS in the same commit.\n' "$discovered_tests" "$expected_tests"
    exit "$exit_infra_failure"
fi
printf 'SUCCESS: all tests passed and %s tests were discovered.\n' "$discovered_tests"

# --- Step 8: network multi-instance scenario (M0-T0.4, D57) ------------------
if [ "$skip_net" = "1" ]; then
    log_step "Step 8/8: Network scenario (SKIPPED via --skip-net)"
    printf 'Skipping the network scenario (--skip-net). Unit tests only.\n'
    exit 0
fi
log_step "Step 8/8: Network multi-instance scenario (1 host + 3 clients)"
# The scenario self-terminates on every path: each child has its own time cap
# and the launcher kills survivors at its deadline before aggregating (D58).
net_output="$(timeout 180 "$godot_bin" --headless --path "$repo_root" -s res://src/tooling/run_net_scenario.gd ++ role=launcher 2>&1)"
net_exit_code=$?
printf '%s\n' "$net_output"
printf 'net scenario exit code: %d\n' "$net_exit_code"
if [ "$net_exit_code" -ne 0 ]; then
    printf 'FAILURE: network scenario failed (exit %d).\n' "$net_exit_code"
    exit "$net_exit_code"
fi
printf 'SUCCESS: network scenario passed (1 host + 3 clients).\n'
exit 0
