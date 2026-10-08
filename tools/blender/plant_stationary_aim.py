"""Blender audit plus isolated GLB lower-body correction; other tracks stay byte-identical."""
import bpy, sys, json, struct, copy, hashlib
from pathlib import Path

root = Path(__file__).resolve().parents[2]
looks = sys.argv[sys.argv.index('--') + 1:]
stage = root / 'build/stationary_aim_candidates'
stage.mkdir(parents=True, exist_ok=True)

def read(path):
    raw = path.read_bytes()
    length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+length])
    at = 20+length
    size = struct.unpack_from('<I', raw, at)[0]
    return doc, raw[at+8:at+8+size]

def first_value(doc, blob, animation, node, kind):
    for channel in animation['channels']:
        if channel['target'] == {'node': node, 'path': kind}:
            sampler = animation['samplers'][channel['sampler']]
            assert sampler.get('interpolation', 'LINEAR') in ('LINEAR', 'STEP')
            accessor = doc['accessors'][sampler['output']]
            view = doc['bufferViews'][accessor['bufferView']]
            count = 4 if kind == 'rotation' else 3
            offset = view.get('byteOffset', 0)+accessor.get('byteOffset', 0)
            return struct.unpack_from('<'+'f'*count, blob, offset)
    return doc['nodes'][node].get(kind, {'rotation': [0,0,0,1], 'translation': [0,0,0], 'scale': [1,1,1]}[kind])

for look in looks:
    source = root / f'assets/art/cast3d_rt/{look}/{look}.glb'
    doc, original = read(source)
    result = copy.deepcopy(doc)
    blob = bytearray(original)
    idle = next(a for a in doc['animations'] if a['name'] == 'idle')
    lower = {i for i,n in enumerate(doc['nodes']) if n.get('name') == 'Hips' or n.get('name','').startswith(('LeftUpLeg','RightUpLeg','LeftLeg','RightLeg','LeftFoot','RightFoot','LeftToe','RightToe'))}
    assert len(lower) >= 7
    changed = []
    for animation in result['animations']:
        if animation['name'] not in ('aim', 'aim_dual'): continue
        for channel in animation['channels']:
            target = channel['target']
            if target['node'] not in lower: continue
            kind = target['path']
            assert kind in ('rotation', 'translation', 'scale')
            sampler = copy.deepcopy(animation['samplers'][channel['sampler']])
            count = result['accessors'][sampler['input']]['count']
            values = first_value(doc, original, idle, target['node'], kind)
            payload = struct.pack('<'+'f'*len(values), *values)*count
            while len(blob)%4: blob.append(0)
            view = len(result['bufferViews'])
            result['bufferViews'].append({'buffer':0, 'byteOffset':len(blob), 'byteLength':len(payload)})
            blob.extend(payload)
            accessor = len(result['accessors'])
            result['accessors'].append({'bufferView':view, 'componentType':5126, 'count':count, 'type':'VEC4' if kind == 'rotation' else 'VEC3'})
            sampler['output'] = accessor
            sampler['interpolation'] = 'LINEAR'
            channel['sampler'] = len(animation['samplers'])
            animation['samplers'].append(sampler)
            changed.append([animation['name'], doc['nodes'][target['node']]['name'], kind])
    assert changed
    for field in ('nodes','skins','meshes','materials','images','textures'):
        assert result.get(field) == doc.get(field)
    untouched = [a['name'] for a,b in zip(doc['animations'],result['animations']) if a == b]
    assert len(untouched) == len(doc['animations'])-2
    # Unmodified upper-body channels still reference their original sampler/accessor bytes.
    for before, after in zip(doc['animations'],result['animations']):
        for a,b in zip(before['channels'],after['channels']):
            if a['target']['node'] not in lower:
                assert a == b and before['samplers'][a['sampler']] == after['samplers'][b['sampler']]
    result['buffers'][0]['byteLength'] = len(blob)
    encoded = json.dumps(result,separators=(',',':')).encode()
    encoded += b' '*((-len(encoded))%4)
    blob += b'\0'*((-len(blob))%4)
    raw = struct.pack('<III',0x46546c67,2,28+len(encoded)+len(blob))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(blob),0x004e4942)+blob
    candidate = stage / f'{look}.glb'
    candidate.write_bytes(raw)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(candidate))
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    actions = {a.name:a for a in bpy.data.actions}
    measured = {}
    for clip in ('aim','aim_dual'):
        action = next(a for a in actions.values() if a.name == clip or a.name.endswith('_'+clip))
        for track in arm.animation_data.nla_tracks: track.mute = True
        arm.animation_data.action = action
        if len(action.slots): arm.animation_data.action_slot = action.slots[0]
        points = {name:[] for name in ('LeftFoot','RightFoot')}
        for i in range(33):
            first,last = action.frame_range
            bpy.context.scene.frame_set(int(first+(last-first)*i/32))
            bpy.context.view_layer.update()
            for name in points: points[name].append((arm.matrix_world @ arm.pose.bones[name].head).copy())
        motion = {name:max((a-b).length for a in positions for b in positions) for name,positions in points.items()}
        assert max(motion.values()) < .0001, motion
        measured[clip] = motion
    bpy.ops.wm.save_as_mainfile(filepath=str(stage/f'{look}.blend'))
    report = {'approved':False,'look':look,'base_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(raw).hexdigest(),'changed_lower_tracks':changed,'untouched_clips':untouched,'geometry_materials_bind_preserved':True,'upper_body_tracks_preserved':True,'blender_foot_motion_metres':measured}
    (stage/f'{look}_audit.json').write_text(json.dumps(report,indent=2))
    print('PLANTED AIM',look,measured,flush=True)
