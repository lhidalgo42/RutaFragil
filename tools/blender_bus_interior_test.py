"""Reproducible interior generator: temp GLBs, glb_check, direct geometry checks.

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
WRAPPER_OFFSET = (0.0, 0.38, 0.005)


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
        out.append({"name": node.get("name", ""), "positions": positions,
                    "low": [min(p[k] for p in positions) for k in range(3)],
                    "high": [max(p[k] for p in positions) for k in range(3)]})
    assert out, "sin malla"
    return out


def wrapped(item):
    return {"name": item["name"], "positions": item.get("positions", []),
            "low": [item["low"][axis] + WRAPPER_OFFSET[axis] for axis in range(3)],
            "high": [item["high"][axis] + WRAPPER_OFFSET[axis] for axis in range(3)]}


def dimensions(item):
    return [item["high"][axis] - item["low"][axis] for axis in range(3)]


def node_triangles(g, bins, name):
    nodes = [g["nodes"][index] for index in scene_nodes(g)
             if g["nodes"][index].get("name", "") == name and "mesh" in g["nodes"][index]]
    assert len(nodes) == 1, (name, len(nodes))
    return sum(len(glb_check.read_accessor(g, bins, primitive["indices"])) // 3
               for primitive in g["meshes"][nodes[0]["mesh"]]["primitives"])


def mesh_components(g, bins, name):
    """Connected pieces after welding exporter-split vertices by world position."""
    nodes = [g["nodes"][index] for index in scene_nodes(g)
             if g["nodes"][index].get("name", "") == name and "mesh" in g["nodes"][index]]
    assert len(nodes) == 1, (name, len(nodes))
    node = nodes[0]
    world = glb_check.node_matrix(node)
    canonical = {}
    points = []
    faces = []
    for primitive in g["meshes"][node["mesh"]]["primitives"]:
        raw = glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"])
        positions = [glb_check.apply(world, point) for point in raw]
        welded = []
        for point in positions:
            key = tuple(round(value, 5) for value in point)
            if key not in canonical:
                canonical[key] = len(points)
                points.append(point)
            welded.append(canonical[key])
        indexes = glb_check.read_accessor(g, bins, primitive["indices"])
        faces.extend(tuple(welded[indexes[start + corner]] for corner in range(3))
                     for start in range(0, len(indexes), 3))
    parent = list(range(len(points)))

    def root(index):
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index

    def union(a, b):
        a, b = root(a), root(b)
        if a != b:
            parent[b] = a

    for face in faces:
        union(face[0], face[1])
        union(face[0], face[2])
    groups = {}
    for index, point in enumerate(points):
        groups.setdefault(root(index), {"positions": [], "tris": 0})["positions"].append(point)
    for face in faces:
        groups[root(face[0])]["tris"] += 1
    out = []
    for group in groups.values():
        positions = group["positions"]
        out.append({"positions": positions, "tris": group["tris"],
                    "low": [min(p[axis] for p in positions) for axis in range(3)],
                    "high": [max(p[axis] for p in positions) for axis in range(3)]})
    return out


def assert_inside(items, low, high, label):
    for item in items:
        item = wrapped(item)
        assert all(item["low"][axis] >= low[axis] - 0.01 and
                   item["high"][axis] <= high[axis] + 0.01 for axis in range(3)), \
            "%s fuera de contencion: %s %s..%s" % (label, item["name"], item["low"], item["high"])


def assert_gap(g, bins, dimensions_):
    """No wrapped world-space face box may intersect the requested bus-local opening."""
    for mesh_index, world in glb_check.mesh_instances(g):
        for primitive in g["meshes"][mesh_index]["primitives"]:
            positions = [tuple(value + WRAPPER_OFFSET[axis] for axis, value in enumerate(glb_check.apply(world, p)))
                         for p in glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"])]
            indexes = glb_check.read_accessor(g, bins, primitive["indices"])
            for start in range(0, len(indexes), 3):
                face = indexes[start:start + 3]
                low = [min(positions[v][axis] for v in face) for axis in range(3)]
                high = [max(positions[v][axis] for v in face) for axis in range(3)]
                if all(dimensions_[axis] is None or
                       (high[axis] > dimensions_[axis][0] and low[axis] < dimensions_[axis][1])
                       for axis in range(3)):
                    raise AssertionError("cara dentro del hueco %s: %s..%s" % (dimensions_, low, high))


# glTF V = 1 - Blender V: floor/rack are the PNG's top quadrants, seat/wall the bottom ones.
UV_REGIONS = {
    "floor": (0.02, 0.02, 0.48, 0.48),
    "rack": (0.52, 0.02, 0.98, 0.48),
    "seat": (0.02, 0.52, 0.48, 0.98),
    "wall": (0.52, 0.52, 0.98, 0.98),
}


def uv_category(name):
    if name.startswith(("Floor", "BoardingStep", "BoardingThreshold")):
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


def assert_automotive_seat(g, bins, prefix, target_x):
    mesh_name = prefix + "Cushion"
    seat = wrapped(node_bounds(g, bins, lambda name: name == mesh_name)[0])
    assert_inside([node_bounds(g, bins, lambda name: name == mesh_name)[0]],
                  (target_x - 0.40, -0.65, -3.22), (target_x + 0.40, 1.08, -2.42), prefix)
    assert node_triangles(g, bins, mesh_name) <= 450, "%s supera 450 tris" % prefix
    components = mesh_components(g, bins, mesh_name)

    cushion = [item for item in components
               if 0.48 <= dimensions(item)[0] <= 0.56 and
               0.14 <= dimensions(item)[1] <= 0.19 and
               0.50 <= dimensions(item)[2] <= 0.58]
    assert len(cushion) == 1, (prefix, "cushion", [dimensions(item) for item in components])
    cushion = wrapped({"name": prefix + " cushion", **cushion[0]})
    center_x = (cushion["low"][0] + cushion["high"][0]) / 2
    center_z = (cushion["low"][2] + cushion["high"][2]) / 2
    assert abs(center_x - target_x) < 1e-3, (prefix, center_x)
    assert abs(center_z + 2.9) < 1e-3, (prefix, center_z)

    backs = [item for item in components if 0.49 <= dimensions(item)[0] <= 0.54 and
             dimensions(item)[1] >= 0.72 and 0.25 <= dimensions(item)[2] <= 0.32]
    assert len(backs) == 1, (prefix, "tapered back", [dimensions(item) for item in components])
    back = backs[0]
    low_y, high_y = back["low"][1], back["high"][1]
    height = high_y - low_y
    shoulder = [point for point in back["positions"] if low_y + height * 0.50 <= point[1] <= low_y + height * 0.76]
    top = [point for point in back["positions"] if point[1] >= low_y + height * 0.92]
    shoulder_width = max(point[0] for point in shoulder) - min(point[0] for point in shoulder)
    top_width = max(point[0] for point in top) - min(point[0] for point in top)
    assert shoulder_width >= 0.49 and top_width <= 0.36 and shoulder_width - top_width >= 0.13, \
        (prefix, shoulder_width, top_width)
    lower = [point[2] for point in back["positions"] if point[1] <= low_y + height * 0.08]
    upper = [point[2] for point in back["positions"] if point[1] >= low_y + height * 0.92]
    recline = sum(upper) / len(upper) - sum(lower) / len(lower)
    assert 0.10 <= recline <= 0.14, "%s reclinacion trasera incorrecta %.3f" % (prefix, recline)

    bolsters = [item for item in components if 0.56 <= dimensions(item)[1] <= 0.62 and
                dimensions(item)[0] <= 0.09 and 0.32 <= dimensions(item)[2] <= 0.36]
    assert len(bolsters) == 2, (prefix, "bolsters", [dimensions(item) for item in components])
    assert min((item["low"][0] + item["high"][0]) / 2 for item in bolsters) < target_x - 0.18
    assert max((item["low"][0] + item["high"][0]) / 2 for item in bolsters) > target_x + 0.18

    posts = [item for item in components if 0.16 <= dimensions(item)[1] <= 0.20 and
             dimensions(item)[0] <= 0.05 and dimensions(item)[2] <= 0.07]
    assert len(posts) == 2, (prefix, "headrest posts", [dimensions(item) for item in components])
    assert abs(((posts[0]["low"][0] + posts[0]["high"][0]) / 2) -
               ((posts[1]["low"][0] + posts[1]["high"][0]) / 2)) >= 0.16

    rails = [item for item in components if dimensions(item)[0] <= 0.08 and
             dimensions(item)[1] <= 0.07 and 0.40 <= dimensions(item)[2] <= 0.44]
    pedestal = [item for item in components if 0.26 <= dimensions(item)[0] <= 0.32 and
                0.40 <= dimensions(item)[1] <= 0.50 and 0.30 <= dimensions(item)[2] <= 0.36]
    # Diagonal shoulder strap: narrow, shallow and distinctly longer than every small part.
    belt = [item for item in components if 0.40 <= dimensions(item)[0] <= 0.50 and
            dimensions(item)[1] >= 0.58 and dimensions(item)[2] <= 0.16 and item["tris"] == 12]
    buckle = [item for item in components if dimensions(item)[0] <= 0.08 and
              0.08 <= dimensions(item)[1] <= 0.12 and dimensions(item)[2] <= 0.07]
    assert len(rails) == 2 and len(pedestal) == 1, (prefix, "pedestal/rails")
    assert len(belt) == 1 and len(buckle) >= 1, (prefix, "belt/buckle")
    assert 0.08 <= (belt[0]["high"][0] - belt[0]["low"][0]) and \
        (belt[0]["high"][0] - belt[0]["low"][0]) <= 0.50
    assert seat["high"][2] < -2.42, (prefix, "invade opening", seat)


def validate(glb):
    checks = invoked_findings(glb)
    assert all(checks.values()), [name for name, ok in checks.items() if not ok]
    g, bins = glb_check.load_glb(str(glb))
    nodes = scene_nodes(g)
    assert len(nodes) <= 60, "interior %d nodos > 60" % len(nodes)
    assert not g.get("images", []) and len(g.get("materials", [])) == 1
    assert not g.get("animations", []) and not g.get("cameras", []) and not g.get("lights", [])
    for node in g.get("nodes", []):
        assert "-col" not in node.get("name", "").lower()
        if "mesh" in node:
            for primitive in g["meshes"][node["mesh"]]["primitives"]:
                assert "TEXCOORD_0" in primitive["attributes"], "UV0 ausente"
    assert_uv_regions(g, bins)

    # Godot/bus-local frame after the unchanged visual wrapper.
    assert_gap(g, bins, ((0.95, 1.10), (-0.59, 1.25), (-2.20, -1.30)))
    assert_gap(g, bins, ((-0.73, 0.63), (-0.59, 1.15), (3.73, 3.91)))
    # r8: wall liners open behind the exterior driver/copilot windows.
    for window_x in ((-1.12, -1.02), (1.02, 1.12)):
        assert_gap(g, bins, (window_x, (0.52, 1.16), (-3.52, -2.42)))
    floor = node_bounds(g, bins, lambda name: name == "FloorLiner")[0]
    roof = node_bounds(g, bins, lambda name: name == "RoofLiner")[0]
    wrapped_floor = wrapped(floor)
    assert -0.66 <= wrapped_floor["low"][1] <= -0.64 and -0.61 <= wrapped_floor["high"][1] <= -0.59
    assert wrapped_floor["high"][2] >= 3.98 and wrapped_floor["low"][2] <= -3.98
    sill = wrapped(node_bounds(g, bins, lambda name: name == "RearDoorSill")[0])
    assert sill["low"][2] > 3.91 and sill["high"][2] <= 4.00, sill
    assert sill["high"][0] - sill["low"][0] >= 1.40, sill
    for rear_name in ("RearLeftLiner", "RearRightLiner", "RearOpeningHeader"):
        piece = wrapped(node_bounds(g, bins, lambda name: name == rear_name)[0])
        assert piece["high"][2] >= 3.95, piece
    wrapped_roof = wrapped(roof)
    assert 1.25 <= wrapped_roof["low"][1] and wrapped_roof["high"][1] <= 1.36, wrapped_roof

    cargo_wall = wrapped(node_bounds(g, bins, lambda name: name == "RightCargoWallLiner")[0])
    cab_wall = wrapped(node_bounds(g, bins, lambda name: name == "RightCabWallLiner")[0])
    header = wrapped(node_bounds(g, bins, lambda name: name == "RightBoardingHeader")[0])
    threshold = wrapped(node_bounds(g, bins, lambda name: name == "BoardingThreshold")[0])
    assert abs(cargo_wall["low"][2] + 1.30) < 1e-3, cargo_wall
    assert abs(cab_wall["high"][2] + 2.20) < 1e-3, cab_wall
    for piece in (header, threshold):
        assert abs(piece["low"][2] + 2.20) < 1e-3 and abs(piece["high"][2] + 1.30) < 1e-3, piece
    assert threshold["high"][1] <= -0.59, threshold

    rack_left = node_bounds(g, bins, lambda name: name.startswith("LeftRack"))
    rack_right = node_bounds(g, bins, lambda name: name.startswith("RightRack"))
    left_inner = max(item["high"][0] for item in rack_left)
    right_inner = min(item["low"][0] for item in rack_right)
    corridor = right_inner - left_inner
    assert corridor >= 1.2, "corredor %.3f < 1.2" % corridor
    assert_inside(rack_left, (-1.15, -0.60, -1.20), (-0.60, 0.80, 1.20), "rack izquierdo")
    assert_inside(rack_right, (0.60, -0.60, -1.20), (1.15, 0.80, 1.20), "rack derecho")
    assert_inside(node_bounds(g, bins, lambda name: name.startswith("Bench")),
                  (-1.15, -0.60, 2.30), (-0.60, 0.30, 3.50), "banco")
    assert_inside(node_bounds(g, bins, lambda name: name.startswith("Stretcher")),
                  (0.50, -0.60, 1.30), (1.10, -0.35, 3.10), "camilla")

    seat_names = {g["nodes"][index].get("name", "") for index in nodes
                  if g["nodes"][index].get("name", "").startswith(("DriverSeat", "CopilotSeat"))}
    assert seat_names == {"DriverSeatCushion", "CopilotSeatCushion"}, seat_names
    assert_automotive_seat(g, bins, "DriverSeat", -0.6)
    assert_automotive_seat(g, bins, "CopilotSeat", 0.6)

    cockpit = node_bounds(g, bins, lambda name: name.startswith(("Dashboard", "Steering")))
    assert {item["name"] for item in cockpit} == {
        "Dashboard", "DashboardConsole", "SteeringWheel", "SteeringColumn"}, cockpit
    wheel_wells = node_bounds(g, bins,
        lambda name: name.startswith("WheelWellDark") and not name.endswith("Fascia"))
    assert {item["name"] for item in wheel_wells} == {
        "WheelWellDarkFL", "WheelWellDarkFR", "WheelWellDarkRR"}, wheel_wells
    fascias = node_bounds(g, bins, lambda name: name.startswith("WheelWellDark") and name.endswith("Fascia"))
    assert {item["name"] for item in fascias} == {
        "WheelWellDarkFLFascia", "WheelWellDarkFRFascia", "WheelWellDarkRRFascia"}, fascias
    assert all(item["high"][1] - item["low"][1] >= 0.50 for item in fascias), fascias
    for item in wheel_wells:
        vertices = {(round(p[0], 4), round(p[1], 4), round(p[2], 4)) for p in item["positions"]}
        base_y = min(p[1] for p in vertices)
        apex_y = max(p[1] for p in vertices)
        z0 = min(p[2] for p in vertices)
        z1 = max(p[2] for p in vertices)
        center_z = (z0 + z1) / 2
        assert len(vertices) == 22, (item["name"], len(vertices))
        assert abs((apex_y - base_y) - (z1 - z0) / 2) < 0.02, item["name"]
        assert any(abs(p[2] - z0) < 1e-3 and abs(p[1] - base_y) < 1e-3 for p in vertices)
        assert any(abs(p[2] - center_z) < 1e-3 and abs(p[1] - apex_y) < 1e-3 for p in vertices)

    ribs = node_bounds(g, bins, lambda name: name.startswith(("FloorRib", "FloorThreshold")))
    assert len(ribs) == 5, ribs
    assert all(item["low"][1] >= floor["high"][1] + 0.003 for item in ribs), (floor, ribs)
    assert sum(1 for item in ribs if item["high"][2] - item["low"][2] > 6.0) == 3, ribs
    for rack, prefix in ((rack_left, "LeftRack"), (rack_right, "RightRack")):
        names = {item["name"] for item in rack}
        assert {"LowerCabinet", "LowerDoorRear", "LowerDoorFront"} <= \
            {name[len(prefix):] for name in names}, names
        shelves = [item for item in rack if "UpperShelf" in item["name"]]
        assert len(shelves) == 3, names
        uprights = [item for item in rack if item["low"][1] > -0.4 and
                    item["high"][1] - item["low"][1] > 0.3 and
                    item["high"][2] - item["low"][2] > 0.3]
        assert not uprights, uprights
        assert max(item["high"][0] - item["low"][0] for item in rack) >= 0.46
    parcels = node_bounds(g, bins, lambda name: "Parcel" in name)
    assert 3 <= len(parcels) <= 6, parcels
    left_parcels = [item for item in parcels if item["name"].startswith("Left")]
    right_parcels = [item for item in parcels if item["name"].startswith("Right")]
    assert left_parcels and right_parcels
    assert_inside(left_parcels, (-1.15, -0.60, -1.20), (-0.60, 0.80, 1.20), "parcel izquierdo")
    assert_inside(right_parcels, (0.60, -0.60, -1.20), (1.15, 0.80, 1.20), "parcel derecho")

    tris = sum(len(glb_check.read_accessor(g, bins, primitive["indices"])) // 3
               for mesh in g.get("meshes", []) for primitive in mesh["primitives"])
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
        nodes = len(scene_nodes(glb_check.load_glb(str(glb))[0]))
        print("INTERIOR_TEST_OK tris=%d nodes=%d corridor=%.3f deterministic=yes" %
              (tris, nodes, corridor))
        return glb, tris


if __name__ == "__main__":
    main()
