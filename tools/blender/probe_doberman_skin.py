"""Measure evaluated deformation for isolated limb pose probes."""
import bpy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/skin_candidate_v6'
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'dog_doberman_skin_candidate.blend'))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
def evaluated():
    bpy.context.view_layer.update()
    result = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = result.to_mesh()
    points = [v.co.copy() for v in mesh.vertices]
    result.to_mesh_clear()
    return points
rest = evaluated()
regions = {pair+'_'+side: [v.index for v in obj.data.vertices
    if v.co.z < .20 and (v.co.y < -.13 if pair=='front' else v.co.y > .13)
    and (v.co.x < -.025 if side=='negative_x' else v.co.x > .025)]
    for pair in ['front','rear'] for side in ['negative_x','positive_x']}
rows = []
for region in regions:
    bone = rig.pose.bones[region+'_lower']
    bone.rotation_mode = 'XYZ'
    bone.rotation_euler.x = math.radians(20)
    points = evaluated()
    rows.append({'probe_bone':bone.name, 'rotation_degrees':20,
        'lower_paw_region_max_displacement_m': {name:max((points[i]-rest[i]).length for i in ids)
                                               for name,ids in regions.items()}})
    bone.rotation_euler.x = 0
report = {'runtime_approved':False,'rig_approved':False,'probes':rows,
    'scope':'Evaluated isolated lower-leg rotation displacements; no visual deformation, gait or collision approval'}
(BASE / 'isolated_limb_probe.json').write_text(json.dumps(report, indent=2),encoding='utf-8')
print(json.dumps(report),flush=True)
