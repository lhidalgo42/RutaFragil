#!/usr/bin/env bash
# run_net_tests.sh - runs ONLY the M0-T0.4 network scenario (1 host + 3
# clients), without the unit suites. Wrapper for reviewers (D57); the full
# harness (tools/run_tests.sh) runs this same scenario as its final step.
set -u
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "$script_dir")"
godot_bin="${GODOT_BIN:-}"
if [ -z "$godot_bin" ]; then
    case "$(uname -s)" in
        Darwin*) godot_bin="/Applications/Godot.app/Contents/MacOS/Godot" ;;
        *) godot_bin='C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' ;;
    esac
fi
exec timeout 180 "$godot_bin" --headless --path "$repo_root" -s res://src/tooling/run_net_scenario.gd ++ role=launcher
