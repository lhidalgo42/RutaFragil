"""Reproducible exterior generator: temp GLBs, glb_check, direct openings and UV regions.

    python tools/blender_van_test.py [--blender <path>]

Blender is searched in --blender, then BLENDER, PATH, and the Windows default.
Godot frame: -Z is front, +Z rear; the wrapper puts the GLB base at bus y=-0.8.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
import glb_check

WINDOWS_DEFAULT = r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"

# glTF V = 1 - Blender V, so yellow is the PNG's top half (v<=0.5).
UV_REGIONS = {
    "yellow": (0.02, 0.02, 0.98, 0.48),
    "red": (0.02, 0.52, 0.23, 0.98),
    "cream": (0.27, 0.52, 0.48, 0.98),
    "glass": (0.52, 0.52, 0.73, 0.98),
    "dark": (0.77, 0.52, 0.98, 0.98),
}


def find_blender(explicit=None):
    for candidate in (explicit, os.environ.get("BLENDER"), shutil.which("blender"), WINDOWS_DEFAULT):
        if candidate and Path(candidate).is_file():
            return str(Path(candidate))
    raise SystemExit("no encuentro Blender: pasa --blender <ruta> o define BLENDER")


def generate(blender, destination):
    return subprocess.run([blender, "--background", "--factory-startup", "--python-exit-code", "1",
                           "--python", str(TOOLS / "blender_van.py"), "--", str(destination)],
                          capture_output=True, encoding="utf-8", errors="replace", timeout=180)


def scene_nodes(g):
    indexes = set()
    stack = list(g["scenes"][g.get("scene", 0)].get("nodes", []))
    while stack:
        index = stack.pop()
        indexes.add(index)
        stack.extend(g["nodes"][index].get("children", []))
    return indexes


def mesh_nodes(g, predicate):
    return [(i, g["nodes"][i]) for i in scene_nodes(g)
            if "mesh" in g["nodes"][i] and predicate(g["nodes"][i].get("name", ""))]


def node_bounds(g, bins, predicate):
    out = []
    for _i, node in mesh_nodes(g, predicate):
        positions = []
        for primitive in g["meshes"][node["mesh"]]["primitives"]:
            positions.extend(glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"]))
        out.append({"name": node.get("name", ""), "positions": positions,
                    "low": [min(p[k] for p in positions) for k in range(3)],
                    "high": [max(p[k] for p in positions) for k in range(3)]})
    assert out, "sin malla"
    return out


def assert_gap(g, bins, dimensions):
    """No world-space face box may intersect the opening; None = unconstrained axis."""
    for mesh_index, world in glb_check.mesh_instances(g):
        for primitive in g["meshes"][mesh_index]["primitives"]:
            positions = [glb_check.apply(world, p)
                         for p in glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"])]
            indexes = glb_check.read_accessor(g, bins, primitive["indices"])
            for start in range(0, len(indexes), 3):
                face = indexes[start:start + 3]
                low = [min(positions[v][axis] for v in face) for axis in range(3)]
                high = [max(positions[v][axis] for v in face) for axis in range(3)]
                if all(dimensions[axis] is None or
                       (high[axis] > dimensions[axis][0] and low[axis] < dimensions[axis][1])
                       for axis in range(3)):
                    raise AssertionError("cara dentro del hueco %s: %s..%s" % (dimensions, low, high))


def assert_uv_regions(g, bins):
    def category(name):
        if name.startswith("RedStripe"):
            return "red"
        if name.startswith("Roof"):
            return "cream"
        if "HighWindow" in name:
            return "glass"
        if name == "Underbody" or "WheelArch" in name:
            return "dark"
        return "yellow"

    for _i, node in mesh_nodes(g, lambda _name: True):
        u0, v0, u1, v1 = UV_REGIONS[category(node.get("name", ""))]
        for primitive in g["meshes"][node["mesh"]]["primitives"]:
            assert "TEXCOORD_0" in primitive["attributes"], "UV0 ausente"
            for u, v in glb_check.read_accessor(g, bins, primitive["attributes"]["TEXCOORD_0"]):
                assert u0 - 1e-3 <= u <= u1 + 1e-3 and v0 - 1e-3 <= v <= v1 + 1e-3, \
                    "%s UV (%.3f, %.3f) fuera de %s" % (node.get("name"), u, v, category(node.get("name")))


def tris(g, bins):
    return sum(len(glb_check.read_accessor(g, bins, p["indices"])) // 3
               for mesh in g.get("meshes", []) for p in mesh["primitives"])


def validate(glb):
    result = subprocess.run([sys.executable, str(TOOLS / "glb_check.py"), str(glb), "--kind", "bus",
                             "--pivot", "base", "--json"],
                            capture_output=True, encoding="utf-8", timeout=30)
    assert result.returncode == 0, result.stdout[-3000:] + result.stderr[-3000:]
    checks = {f["check"]: f["pass"] for f in json.loads(result.stdout)["findings"]}
    assert all(checks.values()), [name for name, ok in checks.items() if not ok]

    g, bins = glb_check.load_glb(str(glb))
    assert not g.get("images", []) and len(g.get("materials", [])) == 1
    assert not g.get("animations", []) and not g.get("cameras", []) and not g.get("lights", [])
    assert all(not n.get("translation") and not n.get("rotation") for n in g.get("nodes", [])), \
        "nodos con transformación: las coordenadas de malla deben ser finales"
    for node in g.get("nodes", []):
        assert "-col" not in node.get("name", "").lower(), "nombre prohibido -col"
    assert_uv_regions(g, bins)

    # Openings (Godot frame: -Z front; wrapper puts model y0 at bus y -0.8).
    assert_gap(g, bins, ((1.15, 1.27), (1.12, 2.02), (-3.19, -2.31)))        # boarding above arch
    assert_gap(g, bins, ((-0.68, 0.68), (0.15, 2.18), (3.84, 4.01)))         # rear, >=1.4 x 1.9
    assert_gap(g, bins, ((-0.90, 0.90), (1.05, 2.02), (-4.01, -3.83)))       # windshield
    assert_gap(g, bins, ((-1.27, -1.15), (1.28, 2.02), (-3.51, -2.37)))      # left cab high window
    assert_gap(g, bins, ((1.15, 1.27), (1.28, 2.02), (-3.61, -3.29)))        # right cab high window

    # Static wheel centre: bus y -0.48 = model y 0.32 (wrapper -0.8); radius 0.5.
    for item in node_bounds(g, bins, lambda name: "WheelArch" in name):
        z_center = (item["low"][2] + item["high"][2]) / 2
        y_center = item["low"][1]  # the arch's straight bottom edge passes through its centre
        assert abs(abs(z_center) - 2.75) <= 0.02, (item["name"], z_center)
        assert 0.32 <= y_center <= 0.45, (item["name"], y_center)
        side = -1.0 if item["name"].startswith("Left") else 1.0
        assert abs(item["high"][0] * side - 1.25) <= 0.01 or abs(item["low"][0] * side - 1.25) <= 0.01
        inner = min(((p[2] - z_center) ** 2 + (p[1] - y_center) ** 2) ** 0.5 for p in item["positions"])
        # the static wheel (centre 0.32, radius 0.5) must fit inside the arch's inner edge
        assert inner - (y_center - 0.32) >= 0.5, (item["name"], inner, y_center)

    total = tris(g, bins)
    assert total <= 10000, "exterior %d > 10000" % total
    return total


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blender", default=None)
    arguments = parser.parse_args()
    blender = find_blender(arguments.blender)

    with tempfile.TemporaryDirectory(prefix="rutafragil_van_") as directory:
        first = Path(directory) / "van.glb"
        second = Path(directory) / "van_second.glb"
        run = generate(blender, first)
        assert run.returncode == 0 and "VAN_OK" in run.stdout, run.stdout[-3000:] + run.stderr[-3000:]
        rerun = generate(blender, second)
        assert rerun.returncode == 0, rerun.stdout[-3000:] + rerun.stderr[-3000:]
        assert second.read_bytes() == first.read_bytes(), "la segunda generación no es byte-determinista"
        total = validate(first)
        print("VAN_TEST_OK tris=%d deterministic=yes" % total)


if __name__ == "__main__":
    main()
