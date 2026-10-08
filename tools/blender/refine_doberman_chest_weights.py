"""Keep sternum attached to chest and isolate lower-leg influence above elbow."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT/'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/walk_candidate_v4'
OUT = BASE/'native_skin_candidate_v5'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'native_skin_candidate_v4/dog_doberman_native_skin.blend'))
obj = next(o for o in bpy.context.scene.objects if o.type=='MESH')
names = [g.name for g in obj.vertex_groups]
chest = names.index('chest')
changed = 0
maximum_transfer = 0.
sole_maximum_change = 0.

def smooth(value):
    value = max(0.,min(1.,value))
    return value*value*(3-2*value)

rows = []
for vertex in obj.data.vertices:
    p = vertex.co
    before = {g.group:g.weight for g in vertex.groups}
    result = dict(before)
    mask = smooth((-p.y-.08)/.06)*smooth((p.y+.38)/.06)
    mask *= smooth((p.z-.32)/.08)*smooth((.58-p.z)/.05)
    inner = 1.-smooth((abs(p.x)-.03)/.055)
    transferred = 0.
    for index,weight in before.items():
        name = names[index]
        if name.startswith('front_'):
            reduction = inner
            if name.endswith('_lower') or name.endswith('_paw'):
                reduction = max(reduction,smooth((p.z-.34)/.06))
            amount = weight*mask*reduction
            result[index] -= amount
            transferred += amount
    if transferred>.000001:
        changed += 1
        result[chest] = result.get(chest,0.)+transferred
        maximum_transfer = max(maximum_transfer,transferred)
    retained = sorted([(index,weight) for index,weight in result.items() if weight>.0001],key=lambda item:item[1],reverse=True)[:4]
    total = sum(weight for _,weight in retained)
    result = {index:weight/total for index,weight in retained}
    if p.z<.06:
        sole_maximum_change = max(sole_maximum_change,max(abs(result.get(index,0.)-before.get(index,0.)) for index in before.keys()|result.keys()))
    rows.append(result)
assert sole_maximum_change<.000001
obj.vertex_groups.clear()
groups = [obj.vertex_groups.new(name=name) for name in names]
for vertex_index,row in enumerate(rows):
    for group_index,weight in row.items():
        groups[group_index].add([vertex_index],weight,'REPLACE')
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'dog_doberman_native_skin.blend'))
report = {'runtime_approved':False,'animation_approved':False,
    'operation':'Smooth inner-chest rigidity and lower-leg isolation above elbow; no geometry or clip changes',
    'changed_vertices':changed,'maximum_weight_transferred_to_chest':maximum_transfer,
    'maximum_sole_weight_change':sole_maximum_change,'scope':'Local native-skin weight candidate; deformation and contact review pending'}
(OUT/'chest_weight_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report),flush=True)
