"""Transfer an exact Godot review pose to Blender, inspect deformed skin only."""
import bpy,json,os
from pathlib import Path
from mathutils import Matrix
ROOT=Path(__file__).resolve().parents[2]
directory=Path(os.environ.get('UTHANA_ARM_POSE_SOURCE',str(ROOT/'build/uthana/cast_roster/motions/guard/merged/run_weapon_frames_closeup_contact_corrected_aim_candidate_hand_candidate_rifle_camera_-90_foreend')))
poses=json.loads((directory/'pose_012.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'build/uthana/cast_roster/motions/guard/hand_foreend_preserved/guard.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
arm.animation_data_clear()
# Godot Y-up/+Z forward -> Blender Z-up/-Y forward.
conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
inverse=conversion.inverted()
for bone in arm.pose.bones:
    assert bone.name in poses,bone.name
    desired=conversion@Matrix(poses[bone.name])@inverse
    bone.matrix=arm.matrix_world.inverted()@desired
    bpy.context.view_layer.update()
for body in [o for o in bpy.context.scene.objects if o.type=='MESH']:
    if body.data.shape_keys and 'WeaponGrip' in body.data.shape_keys.key_blocks:
        body.data.shape_keys.key_blocks['WeaponGrip'].value=1
bpy.context.view_layer.update()
worst=0
for bone in arm.pose.bones:
    expected=conversion@Matrix(poses[bone.name])@inverse
    worst=max(worst,((arm.matrix_world@bone.matrix).translation-expected.translation).length)
assert worst<.00001,worst
out=ROOT/'build/uthana/cast_roster/motions/guard/arm_pose_inspection';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'posed_guard.blend'))
report={'runtime_approved':False,'bone_world_position_transfer_error_m':worst,'pose_source':str(directory/'pose_012.json'),'pending':'Mesh intersection and anatomical review; transform parity is not clearance evidence'}
(out/'report.json').write_text(json.dumps(report,indent=2))
print('EXACT ARM POSE TRANSFERRED',worst)
