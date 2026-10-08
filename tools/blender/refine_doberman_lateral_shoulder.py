"""Reduce upper-body shoulder shearing without changing paws, geometry or clips."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/walk_candidate_v4'
OUT = BASE / 'lateral_shoulder_candidate_v1'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'native_skin_candidate_v6/dog_doberman_native_skin.blend'))
obj = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
chest = obj.vertex_groups['chest']

def smooth(value):
    value = max(0., min(1., value))
    return value * value * (3 - 2 * value)

changed = 0
maximum = 0
before_soles = {}
for vertex in obj.data.vertices:
    if vertex.co.z < .06:
        before_soles[vertex.index] = [(group.group, group.weight) for group in vertex.groups]
    p = vertex.co
    mask = smooth((-p.y-.10)/.06) * smooth((p.y+.40)/.06)
    mask *= smooth((p.z-.40)/.10) * smooth((.62-p.z)/.05)
    mask *= smooth((abs(p.x)-.025)/.05)
    transferred = 0.
    for influence in list(vertex.groups):
        group = obj.vertex_groups[influence.group]
        if group.name.startswith('front_') and group.name.endswith('_upper'):
            amount = influence.weight * mask * .5
            if amount > .000001:
                group.add([vertex.index], influence.weight-amount, 'REPLACE')
                transferred += amount
    if transferred:
        original = next((group.weight for group in vertex.groups if group.group == chest.index), 0.)
        chest.add([vertex.index], original+transferred, 'REPLACE')
        # Keep the same four-weight export contract after adding chest.
        retained = sorted([(group.group, group.weight) for group in vertex.groups if group.weight > .0001], key=lambda item: item[1], reverse=True)[:4]
        total = sum(weight for _, weight in retained)
        for group in list(vertex.groups):
            obj.vertex_groups[group.group].remove([vertex.index])
        for index, weight in retained:
            obj.vertex_groups[index].add([vertex.index], weight/total, 'REPLACE')
        changed += 1
        maximum = max(maximum, transferred)
for index, weights in before_soles.items():
    assert [(group.group, group.weight) for group in obj.data.vertices[index].groups] == weights
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'dog_doberman_native_skin.blend'))
bpy.ops.object.select_all(action='DESELECT')
for item in bpy.context.scene.objects:
    if item.type in {'MESH', 'ARMATURE'}:
        item.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'dog_doberman_native_skin.glb'), export_format='GLB',
    use_selection=True, export_animation_mode='ACTIVE_ACTIONS', export_anim_slide_to_zero=True,
    export_optimize_animation_size=False, export_force_sampling=True, export_apply=False)
report = {'runtime_approved': False, 'animation_approved': False,
          'changed_vertices': changed, 'maximum_transfer_to_chest': maximum,
          'sole_weights_unchanged': True, 'geometry_unchanged': True,
          'scope': 'Lateral shoulder weight candidate; export correspondence, contact and visual review pending'}
(OUT / 'weight_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
