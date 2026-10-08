"""Blender quaternion authoring: staged lowered ready arm, other clips untouched."""
import bpy, math, json, struct, hashlib
from pathlib import Path
from mathutils import Quaternion, Vector

# Reuse the byte-preserving GLB accessor helpers already used for cast reviews.
helpers=Path('tools/blender/author_guard_dual_locomotion.py').read_text().split('rows=[]')[0]
helpers=helpers.replace("cast3d_rt/guard/guard.glb","cast3d_rt/hunter/hunter.glb")
helpers=helpers.replace("a['name']=='aim_dual'","a['name']=='aim_melee'")
exec(helpers)
changed=[]
for anim in result['animations']:
    if anim['name']!='aim_melee': continue
    original=next(a for a in doc['animations'] if a['name']==anim['name'])
    for channel in anim['channels']:
        node=channel['target']['node']
        if channel['target']['path']!='rotation' or doc['nodes'][node]['name']!='RightArm':continue
        sampler=anim['samplers'][channel['sampler']]
        times=values(sampler['input'])
        poses=[]
        for (t,) in times:
            parent=global_rotation(original,parents[node],t)
            # In the source GLB the model faces +Z; +X rotation lowers its
            # forward arm toward the floor while retaining elbow/wrist pose.
            delta=Quaternion(Vector((1,0,0)),math.radians(32))
            q=parent.inverted() @ delta @ parent @ rotation(original,node,t)
            poses.append((q.x,q.y,q.z,q.w))
        sampler['output']=append(poses,'VEC4')
        changed.append(doc['nodes'][node]['name'])
assert changed==['RightArm']
result['buffers'][0]['byteLength']=len(blob)
encoded=json.dumps(result,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
blob+=b'\0'*((-len(blob))%4)
output=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(blob))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(blob),0x004e4942)+blob
out=Path('build/hunter_melee_ready_v1');out.mkdir(exist_ok=True)
(out/'hunter.glb').write_bytes(output)
(out/'audit.json').write_text(json.dumps({'approved':False,'source_sha256':hashlib.sha256(raw).hexdigest(),'candidate_sha256':hashlib.sha256(output).hexdigest(),'changed_clip':'aim_melee','changed_bones':changed,'unchanged_clips':[a['name'] for a in doc['animations'] if a['name']!='aim_melee']},indent=2))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str((out/'hunter.glb').resolve()))
bpy.ops.wm.save_as_mainfile(filepath=str((out/'hunter_ready.blend').resolve()))
print('HUNTER READY: only aim_melee RightArm rotation authored; staging only')
