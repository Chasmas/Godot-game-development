"""Measure staged Blender furniture against room101 production footprints."""
import bpy,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/room_101_v19/room_101.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
bpy.context.view_layer.update()
placements=[]
for root in bpy.context.scene.objects:
    if '101 placement' not in root.name:continue
    meshes=[o for o in root.children_recursive if o.type=='MESH']
    corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    lo=Vector([min(p[i] for p in corners) for i in range(3)])
    hi=Vector([max(p[i] for p in corners) for i in range(3)])
    centre=(lo+hi)/2
    placements.append({'name':root.name,'centre_pixels':[176+centre.x*16,432-centre.y*16],
        'size_pixels':[(hi.x-lo.x)*16,(hi.y-lo.y)*16],
        'bounds_pixels':[176+lo.x*16,432-hi.y*16,176+hi.x*16,432-lo.y*16]})
overlaps=[]
for i,a in enumerate(placements):
    for b in placements[i+1:]:
        aa=a['bounds_pixels'];bb=b['bounds_pixels']
        intersection=[min(aa[2],bb[2])-max(aa[0],bb[0]),min(aa[3],bb[3])-max(aa[1],bb[1])]
        if min(intersection)>0:overlaps.append({'a':a['name'],'b':b['name'],'overlap_pixels':intersection})
report={'runtime_approved':False,'source':str(source),'scope':'Whole hierarchy visual AABBs, including lamps; not collision geometry',
        'placements':placements,'visual_aabb_overlaps':overlaps}
screen=next(o for o in bpy.context.scene.objects if o.name.startswith('Convex dark CRT'))
normal=(screen.matrix_world.to_3x3()@Vector((0,-1,0))).normalized()
report['screen_facing_blender']=list(normal)
report['screen_centre_blender']=list(screen.matrix_world.translation)
(ROOT/'build/m01_room101_mesh_fit.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
assert len(placements)==5,'Expected bed, TV, chair and two cabinets'
assert not overlaps,'Staged furniture silhouettes must not overlap'
tv=next(p for p in placements if p['name'].startswith('tv_dresser'))
assert abs(tv['size_pixels'][0]-12.8)<.01,'Match production TV visible width'
assert abs(tv['centre_pixels'][0]-200)<.01 and abs(tv['centre_pixels'][1]-440)<.01
assert normal.y<-.99,'User requested screen facing the viewer from north wall'
