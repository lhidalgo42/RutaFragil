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
material.diffuse_color = (0.12, 0.12, 0.12, 1.0)
material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = material.diffuse_color


def finish(obj, name):
    obj.name = name
    obj.data.materials.append(material)
    return obj


def cylinder(name, radius, depth, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=(0.0, 0.0, 0.0),
                                       rotation=(0.0, math.pi / 2, 0.0))
    return finish(bpy.context.object, name)


def box(name, location, dimensions, rotation_x=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location,
                                   rotation=(rotation_x, 0.0, 0.0))
    obj = finish(bpy.context.object, name)
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("edge_softening", "BEVEL")
    modifier.width = 0.012
    modifier.segments = 1
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


# Generic smooth tire: 0.5 m radius, no tread lettering or branded pattern.
bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=8,
                                 major_radius=0.39, minor_radius=0.11,
                                 location=(0.0, 0.0, 0.0),
                                 rotation=(0.0, math.pi / 2, 0.0))
finish(bpy.context.object, "GenericTire")

# Utility/racing rim. All rotational geometry uses local +X as its axis.
cylinder("RimOuter", 0.31, 0.15, 24)
cylinder("RimInset", 0.235, 0.17, 24)
cylinder("RimHub", 0.095, 0.20, 20)
for index in range(8):
    angle = math.tau * index / 8
    radius = 0.16
    box("RimSpoke%02d" % index,
        (0.0, radius * math.cos(angle), radius * math.sin(angle)),
        (0.19, 0.25, 0.045), angle)

for obj in sorted((item for item in bpy.context.scene.objects if item.type == "MESH"), key=lambda item: item.name):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    u0, u1 = (0.02, 0.48) if obj.name == "GenericTire" else (0.52, 0.98)
    for uv in obj.data.uv_layers.active.data:
        uv.uv = (u0 + uv.uv.x * (u1 - u0), 0.02 + uv.uv.y * 0.96)
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
