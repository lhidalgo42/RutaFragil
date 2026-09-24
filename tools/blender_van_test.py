"""Reproducible exterior generator: temp GLBs, glb_check, direct openings and UV regions.

    python tools/blender_van_test.py [--blender <path>]

Blender is searched in --blender, then BLENDER, PATH, and the Windows default.
Godot frame: -Z is front, +Z rear; the wrapper puts the GLB base at bus y=-0.8.
"""
import argparse
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


def world_matrices(g):
    identity = [[1 if row == col else 0 for col in range(4)] for row in range(4)]
    out = {}
    stack = [(index, identity) for index in g["scenes"][g.get("scene", 0)].get("nodes", [])]
    while stack:
        index, parent = stack.pop()
        world = glb_check.mat_mul(parent, glb_check.node_matrix(g["nodes"][index]))
        out[index] = world
        stack.extend((child, world) for child in g["nodes"][index].get("children", []))
    return out


def node_bounds(g, bins, predicate):
    out = []
    worlds = world_matrices(g)
    for index, node in mesh_nodes(g, predicate):
        positions = []
        for primitive in g["meshes"][node["mesh"]]["primitives"]:
            positions.extend(glb_check.apply(worlds[index], position) for position in
                             glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"]))
        out.append({"name": node.get("name", ""), "positions": positions,
                    "low": [min(p[k] for p in positions) for k in range(3)],
                    "high": [max(p[k] for p in positions) for k in range(3)]})
    assert out, "sin malla"
    return out


def assert_gap(g, bins, dimensions, excluded=()):
    """No world-space face box may intersect the opening; None = unconstrained axis."""
    excluded_meshes = {node["mesh"] for _index, node in mesh_nodes(g, lambda name: name in excluded)}
    for mesh_index, world in glb_check.mesh_instances(g):
        if mesh_index in excluded_meshes:
            continue
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
    assert len(g.get("nodes", [])) <= 60, len(g.get("nodes", []))
    # Door pivots are the only transformed nodes: they are the hinges/slide origins.
    pivots = {"SideDoorPivot", "RearDoorLeftPivot", "RearDoorRightPivot"}
    for node in g.get("nodes", []):
        assert "-col" not in node.get("name", "").lower(), "nombre prohibido -col"
        if node.get("name", "") not in pivots:
            assert not node.get("translation") and not node.get("rotation") and not node.get("matrix"), \
                "%s con transformación fuera de la jerarquía de puertas" % node.get("name")

    # Exact animatable hierarchy: one static shell, three pivot/leaf pairs, leaves at identity.
    roots = {g["nodes"][index].get("name", ""): index
             for index in g["scenes"][g.get("scene", 0)].get("nodes", [])}
    assert set(roots) == {"StaticShell", "SideDoorPivot", "RearDoorLeftPivot", "RearDoorRightPivot"}, roots
    for pivot_name, leaf_name, expected in (
            ("SideDoorPivot", "SideDoorLeaf", (1.252, 1.04, -1.30)),
            ("RearDoorLeftPivot", "RearDoorLeftLeaf", (-0.72, 0.0, 4.10)),
            ("RearDoorRightPivot", "RearDoorRightLeaf", (0.72, 0.0, 4.10))):
        pivot = g["nodes"][roots[pivot_name]]
        children = pivot.get("children", [])
        assert len(children) == 1 and g["nodes"][children[0]].get("name", "") == leaf_name, pivot
        for got, want in zip(pivot.get("translation", []), expected):
            assert abs(got - want) <= 0.002, (pivot_name, pivot.get("translation"), expected)
        leaf = g["nodes"][children[0]]
        assert "mesh" in leaf and not leaf.get("translation") and not leaf.get("rotation"), leaf

    # UV atlas regions survive the merge: sample one corner piece per region inside StaticShell.
    shell_mesh = g["nodes"][roots["StaticShell"]]["mesh"]
    shell_positions = set()
    shell_uv = []
    for primitive in g["meshes"][shell_mesh]["primitives"]:
        raw = glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"])
        uvs = glb_check.read_accessor(g, bins, primitive["attributes"]["TEXCOORD_0"])
        indexes = glb_check.read_accessor(g, bins, primitive["indices"])
        for index in indexes:
            shell_positions.add(tuple(round(v, 4) for v in raw[index]))
            shell_uv.append((tuple(round(v, 4) for v in raw[index]), uvs[index]))
    probes = [
        ((0.0, 2.39, -3.35), "cream"),            # RoofCrown apex
        ((0.78, 0.70, -4.19), "cream"),           # Headlight face
        ((-1.10, 0.10, 4.11), "red"),             # RearLightLeft face
        ((-1.268, 1.10, 3.80), "red"),            # RedStripeLeft
        ((-1.256, 1.28, -3.76), "glass"),         # LeftCabSideGlass corner
        ((0.95, 0.01, 3.87), "dark"),             # Underbody
        ((1.12, 0.044, 4.216), "yellow"),         # RearStepBumper
    ]
    for probe, region in probes:
        u0, v0, u1, v1 = UV_REGIONS[region]
        near = [uv for position, uv in shell_uv
                if math.dist(position, probe) <= 0.25]
        assert near, "sin vértices cerca de %s" % (probe,)
        assert any(u0 - 1e-3 <= u <= u1 + 1e-3 and v0 - 1e-3 <= v <= v1 + 1e-3
                   for u, v in near), (probe, region, near[:4])

    # Every leaf UV also lands in its semantic region (panels yellow, details dark/red).
    for leaf_name, region in (("SideDoorLeaf", "yellow"),
                              ("RearDoorLeftLeaf", "yellow"),
                              ("RearDoorRightLeaf", "yellow")):
        leaf_node = g["nodes"][roots[leaf_name.replace("Leaf", "Pivot")]]["children"][0]
        u0, v0, u1, v1 = UV_REGIONS[region]
        for primitive in g["meshes"][g["nodes"][leaf_node]["mesh"]]["primitives"]:
            uvs = glb_check.read_accessor(g, bins, primitive["attributes"]["TEXCOORD_0"])
            assert any(u0 - 1e-3 <= u <= u1 + 1e-3 and v0 - 1e-3 <= v <= v1 + 1e-3
                       for u, v in uvs), (leaf_name, region)

    # Openings (Godot frame: -Z front; wrapper puts model y0 at bus y -0.8).
    # Doorway moved aft: Godot z[-2.2,-1.3]; the closed SideDoorLeaf is the only face inside.
    assert_gap(g, bins, ((1.15, 1.27), (1.12, 2.02), (-2.19, -1.31)), excluded=("SideDoorLeaf",))
    # The old doorway column above the front wheel is now closed body.
    old_doorway = ((1.15, 1.27), (1.12, 2.02), (-3.19, -2.31))
    covered = False
    for mesh_index, world in glb_check.mesh_instances(g):
        for primitive in g["meshes"][mesh_index]["primitives"]:
            positions = [glb_check.apply(world, p)
                         for p in glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"])]
            indexes = glb_check.read_accessor(g, bins, primitive["indices"])
            for start in range(0, len(indexes), 3):
                face = indexes[start:start + 3]
                low = [min(positions[v][axis] for v in face) for axis in range(3)]
                high = [max(positions[v][axis] for v in face) for axis in range(3)]
                if all(high[axis] > old_doorway[axis][0] and low[axis] < old_doorway[axis][1]
                       for axis in range(3)):
                    covered = True
    assert covered, "el vano antiguo sobre la rueda quedó abierto"
    assert_gap(g, bins, ((-0.68, 0.68), (0.15, 2.18), (3.84, 4.01)),
               excluded=("RearDoorLeftLeaf", "RearDoorRightLeaf"))         # rear, >=1.4 x 1.9
    assert_gap(g, bins, ((-0.90, 0.90), (1.06, 2.00), (-4.08, -3.70)))       # raked windshield
    assert_gap(g, bins, ((-0.68, -0.52), (1.40, 1.70), (-3.76, -3.55)))      # CabinCamera cone
    assert_gap(g, bins, ((0.52, 0.68), (1.40, 1.70), (-3.76, -3.55)))        # CopilotCamera cone

    # Moved doorway clears the front-right tire at both steering locks. Projecting
    # tire radius 0.50 and half-width 0.11 onto z gives the conservative rear edge.
    doorway_front_z = -2.20
    for steer_deg in (-30.0, 30.0):
        steer = math.radians(steer_deg)
        wheel_rear_z = -2.75 + 0.50 * abs(math.cos(steer)) + 0.11 * abs(math.sin(steer))
        assert doorway_front_z - wheel_rear_z >= 0.05, (steer_deg, wheel_rear_z, doorway_front_z)

    # Closed side leaf fills the doorway: y 1.12..2.02 x z -2.20..-1.30 in the x 1.24..1.36 slab.
    side = node_bounds(g, bins, lambda name: name == "SideDoorLeaf")[0]
    assert 1.24 <= side["low"][0] and side["high"][0] <= 1.36, side["name"]
    assert side["low"][1] <= 1.12 and side["high"][1] >= 2.02, side["name"]
    assert abs(side["low"][2] + 2.20) <= 0.01 and abs(side["high"][2] + 1.30) <= 0.01, side["name"]
    # Leaf origin sits on its slide pivot: local mesh minimum corner is the pivot itself.
    pivot_local = g["meshes"][g["nodes"][g["nodes"][roots["SideDoorPivot"]]["children"][0]]["mesh"]]
    local_positions = [p for primitive in pivot_local["primitives"]
                       for p in glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"])]
    assert min(p[0] for p in local_positions) >= -0.001
    assert min(p[1] for p in local_positions) >= -0.001

    # Closed rear leaves cover the 1.40 m aperture just aft of the fixed frame.
    rear_bounds = []
    for leaf_name in ("RearDoorLeftLeaf", "RearDoorRightLeaf"):
        leaf = node_bounds(g, bins, lambda name, wanted=leaf_name: name == wanted)[0]
        assert 4.06 <= leaf["low"][2] and leaf["high"][2] <= 4.18, (leaf["name"], leaf["low"], leaf["high"])
        assert leaf["low"][1] <= 0.181 and leaf["high"][1] >= 2.039, leaf["name"]
        rear_bounds.append(leaf)
    left_leaf, right_leaf = rear_bounds
    # Panels run hinge pin outward 45 mm (knuckle) to centre seam (|x| <= 5 mm).
    assert abs(left_leaf["low"][0] + 0.765) <= 0.002 and -0.01 <= left_leaf["high"][0] <= 0.0, \
        (left_leaf["low"], left_leaf["high"])
    assert abs(right_leaf["high"][0] - 0.765) <= 0.002 and 0.0 <= right_leaf["low"][0] <= 0.01, \
        (right_leaf["low"], right_leaf["high"])
    # Hinge pins: local mesh extends inboard (toward the other leaf) from the pivot.
    for pivot_name, sign in (("RearDoorLeftPivot", 1.0), ("RearDoorRightPivot", -1.0)):
        leaf_node = g["nodes"][roots[pivot_name]]["children"][0]
        local = [p for primitive in g["meshes"][g["nodes"][leaf_node]["mesh"]]["primitives"]
                 for p in glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"])]
        # Hinge knuckles extend 45 mm outboard from the pivot; panel extends inward.
        assert min(sign * p[0] for p in local) >= -0.046
        assert max(sign * p[0] for p in local) >= 0.70, pivot_name

    # Simulated poses in the test: closed shell never meets the popped or slid leaf,
    # and the rear swing leaves the pinned aperture fully clear.
    shell_world = [world for mesh_index, world in glb_check.mesh_instances(g)
                   if mesh_index == shell_mesh]
    assert len(shell_world) == 1

    def shell_faces():
        for primitive in g["meshes"][shell_mesh]["primitives"]:
            positions = glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"])
            indexes = glb_check.read_accessor(g, bins, primitive["indices"])
            for start in range(0, len(indexes), 3):
                face = indexes[start:start + 3]
                yield ([min(positions[v][axis] for v in face) for axis in range(3)],
                       [max(positions[v][axis] for v in face) for axis in range(3)])

    def leaf_faces(node_index, transform):
        for primitive in g["meshes"][g["nodes"][node_index]["mesh"]]["primitives"]:
            raw = glb_check.read_accessor(g, bins, primitive["attributes"]["POSITION"])
            positions = [glb_check.apply(transform, p) for p in raw]
            indexes = glb_check.read_accessor(g, bins, primitive["indices"])
            for start in range(0, len(indexes), 3):
                face = indexes[start:start + 3]
                yield ([min(positions[v][axis] for v in face) for axis in range(3)],
                       [max(positions[v][axis] for v in face) for axis in range(3)])

    def overlap(a_low, a_high, b_low, b_high):
        return all(a_high[axis] > b_low[axis] + 0.002 and
                   b_high[axis] > a_low[axis] + 0.002 for axis in range(3))

    def yaw_matrix(origin, radians):
        c, s = math.cos(radians), math.sin(radians)
        return [[c, 0.0, s, origin[0]], [0.0, 1.0, 0.0, origin[1]],
                [-s, 0.0, c, origin[2]], [0.0, 0.0, 0.0, 1.0]]

    def translation_matrix(offset):
        return [[1.0, 0.0, 0.0, offset[0]], [0.0, 1.0, 0.0, offset[1]],
                [0.0, 0.0, 1.0, offset[2]], [0.0, 0.0, 0.0, 1.0]]

    static = list(shell_faces())
    side_node = g["nodes"][roots["SideDoorPivot"]]["children"][0]
    side_origin = g["nodes"][roots["SideDoorPivot"]]["translation"]
    popped = translation_matrix((side_origin[0] + 0.035, side_origin[1], side_origin[2]))
    slid = translation_matrix((side_origin[0] + 0.035, side_origin[1], side_origin[2] + 0.95))
    for pose, transform in (("popped", popped), ("open", slid)):
        clashes = sum(1 for low, high in leaf_faces(side_node, transform)
                      for slow, shigh in static if overlap(low, high, slow, shigh))
        assert clashes == 0, "hoja lateral %s cruza el shell: %d caras" % (pose, clashes)
    slid_bounds = [glb_check.apply(slid, p) for p in local_positions]
    # Open leaf parks fully aft of the doorway (z > -1.30), outboard of the shell skin.
    assert min(p[2] for p in slid_bounds) >= -1.30, min(p[2] for p in slid_bounds)
    assert min(p[0] for p in slid_bounds) >= 1.285, min(p[0] for p in slid_bounds)

    aperture = ((-0.68, 0.68), (0.15, 2.18), (3.84, 4.01))
    for pivot_name, sign in (("RearDoorLeftPivot", -1.0), ("RearDoorRightPivot", 1.0)):
        leaf_node = g["nodes"][roots[pivot_name]]["children"][0]
        origin = g["nodes"][roots[pivot_name]]["translation"]
        for degrees in range(0, 133, 12):
            transform = yaw_matrix(origin, math.radians(sign * degrees))
            faces = list(leaf_faces(leaf_node, transform))
            clashes = sum(1 for low, high in faces
                          for slow, shigh in static if overlap(low, high, slow, shigh))
            assert clashes == 0, "%s a %d° cruza el shell: %d caras" % (pivot_name, degrees, clashes)
            assert min(low[2] for low, _high in faces) >= 4.00, (pivot_name, degrees)
        transform = yaw_matrix(origin, math.radians(sign * 132))
        for low, high in leaf_faces(leaf_node, transform):
            assert not all(high[axis] > aperture[axis][0] and low[axis] < aperture[axis][1]
                           for axis in range(3)), (pivot_name, low, high)

    # v6 silhouette and finishing cues survive inside the merged StaticShell vertices.
    assert any(p[1] >= 2.38 for p in shell_positions), "RoofCrown apex perdido"
    assert any(p[2] <= -4.10 for p in shell_positions), "morro cab-over perdido"
    assert any(p[2] >= 4.23 for p in shell_positions), "RearPlateRecess perdido"
    assert any(abs(p[0]) >= 1.56 for p in shell_positions), "MirrorPods perdidos"
    assert any(abs(p[1] - 2.075) < 0.02 and -2.30 <= p[2] <= -1.95 for p in shell_positions), \
        "cabecera de la puerta no se movió con el vano"
    assert sum(1 for p in shell_positions if abs(p[0]) >= 1.55) >= 16, "espejos incompletos"

    # Wheel-arch lips stay the only arch geometry; liners clear the steered sweep.
    lips = [p for p in shell_positions if abs(p[1] - 0.40) <= 0.66 and 1.20 <= abs(p[0]) <= 1.28]
    assert lips, "labios de arco perdidos en la unión"

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
