"""Blender (run inside it): find a Meshy character's hair faces by texture colour
and height, and render a check image with them painted green.

  blender -b --python tools/art/hair_probe.py -- <rigged.glb> <out.png>

Hair = faces above the neck whose texture is a darker, saturated brown/auburn
(the face skin is lighter, the jacket red). Prints the counts and the head's
bounding box so tools/art/swap_hair.py can align another hair mesh.
"""
import bpy, sys, colorsys, math
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = next((o for o in bpy.context.scene.objects if o.type == "ARMATURE"), None)
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")

def head_info():
    if arm and "Head" in arm.data.bones and "Neck" in arm.data.bones:
        neck = arm.matrix_world @ arm.data.bones["Neck"].head_local
        head = arm.matrix_world @ arm.data.bones["Head"].head_local
        return neck, head
    zs = [ (mesh.matrix_world @ v.co).z for v in mesh.data.vertices ]
    top = max(zs)
    return Vector((0, 0, top * 0.82)), Vector((0, 0, top * 0.87))

def hair_faces(obj, neck_z):
    me = obj.data
    mat = obj.material_slots[0].material if obj.material_slots else None
    img = None
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
                break
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    uv = me.uv_layers.active.data
    picked = []
    for poly in me.polygons:
        c = obj.matrix_world @ poly.center
        if c.z < neck_z:
            continue
        u = sum(uv[i].uv[0] for i in poly.loop_indices) / poly.loop_total
        v = sum(uv[i].uv[1] for i in poly.loop_indices) / poly.loop_total
        r, g, b, _ = px[int(min(max(v, 0), 0.9999) * h), int(min(max(u, 0), 0.9999) * w)]
        hh, s, vv = colorsys.rgb_to_hsv(r, g, b)
        hue = hh * 360
        if (hue < 40 or hue > 340) and s > 0.35 and vv < 0.55:
            picked.append(poly.index)
    return picked

neck, head = head_info()
picked = hair_faces(mesh, neck.z)
print("HEAD neck", tuple(round(x, 3) for x in neck), "head", tuple(round(x, 3) for x in head))
print("HAIR faces", len(picked), "of", len(mesh.data.polygons))
# paint the picked faces green in a check render
green = bpy.data.materials.new("hair_mark")
green.diffuse_color = (0, 1, 0, 1)
mesh.data.materials.append(green)
slot = len(mesh.data.materials) - 1
for i in picked:
    mesh.data.polygons[i].material_index = slot
sc = bpy.context.scene
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
cam.data.type = "ORTHO"
cam.data.ortho_scale = 0.9
top = Vector((head.x, head.y, head.z + 0.1))
cam.location = top + Vector((0, -2.0, 0.9))
cam.rotation_euler = (math.radians(66), 0, 0)
sc.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3
sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(40), 0, math.radians(20))
sc.world = bpy.data.worlds.new("w")
sc.world.color = (0.3, 0.3, 0.35)
sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
sc.render.resolution_x = sc.render.resolution_y = 512
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
