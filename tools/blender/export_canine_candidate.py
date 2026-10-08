"""Bake evaluated IK into a review-only GLB, retaining editable source rigs."""
import bpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
out = ROOT / "build/canine_review/shepherd"
clip = "idle" if "--idle" in sys.argv else ("walk" if "--walk" in sys.argv else "trot")
bpy.ops.wm.open_mainfile(filepath=str(out / (clip + "_candidate.blend")))
arm = bpy.data.objects["CanineRig"]
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name != "WeightProxy")
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.select_all(action="SELECT")
bpy.ops.nla.bake(frame_start=1, frame_end=25, step=1, only_selected=True,
                 visual_keying=True, clear_constraints=True, use_current_action=False,
                 bake_types={"POSE"})
arm.animation_data.action.name = clip
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=str(out / ("shepherd_" + clip + "_candidate.glb")),
                          export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIVE_ACTIONS")
print("Exported review-only shepherd", clip, "; runtime files unchanged")
