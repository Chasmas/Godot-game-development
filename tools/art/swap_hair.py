"""Blender (run inside it): give a rigged Meshy character another model's hair,
keeping everything else (body, face, clothes, rig) untouched.

  blender -b --python tools/art/swap_hair.py -- <base_rigged.glb> <donor_rigged.glb> <out.glb> [--check out.png]

Both inputs are Meshy rig exports (same skeleton names, same height). Hair is
found per face: above the neck and hair-coloured (a darker, saturated auburn /
brown), or, on the base, anything above the neck that sticks out past the skull
(pigtails, ties). The donor's hair is moved and scaled from its Head/Neck bones
onto the base's, bound 100% to the base's Head bone, and joined to the base mesh.
Used for Cass: the cutscenes give her long loose wavy hair, the first model had
pigtails (assets/art/Artwork/3d/cass/ + cass_v2/).
"""
import bpy, bmesh, sys, colorsys, math
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
base_path, donor_path, out = argv[0], argv[1], argv[2]
check = argv[argv.index("--check") + 1] if "--check" in argv else None

bpy.ops.wm.read_factory_settings(use_empty=True)

def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in objs if o.type == "ARMATURE")
    mesh = next(o for o in objs if o.type == "MESH")
    return objs, arm, mesh

def bone_pos(arm, name):
    bones = arm.data.bones
    if name in bones:
        return arm.matrix_world @ bones[name].head_local
    if name == "Neck":
        # some Meshy rigs go Spine -> Head with no neck bone: halfway between
        return (bone_pos(arm, "Spine") + bone_pos(arm, "Head")) * 0.5
    raise KeyError(name)

def texture(obj):
    mat = obj.material_slots[0].material
    img = next(n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4), w, h

def face_colour(obj, tex, poly):
    px, w, h = tex
    uv = obj.data.uv_layers.active.data
    u = sum(uv[i].uv[0] for i in poly.loop_indices) / poly.loop_total
    v = sum(uv[i].uv[1] for i in poly.loop_indices) / poly.loop_total
    r, g, b, _ = px[int(min(max(v, 0), 0.9999) * h), int(min(max(u, 0), 0.9999) * w)]
    return colorsys.rgb_to_hsv(r, g, b)

def is_hair_colour(hsv):
    hue, s, v = hsv[0] * 360, hsv[1], hsv[2]
    # darker auburn/brown, or the brighter orange of sunlit strands
    return 4 <= hue <= 45 and (v < 0.5 or (s > 0.5 and v < 0.72) or (hue >= 14 and s > 0.55))

def is_face(c, head):
    """The face and throat (the figure faces -Y): shading there is brown too."""
    return c.y < head.y - 0.02 and abs(c.x - head.x) < 0.06 and head.z - 0.16 < c.z < head.z + 0.105

def is_front_body(c, head):
    """Neck, chest and cleavage below the face: skin, never hair."""
    return c.y < head.y and abs(c.x - head.x) < 0.11

def hair_faces(obj, arm, below_neck, skull_r):
    """Faces of the hair: above (neck - below_neck), hair-coloured, or beyond the skull,
    never the face or the front of the body."""
    neck, head = bone_pos(arm, "Neck"), bone_pos(arm, "Head")
    tex = texture(obj)
    out_ids = []
    for poly in obj.data.polygons:
        c = obj.matrix_world @ poly.center
        if c.z < neck.z - below_neck or is_face(c, head):
            continue
        if c.z < neck.z and is_front_body(c, head):
            continue
        off = math.hypot(c.x - head.x, c.y - head.y)
        hsv = face_colour(obj, tex, poly)
        # near-black above the brows is old fringe whatever its hue
        dark_fringe = c.z > head.z + 0.105 and hsv[2] < 0.3
        if is_hair_colour(hsv) or dark_fringe or (skull_r and off > skull_r and c.z > neck.z):
            out_ids.append(poly.index)
    return set(out_ids), neck, head

base_objs, base_arm, base_mesh = load(base_path)
donor_objs, donor_arm, donor_mesh = load(donor_path)

# 1. the base loses its hair (pigtails included: anything past the skull, and
#    their ends resting on the shoulders)
old_hair, b_neck, b_head = hair_faces(base_mesh, base_arm, 0.25, 0.115)
bm = bmesh.new()
bm.from_mesh(base_mesh.data)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in old_hair], context="FACES")
bm.to_mesh(base_mesh.data)
bm.free()

# 2. the donor keeps only its hair (long hair falls below the neck)
new_hair, d_neck, d_head = hair_faces(donor_mesh, donor_arm, 0.22, 0.0)
bm = bmesh.new()
bm.from_mesh(donor_mesh.data)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in new_hair], context="FACES")
bm.to_mesh(donor_mesh.data)
bm.free()

# 3. onto the base's head: scaled by neck->head length, moved head to head
donor_mesh.modifiers.clear()
donor_mesh.parent = None
mw = donor_mesh.matrix_world.copy()
donor_mesh.data.transform(mw)
donor_mesh.matrix_world.identity()
fit = float(argv[argv.index("--fit") + 1]) if "--fit" in argv else 1.06   # a touch larger: covers the old scalp
drop = float(argv[argv.index("--drop") + 1]) if "--drop" in argv else 0.015  # metres lower: sits on the head
k = (b_head - b_neck).length / max((d_head - d_neck).length, 1e-6) * fit
for v in donor_mesh.data.vertices:
    v.co = b_head + (v.co - d_head) * k - Vector((0, 0, drop))

# warmer and lighter: the donor's hair reads near black; the cutscenes paint her
# auburn. The donor's atlas now only feeds the hair, so the whole image is tinted.
tint = [float(x) for x in argv[argv.index("--tint") + 1].split(",")] if "--tint" in argv else [1.6, 1.05, 0.72]
for slot in donor_mesh.material_slots:
    for node in slot.material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            img = node.image.copy()
            img.name = "hair_auburn"
            arr = np.array(img.pixels[:], dtype=np.float32).reshape(-1, 4)
            arr[:, :3] = np.clip(arr[:, :3] * np.array(tint, dtype=np.float32), 0.0, 1.0)
            img.pixels.foreach_set(arr.ravel())
            img.pack()
            node.image = img

# 4. bound to the base's Head bone and joined to the base mesh
donor_mesh.vertex_groups.clear()
vg = donor_mesh.vertex_groups.new(name="Head")
vg.add(list(range(len(donor_mesh.data.vertices))), 1.0, "REPLACE")
base_inv = base_mesh.matrix_world.inverted()
donor_mesh.data.transform(base_inv)
donor_mesh.matrix_world = base_mesh.matrix_world.copy()
for o in donor_objs:
    if o != donor_mesh:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
donor_mesh.select_set(True)
base_mesh.select_set(True)
bpy.context.view_layer.objects.active = base_mesh
bpy.ops.object.join()
print("SWAP removed", len(old_hair), "faces, added", len(new_hair), "hair faces, scale", round(k, 3))

if base_arm.animation_data:
    base_arm.animation_data.action = None
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=False, export_image_format="AUTO")
print("WROTE", out)

if check:
    sc = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 0.75
    sc.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(40), 0, math.radians(20))
    sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.3, 0.3, 0.35)
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 384
    for i, (ang, tilt) in enumerate(((0, 70), (90, 70), (180, 70), (0, 15))):
        a = math.radians(ang)
        cam.location = b_head + Vector((math.sin(a) * 2.0, -math.cos(a) * 2.0, 2.0 * math.cos(math.radians(tilt))))
        cam.rotation_euler = (math.radians(tilt), 0, a)
        sc.render.filepath = check.replace(".png", "_%d.png" % i)
        bpy.ops.render.render(write_still=True)
