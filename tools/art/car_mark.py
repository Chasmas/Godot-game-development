"""Blender: paint the faces of the prepped hero car inside a box green and render the
game's 50-degree view of that corner, to find stray Meshy geometry before cutting it.

  blender -b --python tools/art/car_mark.py -- <eldorado.glb> <out.png> x0 x1 y0 y1 z0 z1 [yaw_deg]

Box in the Blender frame prep_car.py builds (nose -Y, driver side +X, metres).
yaw 180 = nose up the screen (the car parked on Sunset Palms)."""
import bpy, sys, math
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, out = a[0], a[1]
x0, x1, y0, y1, z0, z1 = map(float, a[2:8])
yaw = float(a[8]) if len(a) > 8 else 180.0
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
body = bpy.data.objects["Body"]
green = bpy.data.materials.new("mark")
green.diffuse_color = (0, 1, 0, 1)
body.data.materials.append(green)
slot = len(body.data.materials) - 1
n = 0
for p in body.data.polygons:
    c = body.matrix_world @ p.center
    if x0 < c.x < x1 and y0 < c.y < y1 and z0 < c.z < z1:
        p.material_index = slot
        n += 1
print("MARKED", n)
sc = bpy.context.scene
pivot = bpy.data.objects.new("pivot", None)
sc.collection.objects.link(pivot)
for o in list(sc.objects):
    if o.parent is None and o != pivot:
        o.parent = pivot
pivot.rotation_euler.z = math.radians(yaw)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = 5.5
e = math.radians(50)
cam.location = Vector((0, -math.cos(e) * 20, 0.4 + math.sin(e) * 20))
cam.rotation_euler = (math.radians(40), 0, 0)
sc.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3
sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(35), 0, math.radians(135))
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.3, 0.3, 0.35)
engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = 700
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
