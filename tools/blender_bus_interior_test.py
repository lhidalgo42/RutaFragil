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


WRAPPER_OFFSET = (0.0, 0.38, 0.005)


def assert_inside(items, low, high, label):
    for item in items:
        wrapped_low = [item["low"][axis] + WRAPPER_OFFSET[axis] for axis in range(3)]
        wrapped_high = [item["high"][axis] + WRAPPER_OFFSET[axis] for axis in range(3)]
        assert all(wrapped_low[axis] >= low[axis] - 0.01 and
                   wrapped_high[axis] <= high[axis] + 0.01 for axis in range(3)), \
            "%s fuera de colision: %s %s..%s" % (label, item["name"], wrapped_low, wrapped_high)


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
    if name.startswith(("LeftRack", "RightRack", "LeftParcel", "RightParcel")):
        return "rack"
    if name.startswith(("DriverSeat", "CopilotSeat", "Bench", "Stretcher",
                        "Dashboard", "Steering", "WheelWellDark", "RearDoorSill",
                        "RearOpeningHeader")):
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
    # Model wrapper restores the centered GLB vertically and longitudinally; X is symmetric.
    assert_gap(g, bins, ((0.95, 1.10), (-0.63, 0.87), (-3.185, -2.305)))     # side opening above steps
    assert_gap(g, bins, ((-0.73, 0.63), (-0.97, 0.77), (3.725, 3.905)))      # rear opening
    floor = node_bounds(g, bins, lambda name: name == "FloorLiner")[0]
    roof = node_bounds(g, bins, lambda name: name == "RoofLiner")[0]
    assert -1.04 <= floor["low"][1] <= -1.02 and -0.99 <= floor["high"][1] <= -0.97, floor
    # v6: el piso llega al portal trasero (z GLB 3.995) y al morro (z GLB -3.985).
    assert floor["high"][2] >= 3.98 and floor["low"][2] <= -3.98, floor
    # El sillon oscuro cubre el portal de 1.40 m sin entrar en la apertura fisica
    # (la apertura termina en z GLB 3.905; el sillon empieza en 3.915).
    sill = node_bounds(g, bins, lambda name: name == "RearDoorSill")[0]
    assert sill["low"][2] > 3.905 and sill["high"][2] <= 3.991, sill
    assert sill["high"][0] - sill["low"][0] >= 1.40, sill
    # Cabecera y montantes traseros profundizados cierran la costura con el shell.
    for rear_name in ("RearLeftLiner", "RearRightLiner", "RearOpeningHeader"):
        piece = node_bounds(g, bins, lambda name: name == rear_name)[0]
        assert piece["high"][2] >= 3.95, piece
    assert 0.87 <= roof["low"][1] and roof["high"][1] <= 0.97, roof
    rack_left = node_bounds(g, bins, lambda name: name.startswith("LeftRack"))
    rack_right = node_bounds(g, bins, lambda name: name.startswith("RightRack"))
    left_inner = max(item["high"][0] for item in rack_left)
    right_inner = min(item["low"][0] for item in rack_right)
    corridor = right_inner - left_inner
    assert corridor >= 1.2, "corredor %.3f < 1.2" % corridor
    # Bus-local collider boxes from src/vehicle/bus_interior.tscn.
    assert_inside(rack_left, (-1.15, -0.60, -1.20), (-0.60, 0.80, 1.20), "rack izquierdo")
    assert_inside(rack_right, (0.60, -0.60, -1.20), (1.15, 0.80, 1.20), "rack derecho")
    assert_inside(node_bounds(g, bins, lambda name: name.startswith("Bench")),
        (-1.15, -0.60, 2.30), (-0.60, 0.30, 3.50), "banco")
    assert_inside(node_bounds(g, bins, lambda name: name.startswith("Stretcher")),
        (0.50, -0.60, 1.30), (1.10, -0.35, 3.10), "camilla")
    # D90 door column is the front-right wheel sweep: no visual step may cross it.
    assert not any(g["nodes"][i].get("name", "").startswith("BoardingStep") for i in scene_nodes(g))
    seats = node_bounds(g, bins, lambda name: name.startswith(("DriverSeat", "CopilotSeat")))
    assert len(seats) >= 8, "asientos visuales incompletos"
    assert {item["name"].split(".")[0] for item in seats} == {
        "DriverSeatBase", "DriverSeatCushion", "DriverSeatBack", "DriverSeatHeadrest",
        "DriverSeatSeatbelt", "DriverSeatBuckle",
        "CopilotSeatBase", "CopilotSeatCushion", "CopilotSeatBack", "CopilotSeatHeadrest",
        "CopilotSeatSeatbelt", "CopilotSeatBuckle"}, seats
    # Los markers driver/copilot del bus fijan el centro (x, z) de cada cushion tras el wrapper.
    for prefix, target_x in (("DriverSeat", -0.6), ("CopilotSeat", 0.6)):
        cushion = node_bounds(g, bins, lambda name: name == prefix + "Cushion")[0]
        center_x = (cushion["low"][0] + cushion["high"][0]) / 2 + WRAPPER_OFFSET[0]
        center_z = (cushion["low"][2] + cushion["high"][2]) / 2 + WRAPPER_OFFSET[2]
        assert abs(center_x - target_x) < 1e-3, (prefix, center_x)
        assert abs(center_z + 2.9) < 1e-3, (prefix, center_z)
    cockpit = node_bounds(g, bins,
        lambda name: name.startswith(("Dashboard", "Steering")))
    assert {item["name"] for item in cockpit} == {
        "Dashboard", "DashboardConsole", "SteeringWheel", "SteeringColumn"}, cockpit
    wheel_wells = node_bounds(g, bins,
        lambda name: name.startswith("WheelWellDark") and not name.endswith("Fascia"))
    assert {item["name"] for item in wheel_wells} == \
        {"WheelWellDarkFL", "WheelWellDarkFR", "WheelWellDarkRR"}, wheel_wells
    fascias = node_bounds(g, bins, lambda name: name.startswith("WheelWellDark") and name.endswith("Fascia"))
    assert {item["name"] for item in fascias} == \
        {"WheelWellDarkFLFascia", "WheelWellDarkFRFascia", "WheelWellDarkRRFascia"}, fascias
    assert all(item["high"][1] - item["low"][1] >= 0.50 for item in fascias), fascias
    for item in wheel_wells:
        vertices = set()
        for index in scene_nodes(g):
            node = g["nodes"][index]
            if node.get("name", "") != item["name"]:
                continue
            world = glb_check.node_matrix(node)
            for primitive in g["meshes"][node["mesh"]]["primitives"]:
                vertices |= {(round(p[0], 4), round(p[1], 4), round(p[2], 4))
                             for p in (glb_check.apply(world, raw) for raw in
                                       glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"]))}
        base_y = min(p[1] for p in vertices)
        apex_y = max(p[1] for p in vertices)
        z0 = min(p[2] for p in vertices)
        z1 = max(p[2] for p in vertices)
        center_z = (z0 + z1) / 2
        span_z = z1 - z0
        assert len(vertices) == 22, (item["name"], len(vertices))
        # Semicirculo: ancho z ≈ 2 * elevación sobre el suelo del interior.
        assert abs((apex_y - base_y) - span_z / 2) < 0.02, (item["name"], vertices)
        assert any(abs(p[2] - z0) < 1e-3 and abs(p[1] - base_y) < 1e-3 for p in vertices), item["name"]
        assert any(abs(p[2] - center_z) < 1e-3 and abs(p[1] - apex_y) < 1e-3 for p in vertices), item["name"]
    ribs = node_bounds(g, bins, lambda name: name.startswith(("FloorRib", "FloorThreshold")))
    assert len(ribs) == 5, ribs
    # Sin caras coplanares: los nervios arrancan por encima de la cara superior del suelo.
    assert all(item["low"][1] >= floor["high"][1] + 0.003 for item in ribs), (floor, ribs)
    assert sum(1 for item in ribs if item["high"][2] - item["low"][2] > 6.0) == 3, ribs
    for rack, sign in ((rack_left, -1), (rack_right, 1)):
        names = {item["name"] for item in rack}
        assert {"LowerCabinet", "LowerDoorRear", "LowerDoorFront"} <= \
            {name[len("LeftRack" if sign < 0 else "RightRack"):] for name in names}, names
        shelves = [item for item in rack if "UpperShelf" in item["name"]]
        assert len(shelves) == 3, names
        # Estantes superiores parciales: nada vertical cubre la cara del pasillo sobre el gabinete.
        uprights = [item for item in rack if item["low"][1] > -0.4 and
                    item["high"][1] - item["low"][1] > 0.3 and
                    item["high"][2] - item["low"][2] > 0.3]
        assert not uprights, uprights
        width = max(item["high"][0] - item["low"][0] for item in rack)
        assert width >= 0.46, (names, width)
    parcels = node_bounds(g, bins, lambda name: "Parcel" in name)
    assert 3 <= len(parcels) <= 6, parcels
    left_parcels = [item for item in parcels if item["name"].startswith("Left")]
    right_parcels = [item for item in parcels if item["name"].startswith("Right")]
    assert left_parcels and right_parcels, parcels
    assert_inside(left_parcels, (-1.15, -0.60, -1.20), (-0.60, 0.80, 1.20), "parcel izquierdo")
    assert_inside(right_parcels, (0.60, -0.60, -1.20), (1.15, 0.80, 1.20), "parcel derecho")

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
        duplicate = Path(directory) / "interior_duplicate.glb"
        run = generate(blender, glb)
        assert run.returncode == 0 and "INTERIOR_OK" in run.stdout, run.stdout[-3000:] + run.stderr[-3000:]
        rerun = generate(blender, duplicate)
        assert rerun.returncode == 0 and "INTERIOR_OK" in rerun.stdout, rerun.stdout[-3000:] + rerun.stderr[-3000:]
        assert glb.read_bytes() == duplicate.read_bytes(), "generacion GLB no determinista"
        tris, corridor = validate(glb)
        print("INTERIOR_TEST_OK tris=%d corridor=%.3f deterministic=yes" % (tris, corridor))
        return glb, tris


if __name__ == "__main__":
    main()
