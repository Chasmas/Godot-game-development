"""Bind reviewed quadruped skeleton on a separate deformation-test candidate."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
OUT = BASE / 'skin_candidate_v1'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'rig_candidate_v2/dog_doberman_skeleton_candidate.blend'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
reports = []
deform = {b.name for b in rig.data.bones if b.use_deform}
for obj in meshes:
    indices = {g.index for g in obj.vertex_groups if g.name in deform}
    sums = [sum(g.weight for g in v.groups if g.group in indices) for v in obj.data.vertices]
    reports.append({'mesh': obj.name, 'vertices': len(sums),
                    'unweighted_vertices': sum(s < .0001 for s in sums),
                    'minimum_weight_sum': min(sums), 'maximum_weight_sum': max(sums),
                    'armature_modifiers': sum(m.type == 'ARMATURE' for m in obj.modifiers)})
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'dog_doberman_skin_candidate.blend'))
report = {'runtime_approved': False, 'rig_approved': False, 'meshes': reports,
          'method': 'Blender automatic bone heat weights on a preserved copy',
          'limitations': 'Weight coverage does not validate joint deformation or independent limb motion',
          'next': 'Render isolated leg, head, jaw and tail pose probes; correct cross-limb influence before locomotion'}
(OUT / 'skin_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
