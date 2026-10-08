"""Measure the deformation change caused by glTF's four-weight linear skinning."""
import bpy
import json
import sys
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/idle_candidate_v1'
WALK = '--walk' in sys.argv
if WALK:
    OUT = OUT.parent / 'walk_candidate_v4/baked_candidate_v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT / ('dog_doberman_walk_baked.blend' if WALK else 'dog_doberman_idle_candidate.blend')))
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
modifier = next(m for m in obj.modifiers if m.type == 'ARMATURE')
rig = modifier.object
deform_groups = {g.index for g in obj.vertex_groups if g.name in rig.data.bones and rig.data.bones[g.name].use_deform}
positions = np.array([v.co[:] for v in obj.data.vertices])
paws = (positions[:, 2] < .06) & (abs(positions[:, 0]) > .025) & (abs(positions[:, 1]) > .13)
frames = list(range(1, 74, 9))
if WALK:
    frames = list(range(1,32))

def evaluated(frame):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    evaluated_obj = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated_obj.to_mesh()
    result = np.empty(len(mesh.vertices) * 3, dtype=np.float32)
    mesh.vertices.foreach_get('co', result)
    evaluated_obj.to_mesh_clear()
    return result.reshape(-1, 3)

source = {frame: evaluated(frame) for frame in frames}
pruned_vertices = 0
max_discarded_weight = 0.
for vertex in obj.data.vertices:
    weights = sorted([(g.group, g.weight) for g in vertex.groups if g.group in deform_groups], key=lambda item: item[1], reverse=True)
    if len(weights) > 4:
        pruned_vertices += 1
        max_discarded_weight = max(max_discarded_weight, sum(weight for _, weight in weights[4:]))
        for index, _ in weights[4:]:
            obj.vertex_groups[index].remove([vertex.index])
        total = sum(weight for _, weight in weights[:4])
        for index, weight in weights[:4]:
            obj.vertex_groups[index].add([vertex.index], weight / total, 'REPLACE')
modifier.use_deform_preserve_volume = False
measurements = []
for frame in frames:
    errors = np.linalg.norm(evaluated(frame) - source[frame], axis=1)
    measurements.append({'frame': frame, 'maximum_difference_m': float(errors.max()),
        'p99_difference_m': float(np.quantile(errors, .99)),
        'maximum_paw_difference_m': float(errors[paws].max())})
report = {'runtime_approved': False, 'scope': 'Nine idle mesh samples: Blender full-weight dual-quaternion versus four-weight linear skinning; no locomotion validation',
    'vertices': len(positions), 'pruned_vertices': pruned_vertices,
    'maximum_discarded_weight': max_discarded_weight, 'samples': measurements}
if WALK:
    report['scope'] = 'All 31 walk mesh samples: Blender full-weight dual-quaternion versus four-weight linear skinning; no Godot or runtime approval'
report['maximum_difference_m'] = max(sample['maximum_difference_m'] for sample in measurements)
report['maximum_paw_difference_m'] = max(sample['maximum_paw_difference_m'] for sample in measurements)
(OUT / 'export_skin_difference_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({key:value for key,value in report.items() if key!='samples'}), flush=True)
