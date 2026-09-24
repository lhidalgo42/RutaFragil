"""Generate the clean bus interior GLB with Blender 5.1.

    blender --background --factory-startup --python tools/blender_bus_interior.py -- <output.glb>
"""
import math
from pathlib import Path
import sys

import bpy


if bpy.app.version[:2] != (5, 1):
    raise SystemExit("Blender 5.1 required, found %s" % (bpy.app.version_string,))

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) != 1 or Path(argv[0]).suffix.lower() != ".glb":
    raise SystemExit("usage: blender_bus_interior.py -- <output.glb>")
out = Path(argv[0]).resolve()
out.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
material = bpy.data.materials.new("placeholder_interior")
material.use_nodes = True
material.diffuse_color = (0.62, 0.57, 0.42, 1.0)
material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = material.diffuse_color


def box(name, location, dimensions, bevel=0.015, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("edge_softening", "BEVEL")
        modifier.width = min(bevel, min(dimensions) * 0.2)
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(material)
    return obj


def rack(prefix, x, y, length):
    for index, z in enumerate((0.10, 0.75, 1.40)):
        box(prefix + "Shelf%d" % index, (x, y, z), (0.34, length, 0.055), 0.008)
    for end in (-length / 2 + 0.04, length / 2 - 0.04):
        for edge in (-0.14, 0.14):
            box(prefix + "Post_%s_%s" % ("Rear" if end < 0 else "Front",
                                           "Outer" if edge * x > 0 else "Inner"),
                (x + edge, y + end, 0.75), (0.045, 0.045, 1.30), 0.005)


def seat(prefix, x, y):
    box(prefix + "Cushion", (x, y, 0.58), (0.48, 0.52, 0.16), 0.045)
    box(prefix + "Back", (x, y - 0.20, 1.05), (0.48, 0.15, 0.82), 0.05,
        rotation=(math.radians(-8), 0.0, 0.0))
    box(prefix + "Headrest", (x, y - 0.25, 1.53), (0.31, 0.13, 0.24), 0.04)
    box(prefix + "Pedestal", (x, y, 0.30), (0.16, 0.16, 0.42), 0.02)


# Liners: visible floor/roof, left wall, right wall split around the side opening.
# Wrapper sits at bus y -0.65: floor liner top 0.05 = physics floor top -0.60.
# Liners stop 1 cm short of the exterior shell (|x| 1.175, |y| 3.82): no shared planes.
box("FloorLiner", (0.0, 0.0, 0.025), (2.10, 7.60, 0.05), 0.01)
box("RoofLiner", (0.0, 0.0, 1.95), (2.10, 7.60, 0.08), 0.025)
box("LeftWallLiner", (-1.07, 0.0, 1.00), (0.08, 7.60, 1.90), 0.018)
box("RightCargoWallLiner", (1.07, -0.77, 1.00), (0.08, 6.06, 1.90), 0.018)
box("RightCabWallLiner", (1.07, 3.51, 1.00), (0.08, 0.58, 1.90), 0.018)
box("RightBoardingHeader", (1.07, 2.75, 1.99), (0.08, 0.90, 0.14), 0.015)

# Narrow inner wheel wells hide the tire portion above the floor. They stay
# visual-only and leave the outer half of every wheel visible from outside.
for name, x, y in (("WheelWellFL", -0.90, 2.75), ("WheelWellFR", 0.90, 2.75),
                   ("WheelWellRR", 0.90, -2.75)):
    box(name, (x, y, 0.36), (0.08, 1.08, 0.68), 0.015)

# Rear liner surrounds the same 1.4 x 1.9 m usable opening as the exterior.
box("RearLeftLiner", (-0.91, -3.77, 0.93), (0.32, 0.08, 1.78), 0.015)
box("RearRightLiner", (0.91, -3.77, 0.93), (0.32, 0.08, 1.78), 0.015)
box("RearOpeningHeader", (0.0, -3.77, 1.91), (1.50, 0.08, 0.16), 0.015)

# Fixtures align with the authored collision boxes after centering and wrapper offset.
# Rack inner edges are x=+-0.72: a measured 1.44 m central corridor.
rack("LeftRack", -0.875, 0.0, 2.35)
rack("RightRack", 0.875, 0.0, 2.35)

# Bench and stretcher sit inside their existing colliders. The solid bench also
# covers the rear-left tire; the narrow stretcher leaves room for its wheel well.
box("BenchBase", (-0.875, -2.9, 0.275), (0.46, 1.16, 0.43), 0.02)
box("BenchCushion", (-0.875, -2.9, 0.57), (0.46, 1.16, 0.16), 0.045)
box("BenchBack", (-1.03, -2.9, 0.80), (0.10, 1.16, 0.30), 0.035)
box("StretcherDeck", (0.68, -2.2, 0.26), (0.32, 1.76, 0.08), 0.025)
for y in (-2.95, -1.45):
    box("StretcherLeg_%s" % ("Rear" if y < -2.2 else "Front"),
        (0.68, y, 0.14), (0.22, 0.08, 0.16), 0.012)

# Two visual-only front seats.
seat("DriverSeat", -0.52, 3.10)
seat("CopilotSeat", 0.52, 3.10)
box("Dashboard", (0.0, 3.62, 1.02), (1.82, 0.24, 0.32), 0.045)

# Boarding steps occupy the sill, not the 1.44 m cargo corridor.
box("BoardingStepLower", (0.97, 2.73, 0.14), (0.48, 0.72, 0.16), 0.018)
box("BoardingStepUpper", (0.83, 2.73, 0.30), (0.32, 0.72, 0.16), 0.018)

# UV0 targets semantic quadrants in the external atlas; no image is embedded.
regions = {
    # Blender V is bottom-up; top PNG quadrants therefore use high Blender V.
    "floor": (0.02, 0.52, 0.48, 0.98),
    "rack": (0.52, 0.52, 0.98, 0.98),
    "seat": (0.02, 0.02, 0.48, 0.48),
    "wall": (0.52, 0.02, 0.98, 0.48),
}
meshes = sorted((item for item in bpy.context.scene.objects if item.type == "MESH"), key=lambda item: item.name)
for obj in meshes:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    region = "floor" if obj.name.startswith(("Floor", "BoardingStep")) else \
        "rack" if obj.name.startswith("LeftRack") or obj.name.startswith("RightRack") else \
        "seat" if obj.name.startswith(("DriverSeat", "CopilotSeat", "Bench", "Stretcher")) else "wall"
    u0, v0, u1, v1 = regions[region]
    for uv in obj.data.uv_layers.active.data:
        uv.uv = (u0 + uv.uv.x * (u1 - u0), v0 + uv.uv.y * (v1 - v0))
    obj.select_set(False)

# Center the complete authored bbox. The wrapper positions this visual independently of physics.
low = [min(vertex.co[axis] for obj in meshes for vertex in obj.data.vertices) for axis in range(3)]
high = [max(vertex.co[axis] for obj in meshes for vertex in obj.data.vertices) for axis in range(3)]
shift = [-(low[axis] + high[axis]) / 2 for axis in range(3)]
for obj in meshes:
    for vertex in obj.data.vertices:
        for axis in range(3):
            vertex.co[axis] += shift[axis]

bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True,
                          export_apply=True, export_image_format="NONE",
                          export_texcoords=True, export_normals=True,
                          export_tangents=False, export_animations=False,
                          export_cameras=False, export_lights=False)
print("INTERIOR_OK objects=%d corridor=1.44 output=%s" % (len(bpy.context.scene.objects), out))
