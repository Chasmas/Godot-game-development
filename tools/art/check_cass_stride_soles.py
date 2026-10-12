"""Measure actual skinned boot clearance, not just ankle target accuracy."""
from pathlib import Path
import bpy
ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'build/locomotion_candidates/cass/walk_contact_candidate.blend'))
mesh = next(o for o in bpy.context.scene.objects if o.type=='MESH')
groups = {side: {g.index for g in mesh.vertex_groups if g.name in [side+'Foot',side+'ToeBase']} for side in ['Left','Right']}
vertices = {side: [v.index for v in mesh.data.vertices if any(g.group in groups[side] and g.weight>.4 for g in v.groups)] for side in groups}
for frame in [0,60,120,180]:
    bpy.context.scene.frame_set(frame)
    evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    print('BOOT CLEARANCE',frame,{side: min((evaluated.matrix_world @ evaluated.data.vertices[i].co).z for i in indices) for side,indices in vertices.items()})
