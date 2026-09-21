"""Rojo primero para glb_check.py (M-ART paso 3).

Genera con Blender headless dos .glb en un directorio temporal:
  bad.glb   — cubo de 40 m (escala ×100), pivote centrado, ~5k tris, toda la
              malla hacia dentro, un triángulo suelto, dos materiales, textura 2048².
  good.glb  — caja de 0,4 m con la base en y=0, 12 tris, un material, sin textura.
y afirma que el validador suspende al malo en cada punto y aprueba al bueno.

    python tools/glb_check_test.py        (BLENDER=ruta opcional)
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glb_check

BLENDER = os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe")

FIXTURES = r'''
import bpy, bmesh, sys
out = sys.argv[sys.argv.index("--") + 1]

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True,
                              export_apply=True, export_image_format="AUTO")

# ---------- bad.glb ----------
reset()
bpy.ops.mesh.primitive_cube_add(size=40.0, location=(0, 0, 0))   # ×100 y pivote centrado
obj = bpy.context.active_object
bm = bmesh.new(); bm.from_mesh(obj.data)
bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=20, use_grid_fill=True)  # ~5k tris
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.faces.ensure_lookup_table()
bmesh.ops.reverse_faces(bm, faces=bm.faces[:])                     # malla entera hacia dentro
v = [bm.verts.new((100.0, 100.0, 100.0)), bm.verts.new((101.0, 100.0, 100.0)),
     bm.verts.new((100.0, 101.0, 100.0))]
bm.faces.new(v)                                                     # cara suelta
bm.to_mesh(obj.data); bm.free()
m1 = bpy.data.materials.new("A"); m1.use_nodes = True
m2 = bpy.data.materials.new("B"); m2.use_nodes = True
img = bpy.data.images.new("big", 2048, 2048); img.pixels[:] = [0.5, 0.5, 0.5, 1.0] * (2048 * 2048)
tex = m1.node_tree.nodes.new("ShaderNodeTexImage"); tex.image = img
bsdf = m1.node_tree.nodes["Principled BSDF"]
m1.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
obj.data.materials.append(m1); obj.data.materials.append(m2)
for i, p in enumerate(obj.data.polygons):
    p.material_index = i % 2
export(out + "/bad.glb")

# ---------- good.glb ----------
reset()
bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0, 0, 0.2))    # base en z=0 → y=0 en glTF
obj = bpy.context.active_object
bm = bmesh.new(); bm.from_mesh(obj.data)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.to_mesh(obj.data); bm.free()
m = bpy.data.materials.new("kraft"); m.use_nodes = True
obj.data.materials.append(m)
export(out + "/good.glb")
print("FIXTURES_OK")
'''


def main():
    tmp = tempfile.mkdtemp(prefix="glbcheck_")
    script = os.path.join(tmp, "fixtures.py")
    open(script, "w", encoding="utf-8").write(FIXTURES)
    r = subprocess.run([BLENDER, "-b", "--python", script, "--", tmp],
                       capture_output=True, text=True, timeout=300)
    if "FIXTURES_OK" not in r.stdout:
        print(r.stdout[-3000:]); print(r.stderr[-3000:])
        raise SystemExit("Blender no generó los fixtures")

    bad = {f["check"]: f["pass"] for f in glb_check.check(os.path.join(tmp, "bad.glb"), "package")}
    good = {f["check"]: f["pass"] for f in glb_check.check(os.path.join(tmp, "good.glb"), "package")}

    must_fail = ["1.escala", "1.pivote_en_base", "2.triangulos", "2.caras_sueltas",
                 "2.normales_invertidas", "4.un_material", "5.textura_max_1024"]
    for k in must_fail:
        assert bad[k] is False, "bad.glb debía FALLAR en %s y pasó" % k
    for k, v in good.items():
        assert v is True, "good.glb debía PASAR en %s y falló" % k
    print("ROJO: bad.glb falla en %d/%d puntos esperados" % (len(must_fail), len(must_fail)))
    print("VERDE: good.glb pasa %d/%d" % (len(good), len(good)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
