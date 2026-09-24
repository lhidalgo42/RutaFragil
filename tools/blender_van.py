"""Generate the clean stylized cab-over delivery van exterior with Blender 5.1.

    blender --background --factory-startup --python tools/blender_van.py -- <output.glb>

Blender frame: +Y front, +Z up, base at z=0. glTF/Godot: -Z front, +Y up.
The wrapper places this base at bus y=-0.8, so the roof top (2.39) lands at 1.59.
"""
import math
from pathlib import Path
import sys

import bmesh
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


def finish(obj, name):
    obj.name = name
    obj.data.materials.append(material)
    return obj


def box(name, y0, y1, z0, z1, x0, x1, bevel=0.018, rotation_z=0.0):
    dimensions = (x1 - x0, y1 - y0, z1 - z0)
    bpy.ops.mesh.primitive_cube_add(size=1.0,
                                   location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
                                   rotation=(0.0, 0.0, rotation_z))
    obj = finish(bpy.context.object, name)
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("edge_softening", "BEVEL")
        modifier.width = min(bevel, min(dimensions) * 0.2)
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def mesh_object(name, vertices, faces):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices, [], faces)
    obj = finish(bpy.data.objects.new(name, mesh), name)
    bpy.context.collection.objects.link(obj)
    return obj


def flank(name, side, y0, y1, z0, z1, bevel=0.018):
    xs = (1.175, 1.25) if side > 0 else (-1.25, -1.175)
    return box(name, y0, y1, z0, z1, *xs, bevel=bevel)


def side_prism(name, side, polygon, depth=0.025, proud=0.0):
    """Thin Y/Z polygon extruded across the side shell; used for trapezoid cab glazing."""
    outer = (1.25 + proud) * side
    inner = outer - depth * side
    count = len(polygon)
    vertices = [(x, y, z) for x in (inner, outer) for y, z in polygon]
    faces = [tuple(range(count)), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    return mesh_object(name, vertices, faces)


def loft(name, sections):
    """Closed longitudinal prism from equally sized X/Z sections."""
    count = len(sections[0][1])
    vertices = [(x, y, z) for y, shape in sections for x, z in shape]
    faces = []
    for section in range(len(sections) - 1):
        for index in range(count):
            nxt = (index + 1) % count
            faces.append((section * count + index, (section + 1) * count + index,
                          (section + 1) * count + nxt, section * count + nxt))
    faces.extend((0, index + 1, index) for index in range(1, count - 1))
    end = (len(sections) - 1) * count
    faces.extend((end, end + index, end + index + 1) for index in range(1, count - 1))
    return mesh_object(name, vertices, faces)


def arch_band(name, side, longitudinal, inner, outer, depth, proud=0.0, segments=16):
    """Thin concentric half-ring lip/liner; the wheel cavity itself stays empty."""
    center_z = 0.40
    x_outer = (1.25 + proud) * side
    x_inner = x_outer - depth * side
    vertices = []
    for x in (x_inner, x_outer):
        for radius in (inner, outer):
            for index in range(segments + 1):
                angle = math.pi * index / segments
                vertices.append((x, longitudinal + radius * math.cos(angle),
                                 center_z + radius * math.sin(angle)))

    def vertex(face, ring, index):
        return face * 2 * (segments + 1) + ring * (segments + 1) + index

    faces = []
    for index in range(segments):
        nxt = index + 1
        faces.extend(((vertex(0, 1, index), vertex(1, 1, index),
                       vertex(1, 1, nxt), vertex(0, 1, nxt)),
                      (vertex(1, 0, index), vertex(0, 0, index),
                       vertex(0, 0, nxt), vertex(1, 0, nxt)),
                      (vertex(0, 0, index), vertex(0, 1, index),
                       vertex(0, 1, nxt), vertex(0, 0, nxt)),
                      (vertex(1, 1, index), vertex(1, 0, index),
                       vertex(1, 0, nxt), vertex(1, 1, nxt))))
    for index in (0, segments):
        faces.append((vertex(0, 0, index), vertex(1, 0, index),
                      vertex(1, 1, index), vertex(0, 1, index)))
    return mesh_object(name, vertices, faces)


def arch_skirt(name, side, longitudinal, inner, half=0.70, segments=16):
    """Body-colour skirt with a semicircular cutout, closing the corners around a lip."""
    center_z = 0.40
    vertices = []
    for x in ((1.175, 1.25) if side > 0 else (-1.25, -1.175)):
        for ring in (0, 1):
            for index in range(segments + 1):
                angle = math.pi * index / segments
                c, s = math.cos(angle), math.sin(angle)
                radius = inner if ring == 0 else min(half / max(abs(c), 1e-9), half / max(s, 1e-9))
                vertices.append((x, longitudinal + radius * c, center_z + radius * s))

    def vertex(face, ring, index):
        return face * 2 * (segments + 1) + ring * (segments + 1) + index

    faces = []
    for index in range(segments):
        nxt = index + 1
        faces.extend(((vertex(0, 1, index), vertex(1, 1, index), vertex(1, 1, nxt), vertex(0, 1, nxt)),
                      (vertex(0, 0, nxt), vertex(1, 0, nxt), vertex(1, 0, index), vertex(0, 0, index)),
                      (vertex(0, 0, index), vertex(0, 1, index), vertex(0, 1, nxt), vertex(0, 0, nxt)),
                      (vertex(1, 0, nxt), vertex(1, 1, nxt), vertex(1, 1, index), vertex(1, 0, index))))
    for index in (0, segments):
        faces.append((vertex(0, 0, index), vertex(1, 0, index), vertex(1, 1, index), vertex(0, 1, index)))
    return mesh_object(name, vertices, faces)


def hinged_box(name, hinge_x, hinge_y, width, z0, z1, angle, depth=0.065, offset=0.0):
    """Rear door detail extending away from a hinge; rotation is baked before export."""
    direction = -1.0 if hinge_x < 0 else 1.0
    local_center = direction * (offset + width / 2)
    center_x = hinge_x + math.cos(angle) * local_center
    center_y = hinge_y + math.sin(angle) * local_center
    return box(name, center_y - depth / 2, center_y + depth / 2, z0, z1,
               center_x - width / 2, center_x + width / 2, 0.008, angle)


def front_strip(name, lower_outer, lower_inner, upper_outer, upper_inner):
    """A-pillar with a raked outer face and a vertical back at y=3.80.

    The wrapper's flat windshield (Godot z=-3.85) sits inside this depth at
    every height, so the glass is seated in its frame rather than floating.
    """
    front = [(lower_outer, 4.10, 1.00), (lower_inner, 4.10, 1.00),
             (upper_inner, 3.88, 2.06), (upper_outer, 3.88, 2.06)]
    vertices = front + [(x, 3.80, z) for x, _y, z in front]
    return mesh_object(name, vertices, [(0, 1, 2, 3), (7, 6, 5, 4),
                                        (0, 4, 5, 1), (1, 5, 6, 2),
                                        (2, 6, 7, 3), (3, 7, 4, 0)])


# Underbody and side shell. Wheel cavities stay open for the 0.5 m wheels.
box("Underbody", -3.88, 3.82, 0.00, 0.10, -0.96, 0.96, 0.025)
for side, prefix in ((-1, "Left"), (1, "Right")):
    flank(prefix + "LowerRearCorner", side, -3.82, -3.45, 0.10, 1.10)
    flank(prefix + "LowerCenter", side, -2.05, 2.05, 0.10, 1.10)
    flank(prefix + "LowerFrontCorner", side, 3.45, 3.82, 0.10, 1.10)
    for axle, longitudinal in (("Rear", -2.75), ("Front", 2.75)):
        arch_skirt(prefix + "ArchSkirt" + axle, side, longitudinal, 0.65)
        arch_band(prefix + "WheelArchLip" + axle, side, longitudinal, 0.585, 0.65, 0.045, 0.012)
        arch_band(prefix + "WheelLiner" + axle, side, longitudinal, 0.55, 0.58, 0.105)

# Mostly blind cargo sides, preserving the pinned cab and boarding openings.
flank("LeftCargoBlindPanel", -1, -3.82, 2.21, 1.10, 2.05)
flank("LeftCabLowerPanel", -1, 2.21, 3.82, 1.10, 1.24)
side_prism("LeftCabSideGlass", -1, ((2.34, 1.28), (3.76, 1.28), (3.60, 2.03), (2.34, 2.03)), 0.022, 0.006)
flank("LeftCabRearPillar", -1, 2.21, 2.34, 1.24, 2.06, 0.010)
flank("LeftCabAPillar", -1, 3.60, 3.82, 1.24, 2.06, 0.010)

flank("RightCargoBlindPanel", 1, -3.82, 2.27, 1.10, 2.05)
flank("RightDoorHeader", 1, 2.27, 3.21, 2.05, 2.10, 0.008)
flank("RightDoorRearJamb", 1, 2.25, 2.30, 1.10, 2.05, 0.006)
flank("RightDoorFrontJamb", 1, 3.20, 3.25, 1.10, 2.05, 0.006)
box("RightDoorThreshold", 2.28, 3.20, 1.04, 1.10, 1.176, 1.25, 0.006)
box("RightDoorRearJambTrim", 2.245, 2.285, 1.10, 2.04, 1.282, 1.312, 0.004)
box("RightDoorFrontJambTrim", 3.215, 3.255, 1.10, 2.04, 1.282, 1.312, 0.004)
box("RightDoorHeaderTrim", 2.27, 3.23, 2.045, 2.085, 1.282, 1.312, 0.004)
flank("RightCabLowerPanel", 1, 3.20, 3.82, 1.10, 1.24)
side_prism("RightCabSideGlass", 1, ((3.29, 1.28), (3.76, 1.28), (3.60, 2.03), (3.29, 2.03)), 0.022, 0.006)
flank("RightCabAPillar", 1, 3.60, 3.82, 1.24, 2.06, 0.010)

# One continuous cream crown: no separate cab roof lid or visible seam.
cargo_roof = ((-1.25, 2.04), (-1.20, 2.20), (-0.88, 2.34), (0.0, 2.39),
              (0.88, 2.34), (1.20, 2.20), (1.25, 2.04), (1.08, 2.20), (-1.08, 2.20))
cab_roof = ((-1.19, 2.04), (-1.13, 2.18), (-0.82, 2.30), (0.0, 2.35),
            (0.82, 2.30), (1.13, 2.18), (1.19, 2.04), (1.03, 2.20), (-1.03, 2.20))
loft("RoofCrown", [(-4.01, cargo_roof), (3.35, cargo_roof), (3.70, cab_roof), (4.08, cab_roof)])
box("CabBrow", 3.69, 3.82, 2.02, 2.16, -1.16, 1.16, 0.035)

# Canonical cab-over face: raked windshield above a stepped, rounded lower nose.
front_strip("WindshieldPillarLeft", -1.24, -0.94, -1.18, -0.95)
front_strip("WindshieldPillarRight", 1.24, 0.94, 1.18, 0.95)
# Dark gasket ring in the wrapper glass plane (1.84 x 1.02 at y=3.85), overlapping the pillars.
box("WindshieldGasketLeft", 3.825, 3.875, 1.00, 2.05, -0.965, -0.905, 0.006)
box("WindshieldGasketRight", 3.825, 3.875, 1.00, 2.05, 0.905, 0.965, 0.006)
box("WindshieldGasketLower", 3.82, 3.90, 0.98, 1.055, -0.965, 0.965, 0.008)
box("WindshieldGasketUpper", 3.80, 3.90, 2.035, 2.095, -0.965, 0.965, 0.008)
box("WindshieldInnerLowerTrim", 3.76, 3.82, 1.00, 1.045, -0.93, 0.93, 0.006)
box("WindshieldInnerUpperTrim", 3.74, 3.80, 2.035, 2.075, -0.95, 0.95, 0.006)
loft("FrontRoundedNose", [(3.76, ((-1.25, 0.10), (-1.25, 1.00), (1.25, 1.00), (1.25, 0.10))),
                          (4.03, ((-1.23, 0.12), (-1.23, 0.94), (1.23, 0.94), (1.23, 0.12))),
                          (4.13, ((-1.15, 0.20), (-1.15, 0.82), (1.15, 0.82), (1.15, 0.20)))])
box("FrontDarkFascia", 4.115, 4.155, 0.45, 0.83, -1.08, 1.08, 0.025)
box("FasciaGrille", 4.151, 4.177, 0.50, 0.74, -0.46, 0.46, 0.008)
for side, prefix in ((-1, "Left"), (1, "Right")):
    x0, x1 = ((-1.00, -0.55) if side < 0 else (0.55, 1.00))
    box("HeadlightBezel" + prefix, 4.148, 4.181, 0.57, 0.82, x0, x1, 0.025)
    box("Headlight" + prefix, 4.178, 4.194, 0.62, 0.77, x0 + 0.06, x1 - 0.06, 0.0)
box("FrontBumper", 4.12, 4.24, 0.20, 0.36, -1.18, 1.18, 0.04)

# Mirrors on compact dark arms, outside the cab window openings.
for side, prefix in ((-1, "Left"), (1, "Right")):
    x0, x1 = ((-1.50, -1.28) if side < 0 else (1.28, 1.50))
    box(prefix + "MirrorArm", 3.43, 3.49, 1.47, 1.53, x0, x1, 0.012)
    mx0, mx1 = ((-1.57, -1.45) if side < 0 else (1.45, 1.57))
    box(prefix + "MirrorPod", 3.34, 3.51, 1.39, 1.73, mx0, mx1, 0.035)
    face_x0, face_x1 = ((-1.582, -1.574) if side < 0 else (1.574, 1.582))
    box(prefix + "MirrorGlass", 3.37, 3.48, 1.43, 1.69, face_x0, face_x1, 0.003)

# Parked sliding panel reads as a panel, never as a second walkable opening.
box("SlidingDoorParked", 1.22, 2.24, 0.45, 2.03, 1.285, 1.355, 0.026)
box("SlidingDoorInset", 1.34, 2.12, 1.37, 1.90, 1.356, 1.370, 0.010)
box("SlidingDoorRail", 1.06, 3.28, 1.99, 2.045, 1.272, 1.302, 0.006)
box("SlidingDoorHandle", 1.94, 2.13, 1.27, 1.33, 1.358, 1.390, 0.008)

# Finished rear around the pinned 1.40 m clear aperture; leaves remain visibly open.
box("RearLeftPanel", -4.00, -3.82, 0.10, 2.05, -1.25, -0.71, 0.025)
box("RearRightPanel", -4.00, -3.82, 0.10, 2.05, 0.71, 1.25, 0.025)
box("RearApertureGasketLeft", -4.035, -3.985, 0.15, 2.19, -0.75, -0.70, 0.005)
box("RearApertureGasketRight", -4.035, -3.985, 0.15, 2.19, 0.70, 0.75, 0.005)
box("RearHeaderTrim", -4.035, -3.985, 2.19, 2.25, -0.75, 0.75, 0.006)
box("RearSillTrim", -4.035, -3.985, 0.10, 0.135, -0.75, 0.75, 0.005)
rear_angle = math.radians(48)
for side, prefix in ((-1, "Left"), (1, "Right")):
    angle = rear_angle if side < 0 else -rear_angle
    hinge_x = 0.72 * side
    hinged_box("RearDoor" + prefix + "Open", hinge_x, -3.92, 0.68, 0.18, 2.04, angle)
    hinged_box("RearDoor" + prefix + "InsetUpper", hinge_x, -3.958, 0.48, 1.28, 1.86, angle, 0.018, 0.10)
    hinged_box("RearDoor" + prefix + "InsetLower", hinge_x, -3.958, 0.48, 0.38, 0.91, angle, 0.018, 0.10)
    for z in (0.45, 1.72):
        x0 = hinge_x - 0.045 if side < 0 else hinge_x - 0.005
        box("RearDoor%sHinge%d" % (prefix, int(z * 100)), -3.99, -3.84,
            z - 0.08, z + 0.08, x0, x0 + 0.05, 0.006)
hinged_box("RearDoorLeftLatch", -0.72, -3.975, 0.12, 0.98, 1.15, rear_angle, 0.025, 0.42)
hinged_box("RearDoorRightLatch", 0.72, -3.975, 0.12, 0.98, 1.15, -rear_angle, 0.025, 0.42)
for x, suffix in ((-0.98, "Left"), (0.98, "Right")):
    box("RearLight" + suffix, -4.075, -4.025, 0.34, 0.78, x - 0.13, x + 0.13, 0.018)
for index, x in enumerate((-0.34, 0.0, 0.34)):
    box("RearUpperMarker%d" % index, -4.055, -4.015, 2.21, 2.29, x - 0.07, x + 0.07, 0.012)
box("RearLowerFascia", -4.16, -4.02, 0.08, 0.26, -1.18, 1.18, 0.035)
box("RearStepBumper", -4.24, -4.08, 0.02, 0.14, -1.12, 1.12, 0.035)
box("RearPlateRecess", -4.245, -4.205, 0.16, 0.37, -0.34, 0.34, 0.025)

# Half-height red datum aligned across fixed shell, parked panel and rear leaves.
stripe_z0, stripe_z1 = 1.04, 1.17
box("RedStripeLeft", -3.82, 3.82, stripe_z0, stripe_z1, -1.272, -1.246, 0.004)
box("RedStripeRightRear", -3.82, 2.30, stripe_z0, stripe_z1, 1.246, 1.272, 0.004)
box("RedStripeRightFront", 3.20, 3.82, stripe_z0, stripe_z1, 1.246, 1.272, 0.004)
box("RedStripeSlidingDoor", 1.22, 2.24, stripe_z0, stripe_z1, 1.356, 1.380, 0.004)
for side, prefix in ((-1, "Left"), (1, "Right")):
    hinged_box("RedStripeRearDoor" + prefix, 0.72 * side, -3.962,
               0.68, stripe_z0, stripe_z1, rear_angle if side < 0 else -rear_angle, 0.018)


# Bake transforms, normalize winding, then map every mesh into its atlas region.
bpy.ops.object.select_all(action="DESELECT")
for obj in sorted((item for item in bpy.context.scene.objects if item.type == "MESH"), key=lambda item: item.name):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    normal_mesh = bmesh.new()
    normal_mesh.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(normal_mesh, faces=normal_mesh.faces[:])
    normal_mesh.to_mesh(obj.data)
    normal_mesh.free()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
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
