"""Generate one centered, +X-axis bus wheel GLB with Blender 5.1.

    blender --background --factory-startup --python tools/blender_bus_wheel.py -- <output.glb>
"""
import math
from pathlib import Path
import sys

import bpy
import bmesh


if bpy.app.version[:2] != (5, 1):
    raise SystemExit("Blender 5.1 required, found %s" % (bpy.app.version_string,))

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(argv) != 1 or Path(argv[0]).suffix.lower() != ".glb":
    raise SystemExit("usage: blender_bus_wheel.py -- <output.glb>")
out = Path(argv[0]).resolve()
out.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
material = bpy.data.materials.new("placeholder_wheel")
material.use_nodes = True
material.diffuse_color = (0.16, 0.16, 0.16, 1.0)
material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = material.diffuse_color

# One external atlas, three deterministic regions. Blender UV uses bottom-up V.
REGIONS = {
    "tread": (0.02, 0.02, 0.31, 0.98),
    "sidewall": (0.34, 0.02, 0.48, 0.98),
    "rim": (0.52, 0.02, 0.98, 0.98),
}
VENT_RING = 0.168
VENT_RADIUS = 0.030


def finish(obj, name, smooth=False):
    obj.name = name
    obj.data.materials.append(material)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def cylinder(name, radius, depth, vertices=16, location=(0.0, 0.0, 0.0), rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=location,
                                       rotation=rotation or (0.0, math.pi / 2, 0.0))
    return finish(bpy.context.object, name, smooth=True)


def annulus(name, inner_radius, outer_radius, depth, vertices=16, center_x=0.0):
    vertices_out = []
    for x in (center_x - depth / 2, center_x + depth / 2):
        for radius in (inner_radius, outer_radius):
            for index in range(vertices):
                angle = math.tau * index / vertices
                vertices_out.append((x, radius * math.cos(angle), radius * math.sin(angle)))

    def vertex(side, ring, index):
        return side * vertices * 2 + ring * vertices + index % vertices

    faces = []
    for index in range(vertices):
        nxt = (index + 1) % vertices
        faces.extend(((vertex(0, 1, index), vertex(0, 1, nxt), vertex(1, 1, nxt), vertex(1, 1, index)),
                      (vertex(1, 0, index), vertex(1, 0, nxt), vertex(0, 0, nxt), vertex(0, 0, index)),
                      (vertex(0, 0, index), vertex(0, 0, nxt), vertex(0, 1, nxt), vertex(0, 1, index)),
                      (vertex(1, 1, index), vertex(1, 1, nxt), vertex(1, 0, nxt), vertex(1, 0, index))))
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(vertices_out, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, smooth=True)


def box(name, location, dimensions, rotation_x=0.0, bevel=0.008):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location,
                                   rotation=(rotation_x, 0.0, 0.0))
    obj = finish(bpy.context.object, name)
    obj.dimensions = dimensions
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("edge_softening", "BEVEL")
    modifier.width = bevel
    modifier.segments = 1
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def tire():
    # Narrow 0.192 m tire. Three 7 mm circumferential grooves keep the tread restrained.
    # The outer profile reaches exactly 0.500 m; the inner profile leaves the rim opening.
    profile = ((-0.090, 0.310), (-0.096, 0.455), (-0.072, 0.490),
               (-0.050, 0.500), (-0.035, 0.493), (-0.020, 0.500),
               (0.000, 0.493), (0.020, 0.500), (0.035, 0.493),
               (0.050, 0.500), (0.072, 0.490), (0.096, 0.455),
               (0.090, 0.310))
    segments = 28
    vertices = []
    for x, radius in profile:
        for index in range(segments):
            angle = math.tau * index / segments
            vertices.append((x, radius * math.cos(angle), radius * math.sin(angle)))
    faces = []
    for profile_index in range(len(profile)):
        nxt_profile = (profile_index + 1) % len(profile)
        for index in range(segments):
            nxt = (index + 1) % segments
            faces.append((profile_index * segments + index,
                          profile_index * segments + nxt,
                          nxt_profile * segments + nxt,
                          nxt_profile * segments + index))
    mesh = bpy.data.meshes.new("TireTread_mesh")
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new("TireTread", mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, "TireTread", smooth=True)


def category(name):
    if name == "TireTread":
        return "tread"
    if name.startswith("TireSidewall"):
        return "sidewall"
    return "rim"


tire()
# Thin clean sidewall faces cover the tread texture at both visible wheel faces.
annulus("TireSidewallInner", 0.296, 0.458, 0.008, vertices=14, center_x=-0.098)
annulus("TireSidewallOuter", 0.296, 0.458, 0.008, vertices=14, center_x=0.098)

# Generic heavy-duty commercial steel wheel: recessed disc, heavy hub, lug nuts.
annulus("RimOuter", 0.238, 0.310, 0.150, vertices=14)
# Disc face sits 13 mm inside the rim lip; its overlap into RimOuter hides any seam.
disc = cylinder("RimDisc", 0.242, 0.024, 16, location=(0.050, 0.0, 0.0))
# Four small round through-holes: restrained ventilation, no sporty spokes.
cutters = []
for index in range(4):
    angle = math.tau * index / 4 + math.pi / 4
    cutters.append(cylinder("VentCutter%02d" % index, VENT_RADIUS, 0.080, 8,
                            (0.050, VENT_RING * math.cos(angle), VENT_RING * math.sin(angle))))
bpy.ops.object.select_all(action="DESELECT")
for cutter in cutters:
    cutter.select_set(True)
bpy.context.view_layer.objects.active = cutters[0]
bpy.ops.object.join()
cutter = bpy.context.object
boolean = disc.modifiers.new("vent_holes", "BOOLEAN")
boolean.operation = "DIFFERENCE"
boolean.solver = "EXACT"
boolean.object = cutter
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = disc
disc.select_set(True)
bpy.ops.object.modifier_apply(modifier=boolean.name)
bpy.data.objects.remove(cutter, do_unlink=True)
cylinder("RimHubCap", 0.100, 0.176, 16)
# Six hex lug nuts on a heavy hub, standing proud of both hub faces.
for index in range(6):
    angle = math.tau * index / 6
    radius = 0.071
    cylinder("RimLug%02d" % index, 0.014, 0.190, 6,
             (0.0, radius * math.cos(angle), radius * math.sin(angle)))
# One off-axis stem makes wheel rotation readable without lettering or trade dress.
cylinder("ValveStem", 0.009, 0.034, 8, (0.083, 0.0, 0.272))

bpy.ops.object.select_all(action="DESELECT")
for obj in sorted((item for item in bpy.context.scene.objects if item.type == "MESH"), key=lambda item: item.name):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # Flat caps and disc faces stay crisp; round surfaces stay smooth.
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    u0, v0, u1, v1 = REGIONS[category(obj.name)]
    for uv in obj.data.uv_layers.active.data:
        uv.uv = (u0 + uv.uv.x * (u1 - u0), v0 + uv.uv.y * (v1 - v0))
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(mesh, faces=mesh.faces[:])
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.select_set(False)

bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True,
                          export_apply=True, export_image_format="NONE",
                          export_texcoords=True, export_normals=True,
                          export_tangents=False, export_animations=False,
                          export_cameras=False, export_lights=False)
print("WHEEL_OK objects=%d radius=0.5 axis=+X output=%s" % (len(bpy.context.scene.objects), out))
