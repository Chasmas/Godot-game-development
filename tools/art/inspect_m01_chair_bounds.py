import bpy,json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(root/'assets/art/prerendered/m01_sunset_palms/staging/room_101_v16/room_101.blend'))
chair=next(o for o in bpy.context.scene.objects if 'armchair_runtime_review101 placement' in o.name)
deps=bpy.context.evaluated_depsgraph_get()
report=[]
for obj in chair.children_recursive:
    if obj.type not in {'MESH','CURVE'}:continue
    evaluated=obj.evaluated_get(deps)
    mesh=evaluated.to_mesh()
    points=[evaluated.matrix_world@v.co for v in mesh.vertices]
    report.append({'name':obj.name,'type':obj.type,'min':[min(p[i] for p in points) for i in range(3)],'max':[max(p[i] for p in points) for i in range(3)]})
    evaluated.to_mesh_clear()
(root/'build/m01_chair_evaluated_bounds.json').write_text(json.dumps(report,indent=2))
print(json.dumps({'combined_min':[min(p['min'][i] for p in report) for i in range(3)],'combined_max':[max(p['max'][i] for p in report) for i in range(3)]}))
