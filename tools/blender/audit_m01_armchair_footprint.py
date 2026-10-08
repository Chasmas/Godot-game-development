"""Measure authored chair geometry for its Godot collision contract."""
import bpy,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
directory=root/'assets/art/prerendered/m01_sunset_palms/staging/armchair_runtime_v3'
bpy.ops.wm.open_mainfile(filepath=str(directory/'armchair_runtime_review.blend'))
chair=next(o for o in bpy.context.scene.objects if o.type=='EMPTY' and o.name.startswith('M01 upholstered armchair') and not o.hide_render)
inverse=chair.matrix_world.inverted()
points=[]
graph=bpy.context.evaluated_depsgraph_get()
for child in chair.children_recursive:
    if child.type not in ('MESH','CURVE'): continue
    evaluated=child.evaluated_get(graph)
    mesh=evaluated.to_mesh()
    points.extend(inverse @ evaluated.matrix_world @ v.co for v in mesh.vertices)
    evaluated.to_mesh_clear()
minimum=Vector(tuple(min(p[i] for p in points) for i in range(3)))
maximum=Vector(tuple(max(p[i] for p in points) for i in range(3)))
contract_path=directory/'runtime_contract.json'
contract=json.loads(contract_path.read_text())
contract['collision_footprint_metres']=[maximum.x-minimum.x,maximum.y-minimum.y]
contract['collision_center_metres']=[(maximum.x+minimum.x)*.5,(maximum.y+minimum.y)*.5]
contract['geometry_bounds_metres']={'minimum':list(minimum),'maximum':list(maximum)}
contract_path.write_text(json.dumps(contract,indent=2))
print('ARMCHAIR BLENDER FOOTPRINT',contract['collision_footprint_metres'],contract['collision_center_metres'])
