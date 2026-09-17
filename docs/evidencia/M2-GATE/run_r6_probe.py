"""Bounded headless runner for the round-six deterministic fixture."""
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
label = sys.argv[1]
engine = r"C:\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
command = [engine, "--headless", "--fixed-fps", "60", "--path", str(root),
           "-s", "res://src/tooling/run_air_carry_probe.gd", "++",
           "output=res://docs/evidencia/M2-GATE/20_air", "label=" + label, *sys.argv[2:]]
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=root)
try:
    out, err = process.communicate(timeout=120)
    code = process.returncode
except subprocess.TimeoutExpired:
    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
    out, err = process.communicate()
    code = 124
(evidence / ("20_" + label + ".log")).write_bytes(out)
(evidence / ("20_" + label + "_stderr.log")).write_bytes(err)
context = {"command": command, "exit": code,
           "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
           "source_dirty": subprocess.check_output(["git", "status", "--porcelain", "--", "src", "tests"], cwd=root, text=True).splitlines()}
(evidence / ("20_" + label + "_context.json")).write_text(json.dumps(context, indent=2) + "\n", encoding="utf-8")
print(label, "EXIT", code, flush=True)
print(out.decode("utf-8", errors="replace")[-1500:])
print(err.decode("utf-8", errors="replace")[-2000:])
sys.exit(code)
