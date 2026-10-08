"""Diffuse shoulder skin weights over welded adjacency; preserve sole weights."""
import bpy
import json
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
OUT = BASE / 'walk_candidate_v3'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'walk_candidate_v2/dog_doberman_walk_candidate.blend'))
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
positions = np.array([v.co[:] for v in obj.data.vertices])
keys, inverse = np.unique(np.round(positions, 6), axis=0, return_inverse=True)
names = [g.name for g in obj.vertex_groups]
original = np.zeros((len(positions), len(names)),dtype=np.float32)
for v in obj.data.vertices:
    for group in v.groups:
        original[v.index,group.group] = group.weight
weights = np.zeros((len(keys), len(names)),dtype=np.float32)
np.add.at(weights,inverse,original)
weights /= np.bincount(inverse)[:,None]
edges = np.unique(np.sort(inverse[np.array([e.vertices[:] for e in obj.data.edges])],axis=1),axis=0)
edges = edges[edges[:,0]!=edges[:,1]]
distance_to_boundary = np.minimum.reduce([keys[:,1]+.38, -.06-keys[:,1], keys[:,2]-.28, .57-keys[:,2]])
amount = np.clip(distance_to_boundary/.04,0.,1.)
amount = amount*amount*(3-2*amount)
region = np.flatnonzero(amount>0.)
local = np.full(len(keys),-1,dtype=np.int32)
local[region] = np.arange(len(region))
sources = np.concatenate([edges[:,0],edges[:,1]])
targets = np.concatenate([edges[:,1],edges[:,0]])
selected = local[targets]>=0
sources,targets = sources[selected],local[targets[selected]]
degree = np.bincount(targets,minlength=len(region))[:,None]
before_gap = np.abs(weights[edges[:,0]]-weights[edges[:,1]]).sum(axis=1)
for _ in range(60):
    means = np.zeros((len(region),len(names)),dtype=np.float32)
    np.add.at(means,targets,weights[sources])
    means /= degree
    alpha = (.45*amount[region])[:,None]
    weights[region] = weights[region]*(1-alpha)+means*alpha
result = original.copy()
affected_vertices = amount[inverse]>0.
result[affected_vertices] = weights[inverse[affected_vertices]]
result /= result.sum(axis=1)[:,None]
sole_mask = positions[:,2]<.06
assert np.max(np.abs(result[sole_mask]-original[sole_mask]))<.000001
obj.vertex_groups.clear()
groups = [obj.vertex_groups.new(name=name) for name in names]
for index,row in enumerate(result):
    for group_index in np.flatnonzero(row>.000001):
        groups[group_index].add([index],float(row[group_index]),'REPLACE')
after_gap = np.abs(weights[edges[:,0]]-weights[edges[:,1]]).sum(axis=1)
region_edges = (amount[edges[:,0]]>0.) | (amount[edges[:,1]]>0.)
report = {'runtime_approved':False,'animation_approved':False,
    'scope':'Local shoulder weight diffusion only; gait pose validation pending',
    'iterations':60,'affected_vertices':int(affected_vertices.sum()),
    'sole_weights_preserved':True,'source_geometry_unchanged':True,
    'maximum_regional_adjacent_weight_gap_before':float(before_gap[region_edges].max()),
    'maximum_regional_adjacent_weight_gap_after':float(after_gap[region_edges].max()),
    'minimum_weight_sum':float(result.sum(axis=1).min()),
    'maximum_weight_sum':float(result.sum(axis=1).max())}
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dog_doberman_walk_candidate.blend'))
(OUT/'shoulder_weight_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report),flush=True)
