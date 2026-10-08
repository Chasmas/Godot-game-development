"""Blender: print a model's bounding box and render it from above and from the
+X / -Y sides, to see which way it points.  blender -b --python tools/art/car_probe.py -- <model.glb> <out_prefix>"""
import bpy, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=argv[0])
sc = bpy.context.scene
pts = [o.matrix_world @ Vector(c) for o in sc.objects if o.type == "MESH" for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
print("BBOX", tuple(round(v, 3) for v in lo), tuple(round(v, 3) for v in hi))
mid = (lo + hi) * 0.5
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(hi - lo) * 1.15
sc.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3
sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(30), 0, math.radians(30))
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.35, 0.35, 0.4)
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = 384
for name, loc, rot in (("top", (0, 0, 20), (0, 0, 0)), ("px", (20, 0, 0), (90, 0, 90)), ("ny", (0, -20, 0), (90, 0, 0))):
    cam.location = mid + Vector(loc)
    cam.rotation_euler = [math.radians(a) for a in rot]
    sc.render.filepath = argv[1] + "_" + name + ".png"
    bpy.ops.render.render(write_still=True)
