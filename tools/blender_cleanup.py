"""Limpieza Blender del maestro §10.1 para una malla generada: de .glb denso a asset.

    blender -b --python tools/blender_cleanup.py -- <in.glb> <out.glb> \
        --size 0.4 --tris 800 --texture 1024 [--pivot base|center]

Hace, en orden: une todas las mallas en una; escala para que el lado mayor mida
`--size` metros; coloca el pivote en la base (y=0) o en el centro; decima a
`--tris` triángulos preservando la silueta; recalcula normales hacia fuera;
elimina caras sueltas y vértices duplicados; reduce cada textura a `--texture`
píxeles como máximo; exporta glTF binario con +Y arriba y −Z adelante.

No toca colisión: la colisión se autora aparte (§10.1 punto 3). Verificar la
salida con tools/glb_check.py.
"""
import argparse
import math
import sys

import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("--size", type=float, required=True, help="lado mayor en metros")
ap.add_argument("--tris", type=int, required=True)
ap.add_argument("--texture", type=int, default=1024)
ap.add_argument("--pivot", choices=("base", "center"), default="base")
a = ap.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.src)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
if not meshes:
    raise SystemExit("el glb no tiene mallas")
for o in bpy.context.scene.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
# aplanar la jerarquía: transform aplicado, sin padres
obj.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o is not obj:
        bpy.data.objects.remove(o, do_unlink=True)

# --- escala real y pivote (Blender es Z-up; el exportador convierte a Y-up) ---
bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
longest = max(mx - mn)
factor = a.size / longest
obj.scale = (factor, factor, factor)
bpy.ops.object.transform_apply(scale=True)
bb = [Vector(c) for c in obj.bound_box]
mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
center = (mn + mx) / 2
shift = Vector((-center.x, -center.y, -mn.z if a.pivot == "base" else -center.z))
for v in obj.data.vertices:
    v.co += shift
obj.location = (0, 0, 0)

# --- topología: soldar, quitar sueltos, decimar, normales hacia fuera ---
bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
# caras sin arista compartida
loose = [f for f in bm.faces if all(len(e.link_faces) == 1 for e in f.edges)]
bmesh.ops.delete(bm, geom=loose, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
bm.to_mesh(obj.data)
bm.free()

faces_before = len(obj.data.polygons)
if faces_before > a.tris:
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = a.tris / faces_before
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # el colapso puede dejar la cuenta un poco arriba: segunda pasada fina
    if len(obj.data.polygons) > a.tris:
        mod = obj.modifiers.new("decimate2", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = a.tris / len(obj.data.polygons) * 0.98
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)

bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
bm.to_mesh(obj.data)
bm.free()
obj.data.shade_flat()

# --- texturas: una cota superior de tamaño ---
seen = set()
for slot in obj.material_slots:
    m = slot.material
    if not m or not m.node_tree:
        continue
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image and n.image.name not in seen:
            seen.add(n.image.name)
            w, h = n.image.size
            if max(w, h) > a.texture:
                s = a.texture / max(w, h)
                n.image.scale(max(1, int(w * s)), max(1, int(h * s)))
# nombres estables de imagen para que el glb no dependa del recorrido interno
for i, name in enumerate(sorted(seen)):
    bpy.data.images[name].name = "tex_%d" % i

bpy.ops.export_scene.gltf(filepath=a.dst, export_format="GLB", export_yup=True,
                          export_apply=True, export_image_format="AUTO",
                          export_normals=True, export_tangents=False)

bb = [Vector(c) for c in obj.bound_box]
size = Vector((max(v.x for v in bb) - min(v.x for v in bb),
               max(v.y for v in bb) - min(v.y for v in bb),
               max(v.z for v in bb) - min(v.z for v in bb)))
print("CLEANUP_OK faces=%d (antes %d) size_xyz=%.3f,%.3f,%.3f textures=%d"
      % (len(obj.data.polygons), faces_before, size.x, size.y, size.z, len(seen)))
