"""Isolated attachment study, not firing-animation approval."""
import bpy,json
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/meshy_import/cass_red_rebel_weapon_combo_2'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'cass_meshy_weapon_combo_2_staging.blend'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
hand=arm.pose.bones['mixamorig:RightHand']
before=set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/art/weapons3d/staging/service_pistol_v3/service_pistol.glb'))
added=set(bpy.context.scene.objects)-before
root=next(o for o in added if o.name.startswith('ServicePistol'))
anchor=next(o for o in added if o.name.startswith('GripAnchor'))
# Root is driven explicitly by the wrist pose each sampled frame. No offsets
# are accepted as production grip calibration until close-up visual review.
local=Matrix.Translation(-anchor.location)
rows=[]
root.rotation_mode='QUATERNION'
for f in range(1,272):
 bpy.context.scene.frame_set(f)
 root.matrix_world=arm.matrix_world @ hand.matrix @ local
 bpy.context.view_layer.update()
 pos=anchor.matrix_world.translation
 wrist=(arm.matrix_world @ hand.matrix).translation
 root.keyframe_insert(data_path='location',frame=f)
 root.keyframe_insert(data_path='rotation_quaternion',frame=f)
 root.keyframe_insert(data_path='scale',frame=f)
 if f in (1,70,136,205,271):
  rows.append({'frame':f,'anchor_wrist_error_m':(pos-wrist).length,'wrist':list(wrist)})
OUT.joinpath('pistol_attachment_probe.json').write_text(json.dumps({'scope':'wrist anchor binding only; finger contact and barrel orientation not approved','rows':rows},indent=2))
bpy.context.scene.frame_set(1)
root.matrix_world=arm.matrix_world @ hand.matrix @ local
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'cass_pistol_attachment_probe.blend'))
print('CASS_ATTACHMENT_PROBE',rows)
