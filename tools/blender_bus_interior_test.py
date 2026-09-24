"""Reproducible interior generator: temp GLBs, glb_check, direct bounds/openings.

    python tools/blender_bus_interior_test.py [--blender <path>]
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


def find_blender(explicit=None):
    for candidate in (explicit, os.environ.get("BLENDER"), shutil.which("blender"), WINDOWS_DEFAULT):
        if candidate and Path(candidate).is_file():
            return str(Path(candidate))
    raise SystemExit("no encuentro Blender: pasa --blender <ruta> o define BLENDER")


def generate(blender, destination):
    return subprocess.run([blender, "--background", "--factory-startup", "--python-exit-code", "1",
                           "--python", str(TOOLS / "blender_bus_interior.py"), "--", str(destination)],
                          capture_output=True, encoding="utf-8", errors="replace", timeout=180)


def invoked_findings(path):
    result = subprocess.run([sys.executable, str(TOOLS / "glb_check.py"), str(path), "--kind", "bus",
                             "--pivot", "center", "--json"],
                            capture_output=True, encoding="utf-8", timeout=30)
    assert result.returncode == 0, result.stdout[-3000:] + result.stderr[-3000:]
    return {f["check"]: f["pass"] for f in json.loads(result.stdout)["findings"]}


def scene_nodes(g):
    indexes = set()
    stack = list(g["scenes"][g.get("scene", 0)].get("nodes", []))
    while stack:
        index = stack.pop()
        indexes.add(index)
        stack.extend(g["nodes"][index].get("children", []))
    return indexes


def node_bounds(g, bins, predicate):
    out = []
    for index in scene_nodes(g):
        node = g["nodes"][index]
        if "mesh" not in node or not predicate(node.get("name", "")):
            continue
        world = glb_check.node_matrix(node)
        positions = []
        for primitive in g["meshes"][node["mesh"]]["primitives"]:
            positions.extend(glb_check.apply(world, p) for p in
                             glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"]))
        out.append({"name": node.get("name", ""),
                    "low": [min(p[k] for p in positions) for k in range(3)],
                    "high": [max(p[k] for p in positions) for k in range(3)]})
    assert out, "sin malla"
    return out


def assert_gap(g, bins, dimensions):
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


# glTF V = 1 - Blender V: floor/rack are the PNG's top quadrants, seat/wall the bottom ones.
UV_REGIONS = {
    "floor": (0.02, 0.02, 0.48, 0.48),
    "rack": (0.52, 0.02, 0.98, 0.48),
    "seat": (0.02, 0.52, 0.48, 0.98),
    "wall": (0.52, 0.52, 0.98, 0.98),
}


def uv_category(name):
    if name.startswith(("Floor", "BoardingStep")):
        return "floor"
    if name.startswith(("LeftRack", "RightRack")):
        return "rack"
    if name.startswith(("DriverSeat", "CopilotSeat", "Bench", "Stretcher")):
        return "seat"
    return "wall"


def assert_uv_regions(g, bins):
    for index in scene_nodes(g):
        node = g["nodes"][index]
        if "mesh" not in node:
            continue
        name = node.get("name", "")
        u0, v0, u1, v1 = UV_REGIONS[uv_category(name)]
        for primitive in g["meshes"][node["mesh"]]["primitives"]:
            for u, v in glb_check.read_accessor(g, bins, primitive["attributes"]["TEXCOORD_0"]):
                assert u0 - 1e-3 <= u <= u1 + 1e-3 and v0 - 1e-3 <= v <= v1 + 1e-3, \
                    "%s UV (%.3f, %.3f) fuera de %s" % (name, u, v, uv_category(name))


def validate(glb):
    checks = invoked_findings(glb)
    assert all(checks.values()), [name for name, ok in checks.items() if not ok]
    g, bins = glb_check.load_glb(str(glb))
    assert not g.get("images", []) and len(g.get("materials", [])) == 1
    for node in g.get("nodes", []):
        assert "-col" not in node.get("name", "").lower()
        if "mesh" in node:
            for primitive in g["meshes"][node["mesh"]]["primitives"]:
                assert "TEXCOORD_0" in primitive["attributes"], "UV0 ausente"
    assert_uv_regions(g, bins)

    # Godot/glTF frame: -Z is front, +Z rear.
    # Center shift is x=-0.05, y=-1.03, Blender-y=-0.005 (glTF z=+0.005).
    assert_gap(g, bins, ((0.95, 1.10), (-0.63, 0.87), (-3.185, -2.305)))     # side opening above steps
    assert_gap(g, bins, ((-0.73, 0.63), (-0.97, 0.77), (3.725, 3.905)))      # rear opening
    floor = node_bounds(g, bins, lambda name: name == "FloorLiner")[0]
    roof = node_bounds(g, bins, lambda name: name == "RoofLiner")[0]
    assert -1.04 <= floor["low"][1] <= -1.02 and -0.99 <= floor["high"][1] <= -0.97, floor
    assert 0.87 <= roof["low"][1] and roof["high"][1] <= 0.97, roof
    rack_left = node_bounds(g, bins, lambda name: name.startswith("LeftRack"))
    rack_right = node_bounds(g, bins, lambda name: name.startswith("RightRack"))
    left_inner = max(item["high"][0] for item in rack_left)
    right_inner = min(item["low"][0] for item in rack_right)
    corridor = right_inner - left_inner
    assert corridor >= 1.2, "corredor %.3f < 1.2" % corridor
    for prefix in ("Bench", "Stretcher", "BoardingStep"):
        items = node_bounds(g, bins, lambda name, p=prefix: name.startswith(p))
        side = -1.0 if prefix == "Bench" else 1.0
        inner = max(item["high"][0] for item in items) if side < 0 else min(item["low"][0] for item in items)
        assert abs(inner) >= 0.60, "%s entra al corredor: %.3f" % (prefix, inner)
    seats = node_bounds(g, bins, lambda name: name.startswith(("DriverSeat", "CopilotSeat")))
    assert len(seats) >= 8, "asientos visuales incompletos"
    wheel_wells = node_bounds(g, bins, lambda name: name.startswith("WheelWell"))
    assert {item["name"] for item in wheel_wells} == {
        "WheelWellFL", "WheelWellFR", "WheelWellRL", "WheelWellRR"}, wheel_wells
    assert all(item["high"][1] >= -0.33 for item in wheel_wells), wheel_wells

    tris = sum(len(glb_check.read_accessor(g, bins, p["indices"])) // 3
               for mesh in g.get("meshes", []) for p in mesh["primitives"])
    assert tris <= 7000, "interior %d > 7000" % tris
    return tris, corridor


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blender", default=None)
    arguments = parser.parse_args()
    blender = find_blender(arguments.blender)
    with tempfile.TemporaryDirectory(prefix="rutafragil_interior_") as directory:
        glb = Path(directory) / "interior.glb"
        run = generate(blender, glb)
        assert run.returncode == 0 and "INTERIOR_OK" in run.stdout, run.stdout[-3000:] + run.stderr[-3000:]
        tris, corridor = validate(glb)
        print("INTERIOR_TEST_OK tris=%d corridor=%.3f" % (tris, corridor))
        return glb, tris


if __name__ == "__main__":
    main()
