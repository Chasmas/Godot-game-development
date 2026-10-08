"""Export the isolated idle pilot and inspect actual GLB animation channels."""
import bpy
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
surface = '--surface' in sys.argv
native = '--native' in sys.argv or surface
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman' / ('idle_native_candidate_v3' if surface else 'idle_native_candidate_v2' if native else 'idle_candidate_v1')
bpy.ops.wm.open_mainfile(filepath=str(OUT / 'dog_doberman_idle_candidate.blend'))
scene = bpy.context.scene
# Include the duplicate endpoint so the exported clip is exactly 2.4 seconds.
scene.frame_end = 73
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in scene.objects:
    if obj.type in {'MESH', 'ARMATURE'}:
        obj.select_set(True)
target = OUT / 'dog_doberman_idle_candidate.glb'
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
    use_selection=True, export_animations=True, export_morph=True,
    export_animation_mode='ACTIVE_ACTIONS', export_anim_slide_to_zero=True, export_apply=False,
    export_optimize_animation_size=False)
blob = target.read_bytes()
magic, version, size = struct.unpack_from('<III', blob)
assert magic == 0x46546C67 and version == 2 and size == len(blob)
length, kind = struct.unpack_from('<II', blob, 12)
assert kind == 0x4E4F534A
document = json.loads(blob[20:20+length])
animations = []
for animation in document.get('animations', []):
    paths = [channel['target']['path'] for channel in animation['channels']]
    durations = []
    for sampler in animation['samplers']:
        accessor = document['accessors'][sampler['input']]
        durations.append(accessor['max'][0] - accessor['min'][0])
    animations.append({'name': animation.get('name'), 'channels': len(paths),
        'paths': sorted(set(paths)), 'duration_seconds': max(durations)})
assert len(animations) == 1, 'Skeleton and breath must share one playable clip'
assert {'rotation', 'weights'} <= set(animations[0]['paths'])
assert abs(animations[0]['duration_seconds'] - 2.4) < .001
report = {'runtime_approved': False, 'scope': 'GLB structure only; Godot playback pending',
    'skins': len(document.get('skins', [])), 'animations': animations,
    'bytes': len(blob)}
(OUT / 'export_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
