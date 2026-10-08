"""Combine authored idle and walk on one refined native mesh, without integration."""
import bpy
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
with_start = '--with-start' in sys.argv
surface = '--surface' in sys.argv
with_stops = '--with-stops' in sys.argv
neutral_tail = '--neutral-tail' in sys.argv
with_trot = '--with-trot' in sys.argv
if with_stops and not (surface and with_start):
    raise ValueError('Stops require the corrected surface and moving start')
OUT = BASE / ('native_clips_candidate_v6' if with_stops else 'native_clips_candidate_v5' if surface else 'native_clips_candidate_v4' if with_start else 'native_clips_candidate_v1')
if neutral_tail:
    if not (surface and with_stops):
        raise ValueError('Neutral-tail candidate requires corrected surface and stops')
    OUT = BASE / 'native_clips_candidate_v7'
if with_trot:
    if not neutral_tail:
        raise ValueError('Trot bundle requires the corrected idle and stop bundle')
    OUT = BASE / 'native_clips_candidate_v8'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / ('idle_native_candidate_v4/dog_doberman_idle_candidate.blend' if neutral_tail else 'idle_native_candidate_v3/dog_doberman_idle_candidate.blend' if surface else 'idle_native_candidate_v2/dog_doberman_idle_candidate.blend')))
rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
idle = rig.animation_data.action
breath_idle = mesh.data.shape_keys.animation_data.action
walk_source = BASE / ('walk_candidate_v4/native_skin_candidate_v7/dog_doberman_native_skin.blend' if surface else 'walk_candidate_v4/native_skin_candidate_v6/dog_doberman_native_skin.blend')
with bpy.data.libraries.load(str(walk_source), link=False) as (available, loaded):
    loaded.actions = available.actions
walk_actions = [action for action in loaded.actions if action is not None]
if len(walk_actions) != 1:
    raise RuntimeError(f'Expected one baked walk action, found {len(walk_actions)}')
walk = walk_actions[0]

def add_strip(owner, action, name):
    owner.animation_data_create()
    owner.animation_data.action = action
    slot = owner.animation_data.action_slot
    track = owner.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.action_slot = slot
    strip.name = name
    strip.extrapolation = 'NOTHING'
    owner.animation_data.action = None
    return strip

add_strip(rig, idle, 'idle')
add_strip(rig, walk, 'walk')
if with_start:
    start_source = BASE / ('start_contact_candidate_v4/baked_candidate_v1/dog_doberman_walk_baked.blend' if surface else 'start_contact_candidate_v3/baked_candidate_v1/dog_doberman_walk_baked.blend')
    with bpy.data.libraries.load(str(start_source), link=False) as (available, loaded_start):
        loaded_start.actions = available.actions
    start_actions = [action for action in loaded_start.actions if action is not None]
    assert len(start_actions) == 1
    slot_audit = []
    for slot in start_actions[0].slots:
        paths = []
        for layer in start_actions[0].layers:
            for action_strip in layer.strips:
                bag = action_strip.channelbag(slot)
                if bag:
                    paths.extend(curve.data_path for curve in bag.fcurves)
        slot_audit.append({'identifier':slot.identifier, 'paths': sorted(set(paths))})
    (OUT / 'start_action_slots.json').write_text(json.dumps(slot_audit, indent=2), encoding='utf-8')
    # Separate world travel from armature pose channels. A dedicated parent
    # carries motion, and identically named NLA tracks merge into each clip.
    motion = bpy.data.objects.new('DOBERMAN_WORLD_MOTION', None)
    bpy.context.scene.collection.objects.link(motion)
    rig.parent = motion
    object_curves = []
    for layer in start_actions[0].layers:
        for action_strip in layer.strips:
            for slot in start_actions[0].slots:
                bag = action_strip.channelbag(slot)
                if bag:
                    for curve in list(bag.fcurves):
                        if curve.data_path == 'location':
                            object_curves.append((bag, curve, [curve.evaluate(frame) for frame in range(1,20)]))
    assert len(object_curves) == 3
    for clip, ending in [('idle', 73), ('walk', 31), ('start', 19)]:
        motion.animation_data_create()
        motion.animation_data.action = None
        for frame in range(1, ending+1):
            values = [0., 0., 0.]
            if clip == 'start':
                for bag, curve, samples in object_curves:
                    values[curve.array_index] = samples[frame-1]
            motion.location = values
            motion.keyframe_insert(data_path='location', frame=frame)
        add_strip(motion, motion.animation_data.action, clip)
    for bag, curve, samples in object_curves:
        bag.fcurves.remove(curve)
    add_strip(rig, start_actions[0], 'start')
add_strip(mesh.data.shape_keys, breath_idle, 'idle')
keys = mesh.data.shape_keys
keys.animation_data.action = None
breath = keys.key_blocks['Idle torso breath']
for frame in (1, 31):
    breath.value = 0
    breath.keyframe_insert(data_path='value', frame=frame)
breath_walk = keys.animation_data.action
breath_walk.name = 'walk_breath_reset'
add_strip(keys, breath_walk, 'walk')
if with_start:
    keys.animation_data.action = None
    for frame in (1, 19):
        breath.value = 0
        breath.keyframe_insert(data_path='value', frame=frame)
    add_strip(keys, keys.animation_data.action, 'start')
if with_stops:
    for source_frame in (1, 4, 7, 10, 13, 16, 19):
        clip = f'stop_{source_frame:02d}'
        source = BASE / f'blocked_stop_phase_candidates_v3/frame_{source_frame:02d}/baked_candidate_v1/dog_doberman_walk_baked.blend'
        with bpy.data.libraries.load(str(source), link=False) as (available, loaded_stop):
            loaded_stop.actions = available.actions
        actions = [action for action in loaded_stop.actions if action is not None]
        assert len(actions) == 1
        add_strip(rig, actions[0], clip)
        keys.animation_data.action = None
        motion.animation_data.action = None
        for frame in (1, 19):
            breath.value = 0
            breath.keyframe_insert(data_path='value', frame=frame)
            motion.location = (0, 0, 0)
            motion.keyframe_insert(data_path='location', frame=frame)
        add_strip(keys, keys.animation_data.action, clip)
        add_strip(motion, motion.animation_data.action, clip)
if with_trot:
    for clip, relative, ending in [
        ('trot', 'trot_candidate_v2/baked_candidate_v1/dog_doberman_walk_baked.blend', 25),
        ('start_trot', 'start_trot_candidate_v4/baked_candidate_v1/dog_doberman_walk_baked.blend', 19),
    ]:
        with bpy.data.libraries.load(str(BASE / relative), link=False) as (available, loaded_extra):
            loaded_extra.actions = available.actions
        actions = [action for action in loaded_extra.actions if action is not None]
        assert len(actions) == 1
        object_curves = []
        for layer in actions[0].layers:
            for action_strip in layer.strips:
                for slot in actions[0].slots:
                    bag = action_strip.channelbag(slot)
                    if bag:
                        for curve in list(bag.fcurves):
                            if curve.data_path == 'location':
                                object_curves.append((bag, curve, [curve.evaluate(frame) for frame in range(1, ending+1)]))
        assert len(object_curves) == (3 if clip == 'start_trot' else 0)
        motion.animation_data.action = None
        for frame in range(1, ending+1):
            values = [0., 0., 0.]
            for bag, curve, samples in object_curves:
                values[curve.array_index] = samples[frame-1]
            motion.location = values
            motion.keyframe_insert(data_path='location', frame=frame)
        add_strip(motion, motion.animation_data.action, clip)
        for bag, curve, samples in object_curves:
            bag.fcurves.remove(curve)
        add_strip(rig, actions[0], clip)
        keys.animation_data.action = None
        for frame in (1, ending):
            breath.value = 0
            breath.keyframe_insert(data_path='value', frame=frame)
        add_strip(keys, keys.animation_data.action, clip)
rig.location = (0, 0, 0)
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'dog_doberman_native_clips.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in (rig, mesh):
    obj.select_set(True)
if with_start:
    motion.select_set(True)
target = OUT / 'dog_doberman_native_clips.glb'
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
    use_selection=True, export_animations=True, export_morph=True,
    export_animation_mode='NLA_TRACKS', export_anim_slide_to_zero=True,
    export_optimize_animation_size=False, export_force_sampling=True,
    export_optimize_animation_keep_anim_object=True, export_apply=False)
blob = target.read_bytes()
length, kind = struct.unpack_from('<II', blob, 12)
assert kind == 0x4E4F534A
document = json.loads(blob[20:20+length])
clips = {}
for animation in document.get('animations', []):
    durations = [document['accessors'][sampler['input']]['max'][0] -
                 document['accessors'][sampler['input']]['min'][0]
                 for sampler in animation['samplers']]
    clips[animation['name']] = {'duration_seconds': max(durations),
                              'channels': len(animation['channels'])}
expected = {'idle', 'walk', 'start'} if with_start else {'idle', 'walk'}
if with_stops:
    expected.update(f'stop_{frame:02d}' for frame in (1, 4, 7, 10, 13, 16, 19))
    assert all(abs(clips[f'stop_{frame:02d}']['duration_seconds'] - .6) < .001 for frame in (1, 4, 7, 10, 13, 16, 19))
if with_trot:
    expected.update({'trot', 'start_trot'})
    assert abs(clips['trot']['duration_seconds'] - .8) < .001
    assert abs(clips['start_trot']['duration_seconds'] - .6) < .001
assert set(clips) == expected, clips
if with_start:
    assert abs(clips['start']['duration_seconds'] - .6) < .001
assert abs(clips['idle']['duration_seconds'] - 2.4) < .001
assert abs(clips['walk']['duration_seconds'] - 1.0) < .001
(OUT / 'export_audit.json').write_text(json.dumps({
    'runtime_approved': False, 'animation_approved': False,
    'clips': clips, 'scope': 'Combined GLB structure; transition validation pending'
}, indent=2), encoding='utf-8')
print(json.dumps(clips), flush=True)
