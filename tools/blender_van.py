"""Generate the clean bus exterior GLB with Blender 5.1.

    blender --background --factory-startup --python tools/blender_van.py -- <output.glb>

Blender frame: +Y front, +Z up, base at z=0. glTF/Godot: -Z front, +Y up.
The wrapper places this base at bus y=-0.8, so the roof top (2.30) lands at 1.50.
"""
import math
from pathlib import Path
import sys

import bpy


if bpy.app.version[:2] != (5, 1):
    raise SystemExit("Blender 5.1 required, found %s" % (bpy.app.version_string,))

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) != 1 or Path(argv[0]).suffix.lower() != ".glb":
    raise SystemExit("usage: blender_van.py -- <output.glb>")
out = Path(argv[0]).resolve()
out.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
material = bpy.data.materials.new("placeholder_exterior")
material.use_nodes = True
material.diffuse_color = (0.95, 0.62, 0.03, 1.0)
material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = material.diffuse_color

# Atlas regions in Blender UV (V bottom-up); glTF stores 1-V, so yellow is the PNG's top half.
REGIONS = {
    "yellow": (0.02, 0.52, 0.98, 0.98),
    "red": (0.02, 0.02, 0.23, 0.48),
    "cream": (0.27, 0.02, 0.48, 0.48),
    "glass": (0.52, 0.02, 0.73, 0.48),
    "dark": (0.77, 0.02, 0.98, 0.48),
}


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


def box(name, y0, y1, z0, z1, x0, x1, bevel=0.025):
    dimensions = (x1 - x0, y1 - y0, z1 - z0)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    # Identity nodes: vertices are final coordinates for glb_check and the wrapper.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel:
        modifier = obj.modifiers.new("edge_softening", "BEVEL")
        modifier.width = min(bevel, min(dimensions) * 0.2)
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(material)
    return obj


def flank(name, side, y0, y1, z0, z1, bevel=0.025):
    """Side panel 0.075 m thick, outer face at |x|=1.25; the interior liner sits inside |x|=1.17."""
    return box(name, y0, y1, z0, z1, *((1.175, 1.25) if side > 0 else (-1.25, -1.175)), bevel=bevel)


def arch(name, side, longitudinal, center_z=0.40, inner=0.60, half=0.70, segments=12):
    """Closed wheel-arch panel: semicircular inner edge, rectangular outer edge flush with the skirt.
    Static wheel centre is bus y -0.48 (model z 0.32 with the wrapper at -0.8); the arch sits
    0.08 higher with a 0.60 radius, leaving ~0.18 m of visual suspension travel."""
    xs = (1.175, 1.25) if side > 0 else (-1.25, -1.175)
    vertices = []
    for x in xs:
        for ring in (0, 1):
            for index in range(segments + 1):
                angle = math.pi * index / segments
                c, s = math.cos(angle), math.sin(angle)
                radius = inner if ring == 0 else min(half / max(abs(c), 1e-9), half / max(s, 1e-9))
                vertices.append((x, longitudinal + radius * c, center_z + radius * s))

    def v(side_index, ring, index):
        return side_index * 2 * (segments + 1) + ring * (segments + 1) + index

    faces = []
    for i in range(segments):
        j = i + 1
        faces += [(v(0, 1, i), v(1, 1, i), v(1, 1, j), v(0, 1, j)),
                  (v(0, 0, j), v(1, 0, j), v(1, 0, i), v(0, 0, i)),
                  (v(0, 0, i), v(0, 1, i), v(0, 1, j), v(0, 0, j)),
                  (v(1, 0, j), v(1, 1, j), v(1, 1, i), v(1, 0, i))]
    for i in (0, segments):
        faces.append((v(0, 0, i), v(1, 0, i), v(1, 1, i), v(0, 1, i)))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


# Shell bands (Blender z): underbody 0..0.10, skirt 0.10..1.10, upper 1.10..2.20, roof 2.20..2.30.
# Pieces abut instead of overlapping, so no coplanar surfaces can flicker.
box("Underbody", -3.875, 3.875, 0.00, 0.10, -0.95, 0.95, 0.03)
box("Roof", -4.00, 4.00, 2.20, 2.30, -1.25, 1.25, 0.04)

for side, prefix in ((-1, "Left"), (1, "Right")):
    flank(prefix + "LowerRearCorner", side, -3.82, -3.45, 0.10, 1.10)
    flank(prefix + "LowerCenter", side, -2.05, 2.05, 0.10, 1.10)
    flank(prefix + "LowerFrontCorner", side, 3.45, 3.82, 0.10, 1.10)
    arch(prefix + "WheelArchRear", side, -2.75)
    arch(prefix + "WheelArchFront", side, 2.75)

# Mostly blind left flank; the cab keeps one small high window (y 2.36..3.52, z 1.24..2.04).
flank("LeftCargoBlindPanel", -1, -3.82, 2.21, 1.10, 2.20)
flank("LeftCabLowerPanel", -1, 2.21, 3.82, 1.10, 1.24)
flank("LeftCabWindowHeader", -1, 2.21, 3.82, 2.04, 2.20)
flank("LeftCabWindowRearPillar", -1, 2.21, 2.36, 1.24, 2.04, 0.01)
flank("LeftCabWindowFrontPillar", -1, 3.52, 3.82, 1.24, 2.04)

# Right flank: boarding opening y 2.30..3.20 (Godot z -3.2..-2.3) above the front arch.
flank("RightCargoBlindPanel", 1, -3.82, 2.30, 1.10, 2.20)
flank("RightBoardingHeader", 1, 2.30, 3.20, 2.04, 2.20)
flank("RightCabLowerPanel", 1, 3.20, 3.82, 1.10, 1.24)
flank("RightCabWindowHeader", 1, 3.20, 3.82, 2.04, 2.20)
flank("RightCabWindowRearPillar", 1, 3.20, 3.28, 1.24, 2.04, 0.01)
flank("RightCabWindowFrontPillar", 1, 3.62, 3.82, 1.24, 2.04)

# Cab-over face around an empty windshield (y 3.82..4.00, opening z 1.00..2.04, |x|<0.93).
box("FrontLowerFace", 3.82, 4.00, 0.10, 1.00, -1.25, 1.25, 0.04)
box("WindshieldLeftPillar", 3.82, 4.00, 1.00, 2.04, -1.25, -0.93, 0.03)
box("WindshieldRightPillar", 3.82, 4.00, 1.00, 2.04, 0.93, 1.25, 0.03)
box("WindshieldHeader", 3.82, 4.00, 2.04, 2.20, -1.25, 1.25, 0.03)

# Rear frame: central opening |x|<0.71, z 0.10..2.20 (>=1.4 x 1.9) at Godot z=3.9.
box("RearLeftPanel", -4.00, -3.82, 0.10, 2.20, -1.25, -0.71, 0.03)
box("RearRightPanel", -4.00, -3.82, 0.10, 2.20, 0.71, 1.25, 0.03)

# Proud trim: red belt below the windows, small high cargo windows as glass panels.
box("RedStripeLeft", -3.82, 3.82, 1.06, 1.18, -1.26, -1.242, 0.004)
box("RedStripeRightRear", -3.82, 2.30, 1.06, 1.18, 1.242, 1.26, 0.004)
box("RedStripeRightFront", 3.20, 3.82, 1.06, 1.18, 1.242, 1.26, 0.004)
for side, prefix in ((-1, "Left"), (1, "Right")):
    for index, y in enumerate((-2.2, -0.6)):
        x0, x1 = (1.244, 1.264) if side > 0 else (-1.264, -1.244)
        box("%sHighWindow%d" % (prefix, index), y - 0.35, y + 0.35, 1.78, 2.00, x0, x1, 0.004)

bpy.ops.object.select_all(action="DESELECT")
for obj in sorted((o for o in bpy.context.scene.objects if o.type == "MESH"), key=lambda o: o.name):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    u0, v0, u1, v1 = REGIONS[category(obj.name)]
    for uv in obj.data.uv_layers.active.data:
        uv.uv = (u0 + uv.uv.x * (u1 - u0), v0 + uv.uv.y * (v1 - v0))
    obj.select_set(False)

bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True,
                          export_apply=True, export_image_format="NONE",
                          export_texcoords=True, export_normals=True,
                          export_tangents=False, export_animations=False,
                          export_cameras=False, export_lights=False)
print("VAN_OK objects=%d output=%s" % (len(bpy.context.scene.objects), out))
