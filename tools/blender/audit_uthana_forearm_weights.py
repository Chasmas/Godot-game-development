"""Read-only anatomical forearm weight review on retained source geometry."""
import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'build/uthana/cast_roster/motions/guard/hand_foreend_preserved/guard.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and 'RightForeArm' in o.vertex_groups)
groups={g.index:g.name for g in body.vertex_groups}
rows=[]
for side in ['Right','Left']:
    elbow=(arm.matrix_world@arm.data.bones[side+'ForeArm'].matrix_local).translation
    wrist=(arm.matrix_world@arm.data.bones[side+'Hand'].matrix_local).translation
    axis=wrist-elbow;length=axis.length
    samples=[]
    for v in body.data.vertices:
        p=body.matrix_world@v.co
        t=(p-elbow).dot(axis)/axis.length_squared
        if not .2<t<.8:continue
        distance=(p-(elbow+axis*t)).length
        if distance>.065:continue
        weights={groups[g.group]:g.weight for g in v.groups}
        if sum(weights.get(side+s,0) for s in ['Arm','ForeArm','Hand'])<.25:continue
        samples.append({'vertex':v.index,'fraction':t,'axis_distance_m':distance,'weights':weights})
    assert len(samples)>20,(side,len(samples))
    average={name:sum(s['weights'].get(name,0) for s in samples)/len(samples) for name in [side+'Arm',side+'ForeArm',side+'Hand']}
    rows.append({'side':side,'sample_count':len(samples),'segment_length_m':length,'average_weights':average,'vertices':samples})
out=ROOT/'build/uthana/cast_roster/motions/guard/arm_pose_inspection'
(out/'forearm_weight_review.json').write_text(json.dumps({'runtime_approved':False,'scope':'Rest-space middle60% of forearm within65mm centreline, arm-influence>.25; anatomical selection requires visual review','rows':rows},indent=2))
print('FOREARM WEIGHTS',json.dumps([{k:v for k,v in row.items() if k!='vertices'} for row in rows]))
