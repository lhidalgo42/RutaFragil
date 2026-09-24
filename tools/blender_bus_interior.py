"""Generate the clean bus interior GLB with Blender 5.1.

    blender --background --factory-startup --python tools/blender_bus_interior.py -- <output.glb>
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
    raise SystemExit("usage: blender_bus_interior.py -- <output.glb>")
out = Path(argv[0]).resolve()
out.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
material = bpy.data.materials.new("placeholder_interior")
material.use_nodes = True
material.diffuse_color = (0.62, 0.57, 0.42, 1.0)
material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = material.diffuse_color


def finish(obj):
    obj.data.materials.append(material)
    return obj


def box(name, location, dimensions, bevel=0.015, rotation=(0.0, 0.0, 0.0), segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("edge_softening", "BEVEL")
        modifier.width = min(bevel, min(dimensions) * 0.2)
        modifier.segments = segments
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj)


def cylinder(name, location, radius, depth, rotation=(0.0, 0.0, 0.0), vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return finish(obj)


def torus(name, location, major_radius, minor_radius, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=6,
                                    major_radius=major_radius, minor_radius=minor_radius,
                                    location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    return finish(obj)


def mesh_object(name, vertices, faces):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    return finish(obj)


def join_objects(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    bpy.context.object.name = name
    return bpy.context.object


RECLINE = math.radians(9)
BACK_BASE_Z = 0.62


def back_center_y(y, height):
    """Seat-back mid-plane; Blender -Y is rear, so higher points move rearward."""
    return y - 0.19 - math.tan(RECLINE) * (height - BACK_BASE_Z)


def prism(name, ring, axis_offsets, place):
    """Closed prism: `ring` is one convex-or-concave loop, `place(u, v, offset)` maps it."""
    vertices = [place(u, v, offset) for offset in axis_offsets for u, v in ring]
    count = len(ring)
    faces = [tuple(range(count)), tuple(range(count, count * 2))[::-1]]
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))
    return mesh_object(name, vertices, faces)


def tapered_seat_back(name, x, y):
    """Back sinks into the cushion, flares at the shoulders and narrows to the headrest."""
    profile = ((BACK_BASE_Z, 0.42), (1.02, 0.52), (1.20, 0.52), (1.41, 0.32))
    ring = [(-width / 2, height) for height, width in profile] + \
           [(width / 2, height) for height, width in reversed(profile)]
    return prism(name, ring, (-0.09, 0.09),
                 lambda side, height, offset: (x + side, back_center_y(y, height) + offset, height))


def bolstered_cushion(name, x, y):
    """U cross-section: raised side bolsters, 4 cm above the sitting well."""
    ring = ((-0.25, 0.51), (0.25, 0.51), (0.25, 0.675), (0.20, 0.685),
            (0.16, 0.645), (-0.16, 0.645), (-0.20, 0.685), (-0.25, 0.675))
    return prism(name, ring, (-0.27, 0.27),
                 lambda side, height, offset: (x + side, y + offset, height))


def wheel_well(name, x, y):
    """Closed half-cylinder, with its flat side resting above the floor."""
    radius = 0.52
    base = 0.055
    profile = [(radius * math.cos(angle), base + radius * math.sin(angle))
               for angle in (math.pi * index / 10 for index in range(10, -1, -1))]
    x0, x1 = x - 0.055, x + 0.055
    vertices = [(side, y + along, height) for side in (x0, x1) for along, height in profile]
    count = len(profile)
    faces = [tuple(range(count)), tuple(range(count, count * 2))[::-1]]
    for index in range(count):
        following = (index + 1) % count
        faces.append((index, following, count + following, count + index))
    return mesh_object(name, vertices, faces)


def cabinet(prefix, side):
    """Fills the visible part of the 0.55 m collider: from inside the wall liner
    (|x| 1.10) to the aisle face (|x| 0.602), keeping a >=1.20 m aisle."""
    box(prefix + "LowerCabinet", (side * 0.865, 0.0, 0.36), (0.47, 2.34, 0.58), 0.025)
    handles = []
    for y in (-0.58, 0.58):
        suffix = "Rear" if y < 0 else "Front"
        box(prefix + "LowerDoor" + suffix, (side * 0.623, y, 0.38), (0.018, 1.08, 0.48), 0.006)
        handles.append(box(prefix + "Handle" + suffix, (side * 0.609, y + 0.35, 0.40),
                           (0.014, 0.18, 0.035), 0.005))
    join_objects(handles, prefix + "Handles")
    for z in (0.72, 1.08, 1.42):
        box(prefix + "UpperShelf_%d" % round(z * 100), (side * 0.851, 0.0, z),
            (0.498, 2.34, 0.055), 0.008)
    for y in (-1.145, 1.145):
        box(prefix + "UpperEnd" + ("Rear" if y < 0 else "Front"), (side * 0.851, y, 1.07),
            (0.498, 0.05, 0.72), 0.008)


def seat(prefix, x, y):
    """One joined, low-poly automotive bucket with all required readable components."""
    tilt = (RECLINE, 0.0, 0.0)
    outboard = -1.0 if x < 0 else 1.0
    parts = [
        box(prefix + "RailLeft", (x - 0.16, y, 0.055), (0.05, 0.42, 0.04), 0.0),
        box(prefix + "RailRight", (x + 0.16, y, 0.055), (0.05, 0.42, 0.04), 0.0),
        box(prefix + "Pedestal", (x, y, 0.285), (0.28, 0.32, 0.46), 0.015, segments=1),
        bolstered_cushion(prefix + "Cushion", x, y),
        tapered_seat_back(prefix + "Back", x, y),
        box(prefix + "PostLeft", (x - 0.105, back_center_y(y, 1.47), 1.47),
            (0.035, 0.035, 0.18), 0.0, tilt),
        box(prefix + "PostRight", (x + 0.105, back_center_y(y, 1.47), 1.47),
            (0.035, 0.035, 0.18), 0.0, tilt),
        box(prefix + "Headrest", (x, back_center_y(y, 1.60), 1.60),
            (0.30, 0.16, 0.22), 0.03, tilt, segments=1),
        # Top end of the diagonal strap sits on the outboard shoulder, bottom at the inboard hip.
        box(prefix + "Seatbelt", (x, back_center_y(y, 1.00) + 0.11, 1.00),
            (0.05, 0.02, 0.72), 0.0, (RECLINE, math.radians(35) * outboard, 0.0)),
        box(prefix + "Buckle", (x - outboard * 0.27, y - 0.05, 0.66),
            (0.04, 0.06, 0.10), 0.0),
    ]
    for bolster_side, suffix in ((-1.0, "Left"), (1.0, "Right")):
        parts.append(box(prefix + "Bolster" + suffix,
                         (x + bolster_side * 0.225, y - 0.22, 0.93),
                         (0.08, 0.26, 0.56), 0.02, tilt, segments=1))
    # Stable imported name retained for Godot's visual smoke test; every component is in this mesh.
    return join_objects(parts, prefix + "Cushion")


# Liners preserve the authored side opening at bus z[-2.20,-1.30] and rear portal.
# The full authored bbox is still centered; wrapper (0, .38, .005) is unchanged.
box("FloorLiner", (0.0, -0.005, 0.025), (2.10, 7.98, 0.05), 0.01)
box("RoofLiner", (0.0, 0.0, 1.95), (2.10, 7.95, 0.08), 0.025)

def windowed_liner(name, x, y0, y1, bevel):
    """Cab wall liner with the side window cut out (bus y 0.50..1.18, z -3.54..-2.40).

    Sill and header are 5 mm thinner than the posts: their butt faces never share
    vertices or visible coplanar faces with the posts (no weld errors, no flicker).
    """
    win_y0, win_y1, sill_top, header_bottom = 2.40, 3.54, 1.15, 1.83
    parts = [box(name + "Rear", (x, (y0 + win_y0) / 2, 1.00), (0.08, win_y0 - y0, 1.90), bevel),
             box(name + "Front", (x, (win_y1 + y1) / 2, 1.00), (0.08, y1 - win_y1, 1.90), bevel)]
    for suffix, z0, z1 in (("Sill", 0.05, sill_top), ("Header", header_bottom, 1.95)):
        parts.append(box(name + suffix, (x, (win_y0 + win_y1) / 2, (z0 + z1) / 2),
                         (0.07, win_y1 - win_y0, z1 - z0), bevel))
    return join_objects(parts, name)


windowed_liner("LeftWallLiner", -1.07, -3.975, 3.975, 0.012)
# Bus z = -Blender y. Jamb faces sit 0.5 mm outside the gap to absorb float noise.
box("RightCargoWallLiner", (1.07, -1.33775, 1.00), (0.08, 5.2745, 1.90), 0.0)
windowed_liner("RightCabWallLiner", 1.07, 2.2005, 3.975, 0.0)
box("RightBoardingHeader", (1.07, 1.75, 1.99), (0.08, 0.90, 0.14), 0.015)
box("BoardingThreshold", (1.03, 1.75, 0.055), (0.14, 0.90, 0.008), 0.003)
box("RearLeftLiner", (-0.91, -3.85, 0.93), (0.32, 0.24, 1.78), 0.015)
box("RearRightLiner", (0.91, -3.85, 0.93), (0.32, 0.24, 1.78), 0.015)
box("RearOpeningHeader", (0.0, -3.85, 1.91), (1.50, 0.24, 0.16), 0.015)
box("RearDoorSill", (0.0, -3.95, 0.09), (1.44, 0.07, 0.18), 0.012)

# Raised aisle ribs and thresholds avoid coplanar overlap with the floor liner.
for x in (-0.42, 0.0, 0.42):
    box("FloorRib_%s" % str(x).replace("-", "N").replace(".", "_"),
        (x, -0.15, 0.066), (0.035, 6.70, 0.022), 0.006)
for index, y in enumerate((-1.28, 1.28)):
    box("FloorThreshold%d" % index, (0.0, y, 0.074), (1.18, 0.07, 0.038), 0.008)

for name, x, y in (("WheelWellDarkFL", -0.99, 2.75),
                   ("WheelWellDarkFR", 0.885, 2.75),
                   ("WheelWellDarkRR", 0.99, -2.75)):
    wheel_well(name, x, y)
    aisle_x = -0.925 if x < 0.0 else 0.805
    box(name + "Fascia", (aisle_x, y, 0.31), (0.025, 1.02, 0.51), 0.0)

cabinet("LeftRack", -1.0)
cabinet("RightRack", 1.0)

# Five visual-only parcels remain inside the rack collision volumes.
box("LeftParcelRear", (-0.875, -0.72, 0.88), (0.42, 0.42, 0.27), 0.025,
    rotation=(0.0, 0.0, math.radians(3)))
box("LeftParcelFront", (-0.875, 0.55, 0.88), (0.38, 0.52, 0.27), 0.025,
    rotation=(0.0, 0.0, math.radians(-4)))
box("RightParcelRear", (0.875, -0.63, 0.88), (0.40, 0.48, 0.27), 0.025)
box("RightParcelMiddle", (0.875, 0.06, 0.89), (0.44, 0.40, 0.29), 0.025,
    rotation=(0.0, 0.0, math.radians(5)))
box("RightParcelFront", (0.875, 0.72, 0.87), (0.36, 0.38, 0.25), 0.025)

# Rear fixtures stay inside their unchanged colliders.
box("BenchBase", (-0.875, -2.9, 0.275), (0.46, 1.16, 0.43), 0.02)
box("BenchCushion", (-0.875, -2.9, 0.57), (0.46, 1.16, 0.16), 0.045)
box("BenchBack", (-1.03, -2.9, 0.80), (0.10, 1.16, 0.30), 0.035)
box("StretcherDeck", (0.68, -2.2, 0.26), (0.32, 1.76, 0.08), 0.025)
join_objects([box("StretcherLeg_%s" % ("Rear" if y < -2.2 else "Front"),
                  (0.68, y, 0.14), (0.22, 0.08, 0.16), 0.012)
              for y in (-2.95, -1.45)], "StretcherLegs")

# Seat cushion centers land exactly on bus markers after centering and wrapper transform.
seat("DriverSeat", -0.60, 2.90)
seat("CopilotSeat", 0.60, 2.90)
box("Dashboard", (0.0, 3.48, 0.98), (1.55, 0.30, 0.30), 0.055)
box("DashboardConsole", (0.0, 3.31, 0.72), (0.34, 0.38, 0.42), 0.045)
torus("SteeringWheel", (-0.60, 3.23, 1.02), 0.19, 0.025,
      rotation=(math.radians(90), 0.0, 0.0))
cylinder("SteeringColumn", (-0.60, 3.38, 0.90), 0.035, 0.34,
         rotation=(math.radians(68), 0.0, 0.0))

# UV0 targets semantic quadrants in the external atlas; no image is embedded.
regions = {
    "floor": (0.02, 0.52, 0.48, 0.98),
    "rack": (0.52, 0.52, 0.98, 0.98),
    "seat": (0.02, 0.02, 0.48, 0.48),
    "wall": (0.52, 0.02, 0.98, 0.48),
}
meshes = sorted((item for item in bpy.context.scene.objects if item.type == "MESH"),
                key=lambda item: item.name)
for obj in meshes:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    if obj.name.startswith(("Floor", "BoardingStep", "BoardingThreshold")):
        region = "floor"
    elif obj.name.startswith(("LeftRack", "RightRack", "LeftParcel", "RightParcel")):
        region = "rack"
    elif obj.name.startswith(("DriverSeat", "CopilotSeat", "Bench", "Stretcher",
                              "Dashboard", "Steering", "WheelWellDark", "RearDoorSill",
                              "RearOpeningHeader")):
        region = "seat"
    else:
        region = "wall"
    u0, v0, u1, v1 = regions[region]
    for uv in obj.data.uv_layers.active.data:
        uv.uv = (u0 + uv.uv.x * (u1 - u0), v0 + uv.uv.y * (v1 - v0))
    obj.select_set(False)

# Center complete authored bbox. Wrapper transform remains unchanged.
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
print("INTERIOR_OK objects=%d corridor=1.20 output=%s" % (len(meshes), out))
