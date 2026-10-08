"""Stage a quadruped rig; heat weights require deformation review before use."""
import bpy
import sys
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
breed = sys.argv[sys.argv.index("--") + 1]
if breed != "shepherd":
    raise ValueError("Landmarks currently reviewed only for shepherd")
out = ROOT / "build/canine_review" / breed
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/art/Artwork/3d" / breed / "model.glb"))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
bpy.ops.object.armature_add()
arm = bpy.context.object
arm.name = "CanineRig"
bpy.ops.object.mode_set(mode="EDIT")
arm.data.edit_bones.remove(arm.data.edit_bones[0])
def bone(name, head, tail, parent=None):
    item = arm.data.edit_bones.new(name)
    item.head, item.tail = head, tail
    if parent:
        item.parent = arm.data.edit_bones[parent]
    return item
bone("Root", (0, 0.5, 0.25), (0, 0.25, 0.3))
bone("Spine", (0, 0.25, 0.3), (0, -0.38, 0.33), "Root")
bone("Neck", (0, -0.38, 0.33), (0, -0.65, 0.36), "Spine")
bone("Head", (0, -0.65, 0.36), (0, -0.89, 0.23), "Neck")
bone("Tail", (0, 0.57, 0.3), (0, 0.9, -0.2), "Root")
for side, sign in [("L", 1), ("R", -1)]:
    x = sign * 0.13
    for limb, y, knee_y, ankle_y, parent in [
        ("Front", -0.43, -0.4, -0.47, "Spine"),
        ("Hind", 0.48, 0.36, 0.56, "Root")]:
        upper = limb + "Upper." + side
        lower = limb + "Lower." + side
        foot = limb + "Paw." + side
        bone(upper, (x, y, 0.15 if limb == "Front" else 0.27), (x, knee_y, -0.22), parent)
        bone(lower, (x, knee_y, -0.22), (x, ankle_y, -0.58), upper)
        bone(foot, (x, ankle_y, -0.58), (x, ankle_y - 0.12, -0.67), lower)
bpy.ops.object.mode_set(mode="OBJECT")
# Heat weights often fail on generated disconnected surface fragments. Build a
# watertight proxy solely for weighting; never remesh the textured source.
proxy = mesh.copy()
proxy.data = mesh.data.copy()
proxy.name = "WeightProxy"
bpy.context.collection.objects.link(proxy)
bpy.ops.object.select_all(action="DESELECT")
proxy.select_set(True)
bpy.context.view_layer.objects.active = proxy
remesh = proxy.modifiers.new("WeightSurface", "REMESH")
remesh.mode = "VOXEL"
remesh.voxel_size = 0.025
bpy.ops.object.modifier_apply(modifier=remesh.name)
bpy.ops.object.select_all(action="DESELECT")
proxy.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
bpy.context.view_layer.objects.active = mesh
for group in proxy.vertex_groups:
    mesh.vertex_groups.new(name=group.name)
transfer = mesh.modifiers.new("TransferSkinWeights", "DATA_TRANSFER")
transfer.object = proxy
transfer.use_vert_data = True
transfer.data_types_verts = {"VGROUP_WEIGHTS"}
transfer.vert_mapping = "POLYINTERP_NEAREST"
bpy.ops.object.modifier_apply(modifier=transfer.name)
# Keep the torso attached to the axial skeleton. Surface proximity alone gives
# the front legs too much of the chest, pulling it apart during recovery.
adjusted = 0
for vertex in mesh.data.vertices:
    position = mesh.matrix_world @ vertex.co
    blend = max(0.0, min(1.0, (position.z - 0.02) / 0.20))
    blend = blend * blend * (3 - 2 * blend)
    if blend <= 0:
        continue
    returned = 0.0
    for entry in list(vertex.groups):
        group = mesh.vertex_groups[entry.group]
        if group.name.startswith(("Front", "Hind")):
            returned += entry.weight * blend
            group.add([vertex.index], entry.weight * (1 - blend), "REPLACE")
    if returned:
        axial = mesh.vertex_groups["Root" if position.y > 0.15 else "Spine"]
        axial.add([vertex.index], returned, "ADD")
        adjusted += 1
# Soles belong to the paw, rather than a blend of shin and opposite leg.
# Blend up the ankle so the transition remains soft while toes stay coherent.
for vertex in mesh.data.vertices:
    point = mesh.matrix_world @ vertex.co
    amount = max(0.0, min(1.0, (-point.z - 0.51) / 0.10))
    amount = amount * amount * (3 - 2 * amount)
    if amount <= 0:
        continue
    paw_name = ("Front" if point.y < 0 else "Hind") + "Paw." + ("L" if point.x > 0 else "R")
    for entry in list(vertex.groups):
        mesh.vertex_groups[entry.group].add([vertex.index], entry.weight * (1 - amount), "REPLACE")
    mesh.vertex_groups[paw_name].add([vertex.index], amount, "ADD")
# Match glTF's four-influence skin before review, rather than letting export
# silently change the deformation that was inspected in Blender.
bpy.context.view_layer.objects.active = mesh
bpy.ops.object.vertex_group_limit_total(limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
skin = mesh.modifiers.new("CanineSkin", "ARMATURE")
skin.object = arm
skin.use_deform_preserve_volume = True
mesh.parent = arm
proxy.hide_render = True
proxy.hide_set(True)
unweighted = [vertex.index for vertex in mesh.data.vertices if not vertex.groups]
report = {"breed": breed, "candidate_only": True, "reviewed_deformation": False,
          "bones": len(arm.data.bones), "unweighted_vertices": len(unweighted),
          "weight_proxy_vertices": len(proxy.data.vertices),
          "torso_weights_adjusted": adjusted,
          "notes": "Provisional landmarks and proxy heat weights; inspect shoulders, knees, paws and head before animation/export."}
(out / "rig_audit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
arm.show_in_front = True
bpy.ops.wm.save_as_mainfile(filepath=str(out / "rig_candidate.blend"))
print(json.dumps(report))
