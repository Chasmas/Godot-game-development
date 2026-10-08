"""Stage distinct native fingers using existing hand authoring, never ship automatically."""
from pathlib import Path
import os

out=Path('build/guard_remodeled_hands')
out.mkdir(parents=True,exist_ok=True)
source=Path('tools/blender/model_chainsaw_hands.py').read_text()
old='assets/art/Artwork/3d/cass/rig_newhair.glb'
assert source.count(old)==1
source=source.replace(old,'assets/art/cast3d_rt/guard/guard.glb')
source=source.replace('skin_samples=[]', '''# Preserve authored split normals on every untouched face through BMesh.
def normal_key(mesh,polygon):
 return tuple(sorted(tuple(round(float(x),5) for x in mesh.vertices[mesh.loops[li].vertex_index].co) for li in polygon.loop_indices))
original_normals={}
for polygon in body.data.polygons:
 original_normals[normal_key(body.data,polygon)]={tuple(round(float(x),5) for x in body.data.vertices[body.data.loops[li].vertex_index].co):body.data.corner_normals[li].vector.copy() for li in polygon.loop_indices}
skin_samples=[]''',1)
if os.environ.get('GUARD_PISTOL_ANATOMY') == '1':
 # Index belongs beside the thumb, above the other three gripping fingers.
 # Keep it along the side of the receiver while aiming, outside the trigger
 # guard. Move complete tube rings rather than projecting individual points,
 # which pinches their cross sections against gun corners.
 source=source.replace("for index,x in enumerate([-2.05,-.7,.7,2.05]):",
                       "for index,x in enumerate([sign*2.05,sign*.7,-sign*.7,-sign*2.05]):")
 old_centre='centres.append(Vector((x,6+radius*math.sin(angle),(3.9 if side=="Left" else 4.1)-radius*math.cos(angle))))'
 assert source.count(old_centre)==1
 source=source.replace(old_centre,'''if index==0:
    # Pistol up is hand X (mirrored on the left), not hand Z.
    # Lift the index from its palm root to the receiver's side, keeping
    # its distal surface outside the 17 mm side panel.
    lift=min(1.0,t/.45);lift=lift*lift*(3-2*lift)
    centres.append(Vector((sign*(2.05+2.35*lift),6+5.5*t,1.2+.12*math.sin(math.pi*t))))
   else:
    radius=3.05
    if os.environ.get('GUARD_PISTOL_LOWER_GRASP') == '1':
     # Seat the three bent phalanges below the guard; keep their knuckle
     # roots on the original palm and blend whole cross-section rings.
     bend=min(1.0,t/.33);bend=bend*bend*(3-2*bend)
     x=x*(1-bend)+sign*[0,-3.0,-4.2,-5.4][index]*bend
    centres.append(Vector((x,6+radius*math.sin(angle),3.9-radius*math.cos(angle))))''')
 source=source.replace('import bpy,bmesh,math,json,statistics',
                       'import bpy,bmesh,math,json,statistics,os')
source=source.replace(' verts=[];faces=[];sign=', ' verts=[];open_verts=[];faces=[];sign=',1)
if os.environ.get('GUARD_PISTOL_THUMB_WRAP') == '1':
 old_thumb='[(2.3,2.2,-.5),(3.2,3.1,-.3),(3.6,4.1,.2),(3.3,5.1,1),(2.6,5.8,1.7)]'
 assert source.count(old_thumb)==1
 # Carry the opposed thumb past the palm towards the grip side, keeping
 # its broad base while tapering the final phalanx.
 source=source.replace(old_thumb,'[(1.7,3,0),(2.5,4,.1),(3,5,.5),(3.2,5.8,.9),(2.9,6.6,1.5)]')
source=source.replace(' def tube(centres,radii,sides=12):', ''' def tube(centres,radii,sides=12):
  if os.environ.get('GUARD_PISTOL_THUMB_WRAP') == '1' and len(centres)==5:
   # Smooth the opposed thumb along its authored phalanges. The broad
   # root is embedded in the palm so the visible transition is tapered.
   points=[];widths=[]
   for segment in range(4):
    p0=centres[max(0,segment-1)];p1=centres[segment]
    p2=centres[segment+1];p3=centres[min(4,segment+2)]
    for sample in range(4):
     t=sample/4
     points.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
     widths.append(tuple(a*(1-t)+b*t for a,b in zip(radii[segment],radii[segment+1])))
   centres=points+[centres[-1]];radii=widths+[radii[-1]]
  if os.environ.get('GUARD_PISTOL_UPRIGHT') == '1' and len(centres) in (13,5):
   # Author upright finger/thumb paths before constructing their rings.
   # Preserve the palm/wrist rings and their normals in both morph states.
   centres=[Vector((-c.x,c.y,c.z)) for c in centres]
''')
# The existing tube author emits stable rings. Preserve their indices and
# author a straight resting finger at every matching vertex.
needle='  for i in range(len(centres)-1):'
assert source.count(needle)==1
source=source.replace(needle,'''  for i,c in enumerate(centres):
   for j in range(sides):
    if len(centres)==13:
     t=i/12;a=j*math.tau/sides
     open_verts.append(Vector((centres[0].x+math.cos(a)*radii[i][0],6+length*t,-math.sin(a)*radii[i][1])))
    else:open_verts.append(verts[start+i*sides+j].copy())
''' + needle)
needle=' obj.data.materials.append(skin_material)'
assert source.count(needle)==1
source=source.replace(needle,''' assert len(open_verts)==len(verts)
 for vertex,point in zip(mesh.vertices,open_verts):vertex.co=frame@point
 obj.shape_key_add(name='Basis')
 grasp=obj.shape_key_add(name='WeaponGrip')
 for point,key in zip(verts,grasp.data):
  authored=point.copy()
  key.co=frame@authored
 grasp.value=0.0
''' + needle)
needle="bpy.ops.object.select_all(action='DESELECT');body.select_set(True)"
assert source.count(needle)==1
source=source.replace(needle,"body.shape_key_add(name='Basis')\nbody.shape_key_add(name='WeaponGrip')\n"+needle)
filter_needle='triangle_tree=KDTree(len(source_triangles))'
assert source.count(filter_needle)==1
source=source.replace(filter_needle,'''skin_images=[n.image for n in skin_material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image]
assert skin_images
skin_image=skin_images[0];width,height=skin_image.size
skin_pixels=skin_image.pixels[:]
def is_skin_uv(coord):
 x=min(width-1,int(coord.x%1*width));y=min(height-1,int(coord.y%1*height))
 r,g,b=skin_pixels[(y*width+x)*4:(y*width+x)*4+3]
 return r>.16 and r>g*.9 and r>b*1.12
before=len(source_triangles)
source_triangles=[(points,coords) for points,coords in source_triangles if all(is_skin_uv(coord) for coord in coords)]
assert len(source_triangles)>20
print('Skin-only UV triangles',len(source_triangles),'of',before)
''' + filter_needle)
source=source.replace('from mathutils import Vector',
                      'from mathutils import Vector\nfrom mathutils.bvhtree import BVHTree')
needle='triangle_tree.balance()'
assert source.count(needle)==1
source=source.replace(needle,needle+'''
surface_vertices=[point for points,coords in source_triangles for point in points]
surface_faces=[(i*3,i*3+1,i*3+2) for i in range(len(source_triangles))]
skin_surface=BVHTree.FromPolygons(surface_vertices,surface_faces,all_triangles=True)
uv_components=[]
if os.environ.get('GUARD_HAND_COHERENT_UV') == '1':
 owners={};neighbors=[set() for _ in source_triangles]
 for i,(points,coords) in enumerate(source_triangles):
  for coord in coords:
   key=tuple(round(float(v),6) for v in coord)
   for other in owners.get(key,[]):neighbors[i].add(other);neighbors[other].add(i)
   owners.setdefault(key,[]).append(i)
 unseen=set(range(len(source_triangles)))
 while unseen:
  todo=[unseen.pop()];component=[]
  while todo:
   i=todo.pop();component.append(i)
   more=neighbors[i]&unseen;unseen-=more;todo.extend(more)
  if len(component)>=5:
   tris=[source_triangles[i] for i in component]
   vertices=[p for points,coords in tris for p in points]
   tree=BVHTree.FromPolygons(vertices,[(i*3,i*3+1,i*3+2) for i in range(len(tris))],all_triangles=True)
   uv_components.append((tris,tree))
 assert uv_components
''')
start=source.index('  _,nearest,_=triangle_tree.find(centre)')
end=source.index(" group=obj.vertex_groups.new(name=side+'Hand')",start)
source=source[:start]+'''  active_triangles=source_triangles;active_surface=skin_surface
  if os.environ.get('GUARD_HAND_COHERENT_UV') == '1':
   if 'coherent_surface' not in obj:
    probe=sum((v.co for v in mesh.vertices),Vector())/len(mesh.vertices)
    obj['coherent_surface']=min(range(len(uv_components)),key=lambda i:uv_components[i][1].find_nearest(probe)[3])
   active_triangles,active_surface=uv_components[obj['coherent_surface']]
  projected,normal,nearest,distance=active_surface.find_nearest(centre)
  assert nearest is not None
  points,coords=active_triangles[nearest]
  mapped=[Vector((c.x,c.y,0)) for c in coords]
  for loop_index in polygon.loop_indices:
   point=mesh.vertices[mesh.loops[loop_index].vertex_index].co
   if os.environ.get('GUARD_HAND_VERTEX_UV') == '1' or os.environ.get('GUARD_HAND_COHERENT_UV') == '1':
    # Experimental mapping: rejected v24 crosses unrelated atlas islands
    # when interpolated across a polygon; never enable for shipped assets.
    projected,normal,nearest,distance=active_surface.find_nearest(point)
    assert nearest is not None
    points,coords=active_triangles[nearest]
    mapped=[Vector((c.x,c.y,0)) for c in coords]
   projected=closest_point_on_tri(point,*points)
   transferred=barycentric_transform(projected,*points,*mapped)
   layer.data[loop_index].uv=(transferred.x,transferred.y)
''' + source[end:]
start=source.index('selected=set(v for v in bm.verts')
end=source.index('bm.to_mesh(body.data);bm.free()',start)
source=source[:start]+'''wrist_profiles=[]
wrist_rings=[]
wrist_weights=[]
for group, inverse in zip(indices,frames):
 region=set(v for v in bm.verts if v[deform].get(group,0)>.05 and (inverse@v.co).y>-5)
 faces=set(f for f in bm.faces if any(v in region for v in f.verts))
 edges=set(e for f in faces for e in f.edges)
 vertices=set(v for f in faces for v in f.verts)
 plane_co=inverse.inverted()@Vector((0,1,0))
 plane_no=(inverse.to_3x3().transposed()@Vector((0,1,0))).normalized()
 bmesh.ops.bisect_plane(bm,geom=list(faces|edges|vertices),dist=.0001,
                       plane_co=plane_co,plane_no=plane_no,clear_outer=True,clear_inner=False)
 points=[inverse@v.co for v in bm.verts if v[deform].get(group,0)>.05 and abs((inverse@v.co).y-1)<.002]
 assert len(points)>6, 'Wrist cut produced no usable boundary'
 wrist_profiles.append((max(abs(p.x) for p in points),max(abs(p.z) for p in points)))
 unique={tuple(round(float(a),4) for a in p):p.copy() for p in points}
 ring=sorted(unique.values(),key=lambda p:math.atan2(-p.z,p.x))
 wrist_rings.append(ring)
 ring_weights=[]
 for point in ring:
  vertex=min(bm.verts,key=lambda v:((inverse@v.co)-point).length_squared)
  ring_weights.append(dict(vertex[deform]))
 wrist_weights.append(ring_weights)
orphans=[v for v in bm.verts if not v.link_faces]
if orphans:bmesh.ops.delete(bm,geom=orphans,context='VERTS')
''' + source[end:]
old_palm="tube([Vector((0,y,0)) for y in [-2.5,0,2,4,6,7]],[(1.9,1.1),(1.9,1.1),(2.8,1.4),(3,1.5),(2.7,1.25),(2.3,1)])"
assert source.count(old_palm)==1
source=source.replace(old_palm,"rx,rz=wrist_profiles[0 if side=='Left' else 1]\n tube([Vector((0,y,0)) for y in [1,2,3,4,6,7]],[(rx,rz),(rx*.9,rz*.9),(2.8,1.4),(3,1.5),(2.7,1.25),(2.3,1)],sides=len(wrist_rings[0 if side=='Left' else 1]))")
old_vertex='a=j*math.tau/sides;verts.append(c+across*math.cos(a)*radii[i][0]+other*math.sin(a)*radii[i][1])'
assert source.count(old_vertex)==1
source=source.replace(old_vertex,'''if len(centres)==6:
     root=wrist_rings[0 if side=='Left' else 1][j]
     a=math.atan2(-root.z,root.x)
     point=c+across*math.cos(a)*radii[i][0]+other*math.sin(a)*radii[i][1]
     if i==0:point=root.copy()
     elif i==1:point=Vector((root.x*.95,c.y,root.z*.95))
     verts.append(point)
    else:
     a=j*math.tau/sides;verts.append(c+across*math.cos(a)*radii[i][0]+other*math.sin(a)*radii[i][1])''')
source=source.replace('faces.append(tuple(start+j for j in reversed(range(sides))))',
                      'if len(centres)!=6:faces.append(tuple(start+j for j in reversed(range(sides))))')
needle="bpy.context.view_layer.objects.active=body;bpy.ops.object.join()"
assert source.count(needle)==1
source=source.replace(needle,needle+'''
joined=bmesh.new();joined.from_mesh(body.data)
layer=joined.verts.layers.deform.active
seam=[]
for vertex in joined.verts:
 for name in ('LeftHand','RightHand'):
  index=body.vertex_groups[name].index
  inverse=arm.data.bones[name].matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world
  if vertex[layer].get(index,0)>.05 and abs((inverse@vertex.co).y-1)<.003:
   seam.append(vertex);break
bmesh.ops.remove_doubles(joined,verts=seam,dist=.002)
for side_index,name in enumerate(('LeftHand','RightHand')):
 index=body.vertex_groups[name].index
 inverse=arm.data.bones[name].matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world
 for vertex in joined.verts:
  point=inverse@vertex.co
  forearm=body.vertex_groups[name.replace('Hand','ForeArm')].index
  if vertex[layer].get(index,0)+vertex[layer].get(forearm,0)<.95 or not -5<=point.y<=3.001:continue
  nearest=min(range(len(wrist_rings[side_index])),key=lambda i:(Vector((point.x,1,point.z))-wrist_rings[side_index][i]).length_squared)
  # Extend rotation support onto the distal forearm, ending at the cut
  # ring. Each cross-section uses one blend, avoiding uneven seam shear.
  blend=max(0,min(1,(point.y+5)/6));blend=blend*blend*(3-2*blend)
  weights={group:weight*(1-blend) for group,weight in dict(vertex[layer]).items()}
  weights[index]=weights.get(index,0)+blend
  total=sum(weights.values());vertex[layer].clear()
  for group,weight in weights.items():
   if weight>1e-6:vertex[layer][group]=weight/total
bmesh.ops.recalc_face_normals(joined,faces=list(joined.faces))
hand_groups={body.vertex_groups[n].index for n in ('LeftHand','RightHand')}
for face in joined.faces:
 if any(sum(vertex[layer].get(index,0) for index in hand_groups)>.5 for vertex in face.verts):
  face.smooth=True
joined.to_mesh(body.data);joined.free()
body.data.update()
split_normals=[normal.vector.copy() for normal in body.data.corner_normals]
restored_faces=0
for polygon in body.data.polygons:
 normals=original_normals.get(normal_key(body.data,polygon))
 if normals is None:continue
 # Keep smooth hand normals on authored or adjacent wrist faces only.
 if any(any(body.vertex_groups[g.group].name in ('LeftHand','RightHand','LeftForeArm','RightForeArm') and g.weight>.001 for g in body.data.vertices[body.data.loops[li].vertex_index].groups) for li in polygon.loop_indices):continue
 for li in polygon.loop_indices:
  position=tuple(round(float(x),5) for x in body.data.vertices[body.data.loops[li].vertex_index].co)
  split_normals[li]=normals[position]
 restored_faces+=1
body.data.normals_split_custom_set(split_normals)
print('Restored untouched custom-normal faces',restored_faces)
for key in body.data.shape_keys.key_blocks:
 if key.name!='Basis':key.value=0.0
''')
source=source.replace("skin_material=body.data.materials[max(material_votes,key=material_votes.get)]",
                      "skin_material=body.data.materials[max(material_votes,key=material_votes.get)]\nsource_skin_material=skin_material")
# Use the source textured shader rather than the flat sampling fallback.
source=source.replace('obj.data.materials.append(skin_material)',
                      'obj.data.materials.append(source_skin_material)')
source=source.replace('build/chainsaw_pose_candidate/cass_remodeled_hands.glb',
                      'build/guard_remodeled_hands/guard.glb')
source=source.replace('build/chainsaw_pose_candidate/remodeled_hand_report.json',
                      'build/guard_remodeled_hands/report.json')
destination=os.environ.get('GUARD_HAND_OUTPUT','build/guard_remodeled_hands')
Path(destination).mkdir(parents=True,exist_ok=True)
source=source.replace('build/guard_remodeled_hands/guard.glb',destination+'/guard.glb')
source=source.replace('build/guard_remodeled_hands/report.json',destination+'/report.json')
exec(compile(source,'tools/blender/model_chainsaw_hands.py','exec'))
