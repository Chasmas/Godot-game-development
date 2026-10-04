"""Blender (run inside it): a character GLB rendered straight from above.

  blender -b --python tools/art/render_topdown.py -- <in.glb> <out_dir> [--frames 8] [--size 256] [--side]

Orthographic camera looking straight down (the game's view), the figure
turned to face +X (the game's "forward"), a warm key light from the top
left with a cool neon rim, transparent background. Writes out_dir/f00.png ..
spread over the animation; --side also renders a front view for checking.
"""
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
frames = int(argv[argv.index("--frames") + 1]) if "--frames" in argv else 8
size = int(argv[argv.index("--size") + 1]) if "--size" in argv else 256
os.makedirs(out, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
objs = [o for o in sc.objects]
arm = next((o for o in objs if o.type == "ARMATURE"), None)
meshes = [o for o in objs if o.type == "MESH"]
root = arm or meshes[0]
# face +X: glTF forward (+Z) arrives as -Y in Blender
top = [o for o in objs if o.parent is None]
for o in top:
    o.rotation_mode = "XYZ"
    o.rotation_euler.z += math.radians(90)
bpy.context.view_layer.update()

# frame range from the action
act = arm.animation_data.action if arm and arm.animation_data and arm.animation_data.action else None
f0, f1 = (int(act.frame_range[0]), int(act.frame_range[1])) if act else (1, 1)
sc.frame_start, sc.frame_end = f0, f1

# size of the figure (bounding box over the animation's first frame)
sc.frame_set(f0)
pts = []
for m in meshes:
    ev = m.evaluated_get(bpy.context.evaluated_depsgraph_get())
    pts += [ev.matrix_world @ Vector(c) for c in ev.bound_box]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
height = mx.z - mn.z
centre = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, 0))

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = height * float(argv[argv.index("--fit") + 1]) if "--fit" in argv else height * 0.6   # arms out, a gun forward
cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam)
cam.location = (centre.x, centre.y, mx.z + 5)
cam.rotation_euler = (0, 0, 0)            # looking straight down -Z
sc.camera = cam

def light(name, kind, energy, color, rot):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    lo = bpy.data.objects.new(name, ld)
    lo.rotation_euler = [math.radians(a) for a in rot]
    sc.collection.objects.link(lo)
light("key", "SUN", 3.2, (1.0, 0.9, 0.8), (35, 0, 135))
light("rim", "SUN", 1.6, (0.35, 0.8, 1.0), (60, 0, -45))
light("fill", "SUN", 0.6, (1.0, 0.4, 0.7), (50, 0, 45))
world = bpy.data.worlds.new("w")
world.color = (0.03, 0.02, 0.05)
sc.world = world

sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
sc.render.film_transparent = True
sc.render.resolution_x = sc.render.resolution_y = size
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.view_settings.view_transform = "Standard"

# the camera follows the hips: moves that travel (a punch, a fall) stay framed
hips = None
if arm:
    for b in arm.pose.bones:
        if "hip" in b.name.lower() or "pelvis" in b.name.lower():
            hips = b
            break
def follow():
    if hips:
        p = arm.matrix_world @ hips.head
        cam.location.x, cam.location.y = p.x, p.y

n = max(1, frames)
for i in range(n):
    f = f0 + int(round((f1 - f0) * i / max(1, n - (0 if f1 == f0 else 0))))
    sc.frame_set(min(f, f1))
    follow()
    sc.render.filepath = os.path.join(out, "f%02d.png" % i)
    bpy.ops.render.render(write_still=True)
if "--side" in argv:
    cam.location = (centre.x + 6, centre.y, (mn.z + mx.z) / 2)
    cam.rotation_euler = (math.radians(90), 0, math.radians(90))
    sc.frame_set(f0)
    sc.render.filepath = os.path.join(out, "side.png")
    bpy.ops.render.render(write_still=True)
print("rendered", n, "frames of", f0, "-", f1, "height", round(height, 2))
