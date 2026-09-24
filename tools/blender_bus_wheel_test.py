"""Reproducible wheel generator and aggregate budget.

    python tools/blender_bus_wheel_test.py [--blender <path>]
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import glb_check
import blender_van_test
import blender_bus_interior_test

WINDOWS_DEFAULT = r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"


def find_blender(explicit=None):
    for candidate in (explicit, os.environ.get("BLENDER"), shutil.which("blender"), WINDOWS_DEFAULT):
        if candidate and Path(candidate).is_file():
            return str(Path(candidate))
    raise SystemExit("no encuentro Blender: pasa --blender <ruta> o define BLENDER")


def generate(blender, destination):
    return subprocess.run([blender, "--background", "--factory-startup", "--python-exit-code", "1",
                           "--python", str(TOOLS / "blender_bus_wheel.py"), "--", str(destination)],
                          capture_output=True, encoding="utf-8", errors="replace", timeout=180)


def invoked_findings(path):
    result = subprocess.run([sys.executable, str(TOOLS / "glb_check.py"), str(path), "--kind", "prop",
                             "--pivot", "center", "--json"],
                            capture_output=True, encoding="utf-8", timeout=30)
    assert result.returncode == 0, result.stdout[-3000:] + result.stderr[-3000:]
    return {f["check"]: f["pass"] for f in json.loads(result.stdout)["findings"]}


def validate(path):
    checks = invoked_findings(path)
    assert all(checks.values()), [name for name, ok in checks.items() if not ok]
    g, bins = glb_check.load_glb(str(path))
    assert not g.get("images", []) and len(g.get("materials", [])) == 1
    positions = []
    tris = 0
    for node in g.get("nodes", []):
        assert "-col" not in node.get("name", "").lower()
        if "mesh" not in node:
            continue
        # Atlas: tread is the left half, rim the right half.
        u0, u1 = (0.02, 0.48) if node.get("name") == "GenericTire" else (0.52, 0.98)
        for primitive in g["meshes"][node["mesh"]]["primitives"]:
            assert "TEXCOORD_0" in primitive["attributes"], "UV0 ausente"
            for u, v in glb_check.read_accessor(g, bins, primitive["attributes"]["TEXCOORD_0"]):
                assert u0 - 1e-3 <= u <= u1 + 1e-3 and 0.02 - 1e-3 <= v <= 0.98 + 1e-3, \
                    "%s UV (%.3f, %.3f) fuera de su mitad" % (node.get("name"), u, v)
            positions.extend(glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"]))
            tris += len(glb_check.read_accessor(g, bins, primitive["indices"])) // 3
    assert tris <= 1500, "rueda %d > 1500" % tris
    center = [sum(p[k] for p in positions) / len(positions) for k in range(3)]
    assert max(abs(c) for c in center) <= 0.03, "rueda no centrada"
    width = max(p[0] for p in positions) - min(p[0] for p in positions)
    radii = [math.hypot(p[1], p[2]) for p in positions]
    assert width >= 0.18, "eje local no parece +X (width %.3f)" % width
    assert 0.48 <= max(radii) <= 0.502, "radio máximo %.3f" % max(radii)
    assert min(radii) <= 0.10, "sin buje"
    names = [node.get("name", "") for node in g.get("nodes", []) if "mesh" in node]
    forbidden = ("pirelli", "michelin", "goodyear", "logo", "text")
    assert not any(word in name.lower() for name in names for word in forbidden), names
    return tris, max(radii)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blender", default=None)
    arguments = parser.parse_args()
    blender = find_blender(arguments.blender)

    with tempfile.TemporaryDirectory(prefix="rutafragil_assets_") as directory:
        directory = Path(directory)
        exterior = directory / "exterior.glb"
        interior = directory / "interior.glb"
        wheel = directory / "wheel.glb"
        for generator, destination in (("blender_van.py", exterior),
                                       ("blender_bus_interior.py", interior),
                                       ("blender_bus_wheel.py", wheel)):
            run = generate(blender, destination) if generator == "blender_bus_wheel.py" else \
                blender_van_test.generate(blender, destination) if generator == "blender_van.py" else \
                blender_bus_interior_test.generate(blender, destination)
            assert run.returncode == 0, run.stdout[-3000:] + run.stderr[-3000:]
        second = directory / "wheel_second.glb"
        rerun = generate(blender, second)
        assert rerun.returncode == 0, rerun.stdout[-3000:] + rerun.stderr[-3000:]
        assert second.read_bytes() == wheel.read_bytes(), "rueda no byte-determinista"

        exterior_tris = blender_van_test.validate(exterior)
        interior_tris, corridor = blender_bus_interior_test.validate(interior)
        wheel_tris, radius = validate(wheel)
        total = exterior_tris + interior_tris + 4 * wheel_tris
        assert total <= 25000, "suma instanciada %d > 25000" % total
        print("WHEEL_TEST_OK tris=%d radius=%.3f aggregate=%d/25000 corridor=%.3f"
              % (wheel_tris, radius, total, corridor))


if __name__ == "__main__":
    main()
