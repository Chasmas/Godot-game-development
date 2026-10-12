"""Replace the undersized staged cabinet with production's authored source."""
from pathlib import Path
import bpy,json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/art/prerendered/m01_sunset_palms/staging'
OUT=BASE/'room_101_v21';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'room_101_v20/room_101.blend'))
old=next(o for o in bpy.context.scene.objects if o.name.startswith('tv_dresser101 placement'))
for o in list(old.children_recursive)+[old]:bpy.data.objects.remove(o,do_unlink=True)
with bpy.data.libraries.load(str(BASE/'tv_dresser_family_v1/tv_dresser.blend'),link=False) as (src,dst):
    dst.objects=src.objects
objects=[o for o in dst.objects if o and o.type not in {'CAMERA','LIGHT'}]
root=bpy.data.objects.new('tv_dresser101 placement',None);bpy.context.collection.objects.link(root)
for o in objects:
    bpy.context.collection.objects.link(o)
    if o.parent not in objects:o.parent=root
bpy.context.view_layer.update()
def bounds():
    points=[];deps=bpy.context.evaluated_depsgraph_get()
    for o in objects:
        if o.type!='MESH' or o.hide_render:continue
        evaluated=o.evaluated_get(deps);mesh=evaluated.to_mesh()
        points.extend(evaluated.matrix_world@v.co for v in mesh.vertices)
        evaluated.to_mesh_clear()
    return Vector([min(p[i] for p in points) for i in range(3)]),Vector([max(p[i] for p in points) for i in range(3)])
lo,hi=bounds()
contract=json.loads((ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/tv_dresser_v1/runtime_contract.json').read_text())
expected=contract['footprint_metres']
print('CABINET SOURCE BOUNDS',list(lo),list(hi),'EXPECTED',expected,flush=True)
root.scale*=expected[0]/(hi.x-lo.x);bpy.context.view_layer.update();lo,hi=bounds()
assert abs(hi.y-lo.y-(expected[1]+.046))<.005,'Authored drawer pulls extend .046m past cabinet footprint'
# Source cabinet/top is centred at local XY zero. Do not recentre using handles.
root.location=Vector((1.5,-.5,-lo.z))
bpy.context.view_layer.update();lo,hi=bounds()
report={'runtime_approved':False,'source':'room_101_v20','cabinet_source':'tv_dresser_family_v1/tv_dresser.blend','collision_centre_pixels':[200,440],'visual_aabb_centre_pixels':[176+(lo.x+hi.x)*8,432-(lo.y+hi.y)*8],'size_pixels':[(hi.x-lo.x)*16,(hi.y-lo.y)*16],'production_size_pixels':[v*16 for v in expected],'drawer_pull_overhang_metres':.046,'height_metres':hi.z-lo.z,'pending':['Full-map art/camera integration','Whole room visual quality','Actor depth visibility']}
assert abs(report['height_metres']-contract['height_metres'])<.02
(OUT/'review.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'room_101.blend'))
scene=bpy.context.scene;scene.cycles.samples=24
for o in scene.objects:
    if o.name.startswith(('101 south wall','101 wall above window','101 entrance lintel')):o.hide_render=True
scene.render.filepath=str(OUT/'room_101_cutaway.png');bpy.ops.render.render(write_still=True)
print('M01 ROOM101 CABINET ALIGNED',json.dumps(report))
