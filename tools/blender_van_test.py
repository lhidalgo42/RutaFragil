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
        if name.startswith("RedStripe") or "RearLight" in name or "Marker" in name:
            return "red"
        if name.startswith("Roof") or "Headlight" in name or name in ("CabBrow", "RearPlateRecess"):
            return "cream"
        if "CabSideGlass" in name or "MirrorGlass" in name:
            return "glass"
        if name in ("RearLowerFascia", "RearStepBumper"):
            return "yellow"
        dark_words = ("Underbody", "WheelArch", "WheelLiner", "Gasket", "Rail", "Handle",
                      "Bumper", "MirrorArm", "Hinge", "Threshold", "JambTrim", "HeaderTrim",
                      "DarkFascia", "Grille", "Bezel", "Inset", "Latch", "SillTrim")
        return "dark" if any(word in name for word in dark_words) else "yellow"

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
    assert_gap(g, bins, ((-0.90, 0.90), (1.06, 2.00), (-4.08, -3.70)))       # raked windshield
    assert_gap(g, bins, ((-0.68, -0.52), (1.40, 1.70), (-3.76, -3.55)))      # CabinCamera cone
    assert_gap(g, bins, ((0.52, 0.68), (1.40, 1.70), (-3.76, -3.55)))        # CopilotCamera cone

    # Only thin concentric lips may carry WheelArch: reject the old giant black patches.
    arches = node_bounds(g, bins, lambda name: "WheelArch" in name)
    assert len(arches) == 4
    for item in arches:
        assert "Lip" in item["name"], "parche rectangular antiguo: %s" % item["name"]
        assert item["high"][0] - item["low"][0] <= 0.06, item["name"]
        z_center = (item["low"][2] + item["high"][2]) / 2
        y_center = item["low"][1]
        assert abs(abs(z_center) - 2.75) <= 0.02, (item["name"], z_center)
        assert 0.32 <= y_center <= 0.45, (item["name"], y_center)
        inner = min(math.hypot(p[2] - z_center, p[1] - y_center) for p in item["positions"])
        assert inner - (y_center - 0.32) >= 0.5, (item["name"], inner, y_center)

    # Liners clear the steered front wheel sweep: sqrt(0.5^2 + 0.11^2) = 0.512.
    liners = node_bounds(g, bins, lambda name: "WheelLiner" in name)
    assert len(liners) == 4
    for item in liners:
        z_center = (item["low"][2] + item["high"][2]) / 2
        y_center = item["low"][1]
        inner = min(math.hypot(p[2] - z_center, p[1] - y_center) for p in item["positions"])
        assert inner >= 0.515, (item["name"], inner)

    # v6 silhouette and finishing cues; each rejects a conspicuous v5 shortcut.
    names = {node.get("name", "") for _i, node in mesh_nodes(g, lambda _name: True)}
    required = {"RoofCrown", "CabBrow", "FrontRoundedNose", "FrontDarkFascia",
                "FasciaGrille", "FrontBumper", "HeadlightLeft", "HeadlightRight",
                "HeadlightBezelLeft", "HeadlightBezelRight",
                "WindshieldPillarLeft", "WindshieldPillarRight",
                "WindshieldGasketLeft", "WindshieldGasketRight",
                "WindshieldGasketLower", "WindshieldGasketUpper",
                "WindshieldInnerLowerTrim", "WindshieldInnerUpperTrim",
                "LeftCabSideGlass", "RightCabSideGlass",
                "LeftMirrorPod", "RightMirrorPod", "LeftMirrorGlass", "RightMirrorGlass",
                "RightDoorRearJambTrim", "RightDoorFrontJambTrim",
                "RightDoorHeaderTrim", "RightDoorThreshold",
                "SlidingDoorParked", "SlidingDoorInset", "SlidingDoorRail", "SlidingDoorHandle",
                "RearDoorLeftOpen", "RearDoorRightOpen",
                "RearDoorLeftInsetUpper", "RearDoorRightInsetUpper",
                "RearDoorLeftInsetLower", "RearDoorRightInsetLower",
                "RearDoorLeftLatch", "RearDoorRightLatch",
                "RearApertureGasketLeft", "RearApertureGasketRight",
                "RearHeaderTrim", "RearSillTrim", "RearLowerFascia", "RearPlateRecess",
                "RearStepBumper", "RearLightLeft", "RearLightRight",
                "RearUpperMarker0", "RearUpperMarker1", "RearUpperMarker2",
                "RedStripeSlidingDoor", "RedStripeRearDoorLeft", "RedStripeRearDoorRight"}
    assert required <= names, sorted(required - names)
    assert not any("HighWindow" in name or "DoorWindow" in name or
                   "RearDoorLeftWindow" in name or "RearDoorRightWindow" in name
                   for name in names), "v5 cargo/rear glazing survived"
    assert sum(name.startswith("RearDoor") and "Hinge" in name for name in names) == 4

    roof = node_bounds(g, bins, lambda name: name == "RoofCrown")[0]
    assert roof["high"][1] >= 2.34 and roof["high"][2] >= 4.00, roof["high"]
    # Raked A-pillar face, yet deep enough to seat the wrapper's flat glass (z=-3.85).
    for item in node_bounds(g, bins, lambda name: name.startswith("WindshieldPillar")):
        lower_front = min(p[2] for p in item["positions"] if p[1] < 1.1)
        upper_front = min(p[2] for p in item["positions"] if p[1] > 1.9)
        assert upper_front - lower_front >= 0.20, (item["name"], lower_front, upper_front)
        assert upper_front <= -3.86 and item["high"][2] >= -3.84, item["name"]

    # Half-height datum remains aligned across shell, parked panel and both leaves.
    stripes = node_bounds(g, bins, lambda name: name.startswith("RedStripe"))
    assert len(stripes) == 6
    for item in stripes:
        band = item["high"][1] - item["low"][1]
        assert 0.12 <= band <= 0.14, (item["name"], band)
        assert 1.03 <= item["low"][1] <= 1.05 and 1.16 <= item["high"][1] <= 1.18, item["name"]

    # Parked panel: thin slab with an inset, never a fake doorway.
    door = node_bounds(g, bins, lambda name: name == "SlidingDoorParked")[0]
    assert 1.28 <= door["low"][0] and door["high"][0] <= 1.40, door["name"]
    assert door["low"][2] >= -2.30 and door["high"][2] <= -1.20, door["name"]
    threshold = node_bounds(g, bins, lambda name: name == "RightDoorThreshold")[0]
    assert threshold["high"][1] <= 1.105, threshold["high"]

    # Rear leaves visibly swing outboard and aft of the rear body plane.
    for side in ("Left", "Right"):
        leaf = node_bounds(g, bins, lambda name: name == "RearDoor%sOpen" % side)[0]
        assert leaf["high"][2] >= 4.15, (leaf["name"], leaf["high"][2])
        assert max(abs(leaf["low"][0]), abs(leaf["high"][0])) >= 1.10, leaf["name"]

    for side in ("Left", "Right"):
        pod = node_bounds(g, bins, lambda name: name == "%sMirrorPod" % side)[0]
        assert max(abs(pod["low"][0]), abs(pod["high"][0])) >= 1.45, pod["name"]

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
