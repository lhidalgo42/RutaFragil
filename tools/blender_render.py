"""Renderiza tres vistas de un .glb con Blender headless, para evidencia (M-ART paso 5).

    blender -b --python tools/blender_render.py -- <in.glb> <out.png>

Escribe <out>_front34.png, <out>_rear34.png y <out>_side.png. Blender 5.1 verificado.
"""
import bpy, math, sys, os
argv = sys.argv[sys.argv.index("--")+1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
# bbox centro y tamaño
import mathutils
mn = mathutils.Vector((1e9,)*3); mx = mathutils.Vector((-1e9,)*3)
for o in objs:
    for c in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(c)
        mn = mathutils.Vector(map(min, mn, w)); mx = mathutils.Vector(map(max, mx, w))
ctr = (mn+mx)/2; size = max(mx-mn)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE" if hasattr(bpy.types, "SceneEEVEE") else "BLENDER_WORKBENCH"
try:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
except Exception:
    pass
scene.render.resolution_x = 1400; scene.render.resolution_y = 900
world = bpy.data.worlds.new("W"); scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.85, 0.85, 0.88, 1); bg.inputs[1].default_value = 1.0
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN")); sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35)); scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); scene.collection.objects.link(cam); scene.camera = cam
def shoot(az_deg, el_deg, suffix):
    d = size * 2.3
    az, el = math.radians(az_deg), math.radians(el_deg)
    cam.location = ctr + mathutils.Vector((d*math.cos(el)*math.sin(az), -d*math.cos(el)*math.cos(az), d*math.sin(el)))
    direction = ctr - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = out.replace(".png", suffix + ".png")
    bpy.ops.render.render(write_still=True)
shoot(35, 18, "_front34")
shoot(215, 18, "_rear34")
shoot(90, 5, "_side")
print("BBOX", tuple(round(v,3) for v in mn), tuple(round(v,3) for v in mx))
