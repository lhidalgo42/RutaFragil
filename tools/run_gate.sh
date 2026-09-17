#!/usr/bin/env bash
set -euo pipefail
project_path="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_path="${GODOT_BIN:-}"
if [[ -z "$godot_path" && -f "$project_path/tools/godot_bin.local" ]]; then
    godot_path="$(tr -d '\r\n' < "$project_path/tools/godot_bin.local")"
fi
if [[ -z "$godot_path" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
        godot_path="/Applications/Godot.app/Contents/MacOS/Godot"
    else
        godot_path="godot"
    fi
fi
seconds="${GATE_SECONDS:-300}"
output="${GATE_OUTPUT:-user://gate/run_$(date +%Y%m%d_%H%M%S)}"
# Additional key=value arguments override these defaults in GateConfig.parse.
deadline_seconds="$seconds"
for argument in "$@"; do
    case "$argument" in seconds=*) deadline_seconds="${argument#seconds=}" ;; esac
done
# Match GateConfig's minimum duration; the watchdog does not depend on Godot ticks.
deadline="$(awk -v seconds="$deadline_seconds" 'BEGIN { if (seconds < 1) seconds=1; print int(seconds+140.999) }')"
"$godot_path" --headless --path "$project_path" --log-file user://gate_launcher.log \
    -s res://src/tooling/run_net_scenario.gd ++ mode=gate role=launcher \
    "seconds=$seconds" human=client "output=$output" "$@" &
gate_pid=$!
timed_out=0
trap 'timed_out=1; kill -TERM "$gate_pid" 2>/dev/null || true' ALRM
trap 'kill -TERM "$gate_pid" 2>/dev/null || true; exit 130' INT
trap 'kill -TERM "$gate_pid" 2>/dev/null || true; exit 143' TERM
(
    expires_at=$((SECONDS + deadline))
    while kill -0 "$gate_pid" 2>/dev/null && (( SECONDS < expires_at )); do
        sleep 1
    done
    if kill -0 "$gate_pid" 2>/dev/null; then kill -ALRM "$$"; fi
) >/dev/null 2>&1 &
watchdog_pid=$!
trap 'kill "$watchdog_pid" 2>/dev/null || true' EXIT
result=0
wait "$gate_pid" || result=$?
if (( timed_out )); then
    kill -KILL "$gate_pid" 2>/dev/null || true
    wait "$gate_pid" 2>/dev/null || true
    printf '%s\n' 'Gate launcher exceeded the external deadline; see its log.' >&2
    exit 124
fi
exit "$result"
