"""Reproducible wheel generator and aggregate budget.

    python tools/blender_bus_wheel_test.py [--blender <path>]
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
import blender_van_test
import blender_bus_interior_test

WINDOWS_DEFAULT = r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"
REGIONS = {
    "tread": (0.02, 0.02, 0.31, 0.98),
    "sidewall": (0.34, 0.02, 0.48, 0.98),
    "rim": (0.52, 0.02, 0.98, 0.98),
}


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
    return {finding["check"]: finding["pass"] for finding in json.loads(result.stdout)["findings"]}


def region_for(name):
    if name == "TireTread":
        return "tread"
    if name.startswith("TireSidewall"):
        return "sidewall"
    return "rim"


def validate(path):
    checks = invoked_findings(path)
    assert all(checks.values()), [name for name, ok in checks.items() if not ok]
    gltf, bins = glb_check.load_glb(str(path))
    assert not gltf.get("images", []), "GLB no debe embeber imágenes"
    assert len(gltf.get("materials", [])) == 1
    assert gltf["materials"][0]["name"] == "placeholder_wheel"

    positions = []
    triangles = 0
    names = {node.get("name", "") for node in gltf.get("nodes", []) if "mesh" in node}
    required = {"TireTread", "TireSidewallInner", "TireSidewallOuter", "RimOuter",
                "RimDisc", "RimHubCap", "ValveStem"}
    required.update("RimLug%02d" % index for index in range(6))
    assert required <= names, sorted(required - names)
    assert not any(name.startswith("RimSpoke") for name in names), "rin deportivo con radios"
    assert sum(name.startswith("RimLug") for name in names) == 6
    assert sum(name == "ValveStem" for name in names) == 1

    categories = set()
    for node in gltf.get("nodes", []):
        name = node.get("name", "")
        assert "-col" not in name.lower()
        if "mesh" not in node:
            continue
        category = region_for(name)
        categories.add(category)
        u0, v0, u1, v1 = REGIONS[category]
        for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
            assert primitive.get("material") == 0
            assert "TEXCOORD_0" in primitive["attributes"], "UV0 ausente"
            for u, v in glb_check.read_accessor(gltf, bins, primitive["attributes"]["TEXCOORD_0"]):
                assert u0 - 1e-3 <= u <= u1 + 1e-3 and v0 - 1e-3 <= v <= v1 + 1e-3, \
                    "%s UV (%.3f, %.3f) fuera de %s" % (name, u, v, category)
            positions.extend(glb_check.read_accessor(gltf, bins, primitive["attributes"]["POSITION"]))
            triangles += len(glb_check.read_accessor(gltf, bins, primitive["indices"])) // 3
    assert categories == set(REGIONS)
    assert triangles <= 1500, "rueda %d > 1500" % triangles

    minimum = [min(position[axis] for position in positions) for axis in range(3)]
    maximum = [max(position[axis] for position in positions) for axis in range(3)]
    center = [(minimum[axis] + maximum[axis]) / 2 for axis in range(3)]
    assert max(abs(value) for value in center) <= 0.002, "rueda no centrada: %s" % center
    width = maximum[0] - minimum[0]
    radii = [math.hypot(position[1], position[2]) for position in positions]
    assert 0.17 <= width <= 0.22, "neumático no estrecho o eje incorrecto: %.3f" % width
    assert math.isclose(max(radii), 0.5, abs_tol=0.002), "radio máximo %.4f" % max(radii)
    hub_positions = []
    disc_positions = []
    for node in gltf.get("nodes", []):
        if "mesh" not in node or node.get("name") not in ("RimHubCap", "RimDisc"):
            continue
        target = hub_positions if node["name"] == "RimHubCap" else disc_positions
        for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
            target.extend(glb_check.read_accessor(
                gltf, bins, primitive["attributes"]["POSITION"]))
    assert hub_positions and 0.098 <= max(math.hypot(p[1], p[2]) for p in hub_positions) <= 0.102, \
        "buje pesado inválido"
    # Boolean hole rims must leave vertices around each of four expected centers.
    for index in range(4):
        angle = math.tau * index / 4 + math.pi / 4
        center_y, center_z = 0.168 * math.cos(angle), 0.168 * math.sin(angle)
        distances = [math.hypot(p[1] - center_y, p[2] - center_z) for p in disc_positions]
        assert distances and min(abs(distance - 0.030) for distance in distances) <= 0.003, \
            "ventilación %d ausente" % index
    forbidden = ("pirelli", "michelin", "goodyear", "logo", "text")
    assert not any(word in name.lower() for name in names for word in forbidden), sorted(names)
    return triangles, max(radii)


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
