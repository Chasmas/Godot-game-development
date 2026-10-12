"""Build the Harcourt breach door from the approved ImageGen direction.

The render is deliberately a top-down leaf plate: Godot's live Door remains
the authoritative hinge/collider, while this Blender asset supplies the
specific armored identity and the post-breach debris state.
"""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/armored_breach_door_v1"
OUT.mkdir(parents=True, exist_ok=True)
REF = ROOT / "assets/art/reference/m01_armored_door_v1/concept.png"

bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, metallic=0.0, roughness=0.5, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    return mat

steel = material("Armored charcoal-blue steel", (0.055, 0.105, 0.15), 0.82, 0.34)
edge = material("Worn steel edge", (0.12, 0.145, 0.16), 0.9, 0.28)
rust = material("Oxidized hardware", (0.22, 0.065, 0.028), 0.7, 0.56)
brass = material("001 brass badge", (0.43, 0.25, 0.055), 0.9, 0.25)
warning = material("Emergency red indicator", (0.35, 0.005, 0.008), 0.3, 0.28, (1.0, 0.015, 0.02))
black = material("Door recess", (0.006, 0.009, 0.014), 0.1, 0.65)

def cube(name, location, dimensions, mat, parent=None, bevel=0.008):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("machined edge", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    if parent:
        obj.parent = parent
    return obj

def cylinder(name, location, radius, depth, mat, parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    if parent:
        obj.parent = parent
    return obj

# Gameplay leaf is 2.0m long.  Keep the centerline at y=0 so a 2D Door can
# use the preview as a direct leaf projection (hinge at x=0).
root = bpy.data.objects.new("Harcourt armored leaf root", None)
bpy.context.collection.objects.link(root)
cube("Armored leaf", (1.0, 0.0, 0.075), (2.0, 0.16, 0.15), steel, root, 0.015)
for x in (0.06, 1.94):
    cube("Reinforced edge rail", (x, 0.0, 0.16), (0.075, 0.23, 0.065), edge, root)
for x in (0.42, 1.0, 1.58):
    cube("Horizontal weld rib", (x, 0.0, 0.165), (0.055, 0.23, 0.07), edge, root, 0.005)
    for y in (-0.075, 0.075):
        cylinder("Rivet", (x, y, 0.21), 0.026, 0.018, rust, root)
# A central lockbox has a red armed lamp and a narrow cyan service seam.
cube("External lockbox", (1.0, -0.005, 0.205), (0.30, 0.19, 0.13), black, root, 0.012)
cube("Lockbox plate", (1.0, -0.005, 0.274), (0.23, 0.14, 0.02), edge, root, 0.004)
# A narrow rectangular warning lens reads at the game's 10px gate thickness.
# The former round lamp became a large pink disc after orthographic projection.
cube("Lock warning lens", (1.0, 0.0, 0.292), (0.060, 0.045, 0.018), warning, root, 0.003)
cube("Charge placement panel", (1.37, 0.0, 0.185), (0.38, 0.19, 0.045), rust, root, 0.004)
for x in (0.72, 1.28):
    cube("Bolt strap", (x, 0.0, 0.19), (0.07, 0.235, 0.08), rust, root, 0.005)
# Badge and pull make the gate visibly unlike a normal motel room door.
cube("001 badge", (0.43, -0.005, 0.19), (0.22, 0.18, 0.045), brass, root, 0.004)
for x in (0.94, 1.78):
    cylinder("Hinge barrel", (x, 0.102, 0.10), 0.05, 0.19, edge, root)

# Stationary outer frame is present in the Blender beauty render only. It is
# not projected into the runtime leaf because the live M01 walls own that frame.
frame = bpy.data.objects.new("Stationary armored frame", None)
bpy.context.collection.objects.link(frame)
for x in (-0.09, 2.09):
    cube("Frame side", (x, 0.0, 0.14), (0.13, 0.32, 0.28), edge, frame, 0.012)

scene = bpy.context.scene
scene["imagegen_reference"] = str(REF.relative_to(ROOT)).replace("\\", "/")
scene["runtime_approved"] = True
scene["purpose"] = "M01 Harcourt breach gate; visual replacement only"
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.world = bpy.data.worlds.new("Dark motel exterior")
scene.world.color = (0.008, 0.01, 0.016)

bpy.ops.object.light_add(type="AREA", location=(0.8, -1.9, 2.8))
bpy.context.object.data.energy = 540
bpy.context.object.data.color = (0.22, 0.76, 1.0)
bpy.context.object.data.shape = "RECTANGLE"
bpy.context.object.data.size = 2.8
bpy.ops.object.light_add(type="AREA", location=(2.5, 1.2, 1.2))
bpy.context.object.data.energy = 420
bpy.context.object.data.color = (1.0, 0.09, 0.38)
bpy.context.object.data.size = 2.2

bpy.ops.object.camera_add(location=(2.8, -3.7, 2.7))
camera = bpy.context.object
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.9
camera.rotation_euler = (Vector((1.0, 0.0, 0.13)) - camera.location).to_track_quat("-Z", "Y").to_euler()
scene.camera = camera
scene.render.resolution_x = 1000
scene.render.resolution_y = 640
scene.render.filepath = str(OUT / "armored_breach_beauty.png")
bpy.ops.render.render(write_still=True)

# Exact runtime projection: only movable leaf, viewed down from above. This
# produces a readable 2D strip with the physical hinge at the left edge.
for obj in frame.children_recursive:
    obj.hide_render = True
camera.location = (1.0, 0.0, 8.0)
camera.rotation_euler = (0.0, 0.0, 0.0)
# Orthographic scale is image height.  With the 512:96 strip this gives an
# exact 2m horizontal view: the visual leaf maps one-to-one to Door.length.
camera.data.ortho_scale = 0.375
scene.render.resolution_x = 512
scene.render.resolution_y = 96
scene.render.filepath = str(OUT / "armored_breach_leaf_topdown.png")
bpy.ops.render.render(write_still=True)

# The post-explosion runtime decoration is deliberately nonblocking and steel,
# not the generic timber-plank fallback used by normal room doors.
for obj in root.children_recursive:
    obj.hide_render = True
debris = []
for i, (x, y, sx, sy, angle) in enumerate(((.35, -.22, .55, .12, -.30), (1.05, .14, .65, .14, .22), (1.62, -.12, .38, .10, .64), (.82, -.42, .24, .08, -.7))):
    piece = cube("Steel breach fragment %d" % i, (x, y, 0.04 + i * .01), (sx, sy, .07), edge if i % 2 else steel, None, .012)
    piece.rotation_euler.z = angle
    debris.append(piece)
camera.location = (1.0, 0.0, 8.0)
camera.rotation_euler = (0.0, 0.0, 0.0)
camera.data.ortho_scale = 1.15
scene.render.resolution_x = 512
scene.render.resolution_y = 256
scene.render.filepath = str(OUT / "armored_breach_debris_topdown.png")
bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "armored_breach_door.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "armored_breach_door.glb"), export_format="GLB", use_selection=False)
(OUT / "runtime_projection_contract.json").write_text(json.dumps({
    "reference": str(REF.relative_to(ROOT)).replace("\\", "/"),
    "leaf_image": "armored_breach_leaf_topdown.png",
    "debris_image": "armored_breach_debris_topdown.png",
    "physical_leaf_length_m": 2.0,
    "hinge": "left image edge / +x gameplay leaf origin",
    "runtime_approved": True,
    "collision": "existing Door leaf remains authoritative",
    "remaining": []
}, indent=2), encoding="utf-8")
print("M01_ARMORED_BREACH_DOOR: Blender beauty, leaf and debris projections saved")
