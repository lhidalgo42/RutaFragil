"""python tools/blender_cleanup_test.py [--blender <path-to-blender>]

Verde: el paquete crudo real, con --outer-shell, pasa todo el checklist salvo el
punto 4 (una textura), que depende del generador y no de la limpieza; la fuente
no cambia.
Rojo: las dos guardas de --outer-shell se niegan a borrar geometría que no es una
capa interior invertida. Sin estos dos casos un cambio que quite las guardas
seguía pasando, porque el paquete real no las dispara.

Blender se busca en --blender, luego en la variable BLENDER, luego en el PATH y
luego en la instalación por defecto de Windows.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

WINDOWS_DEFAULT = r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"

# Dos fixtures que --outer-shell debe RECHAZAR. Se construyen en Blender y se
# exportan a .glb, igual que la entrada real.
FIXTURES = r'''
import bpy, bmesh, sys
out = sys.argv[sys.argv.index("--") + 1]

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True,
                              export_apply=True, export_image_format="NONE")

# (a) Dos cajas separadas, ambas mirando hacia fuera: la pequeña queda fuera de
#     la grande. Borrarla sería perder una pieza real del asset.
reset()
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
bpy.ops.mesh.primitive_cube_add(size=0.3, location=(2.0, 0, 0))
export(out + "/detached.glb")

# (b) Una caja abierta (sin tapa): la exterior no es cerrada ni manifold, así
#     que no hay «dentro» contra el que decidir.
reset()
bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
obj = bpy.context.active_object
bm = bmesh.new(); bm.from_mesh(obj.data)
bm.faces.ensure_lookup_table()
top = max(bm.faces, key=lambda f: f.calc_center_median().z)
bmesh.ops.delete(bm, geom=[top], context="FACES")
bm.to_mesh(obj.data); bm.free()
export(out + "/open.glb")
print("FIXTURES_OK")
'''


def find_blender(explicit):
    for candidate in (explicit, os.environ.get("BLENDER"), shutil.which("blender"), WINDOWS_DEFAULT):
        if candidate and Path(candidate).is_file():
            return candidate
    raise SystemExit("no encuentro Blender: pasa --blender <ruta> o define BLENDER")


def cleanup(blender, root, source, destination):
    return subprocess.run([blender, "--background", "--factory-startup",
                           "--python-exit-code", "1", "--python",
                           str(root / "tools/blender_cleanup.py"), "--",
                           str(source), str(destination), "--size", "0.4",
                           "--tris", "800", "--texture", "1024", "--pivot", "base",
                           "--outer-shell"],
                          capture_output=True, encoding="utf-8", errors="replace", timeout=120)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--blender", default=None)
    arguments = parser.parse_args()
    blender = find_blender(arguments.blender)
    root = Path(__file__).resolve().parent.parent
    source = root / "docs/referencias/package_raw_v1.glb"
    original_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="rutafragil_cleanup_") as directory:
        tmp = Path(directory)

        # --- verde: el paquete real ---
        destination = tmp / "package.glb"
        run = cleanup(blender, root, source, destination)
        assert run.returncode == 0, run.stdout[-3000:] + run.stderr[-3000:]
        result = subprocess.run([sys.executable, str(root / "tools/glb_check.py"),
                                 str(destination), "--kind", "package", "--pivot", "base",
                                 "--json"],
                                capture_output=True, encoding="utf-8", timeout=30)
        verdict = {f["check"]: f["pass"] for f in json.loads(result.stdout)["findings"]}
        # La limpieza responde de geometría y tamaño de textura. El punto 4 (una sola
        # textura) depende de cómo hornea el generador (TRELLIS saca color, ORM y
        # normal): se reporta, pero no es un fallo de este script.
        not_ours = {"4.una_textura"}
        failed = [k for k, ok in verdict.items() if not ok and k not in not_ours]
        assert not failed, "la limpieza dejó fallos: %s\n%s" % (failed, result.stdout)
        assert hashlib.sha256(source.read_bytes()).hexdigest() == original_hash
        for k, ok in sorted(verdict.items()):
            print("%s  %s%s" % ("OK  " if ok else "FAIL", k, "  (no depende de la limpieza)" if k in not_ours else ""))

        # --- rojo: las dos guardas ---
        script = tmp / "fixtures.py"
        script.write_text(FIXTURES, encoding="utf-8")
        built = subprocess.run([blender, "--background", "--factory-startup", "--python",
                                str(script), "--", str(tmp)],
                               capture_output=True, encoding="utf-8", errors="replace", timeout=120)
        assert "FIXTURES_OK" in built.stdout, built.stdout[-3000:] + built.stderr[-3000:]
        for name, message in (("detached", "refusing to discard a non-enclosed or outward shell"),
                              ("open", "exterior must be closed and manifold")):
            out = tmp / (name + "_clean.glb")
            run = cleanup(blender, root, tmp / (name + ".glb"), out)
            text = run.stdout + run.stderr
            assert run.returncode != 0, "%s.glb: --outer-shell debía negarse y terminó bien" % name
            assert message in text, "%s.glb: esperaba «%s», salió:\n%s" % (name, message, text[-2000:])
            assert not out.exists(), "%s.glb: se negó pero escribió salida igual" % name
            print("ROJO: %s.glb rechazado («%s»)" % (name, message))
    print("PASS: package cleanup meets every check it owns; source unchanged; guards refuse")


if __name__ == "__main__":
    main()
