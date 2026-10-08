import bpy,bmesh,math,json,statistics
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
from mathutils.geometry import closest_point_on_tri,barycentric_transform
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path('assets/art/Artwork/3d/cass/rig_newhair.glb').resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and 'LeftHand' in o.vertex_groups)
skin_samples=[]
image_cache={}
uv=body.data.uv_layers.active
uv_name=uv.name
for polygon in body.data.polygons:
 material_source=body.data.materials[polygon.material_index]
 images=[n.image for n in material_source.node_tree.nodes if n.type=='TEX_IMAGE' and n.image] if material_source.use_nodes else []
 if not images or uv is None:continue
 image=images[0];width,height=image.size;
 if image.name not in image_cache:image_cache[image.name]=image.pixels[:]
 pixels=image_cache[image.name]
 for loop_index in polygon.loop_indices:
  vertex=body.data.vertices[body.data.loops[loop_index].vertex_index]
  for name in ['LeftHand','RightHand']:
   group=body.vertex_groups[name].index
   weight=next((g.weight for g in vertex.groups if g.group==group),0)
   frame=arm.data.bones[name].matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world
   if weight<.8 or not 2<(frame@vertex.co).y<6:continue
   coord=uv.data[loop_index].uv;x=min(width-1,int(coord.x%1*width));y=min(height-1,int(coord.y%1*height))
   rgba=pixels[(y*width+x)*4:(y*width+x)*4+4]
   if rgba[3]>.5:skin_samples.append(rgba[:3])
skin_colour=tuple(statistics.median(c[i] for c in skin_samples) for i in range(3)) if skin_samples else (.57,.28,.17)
# Preserve original textured hand samples before removing damaged geometry.
hand_uv_samples=[];material_votes={}
source_triangles=[]
for polygon in body.data.polygons:
 eligible=any(any(g.weight>.5 and body.vertex_groups[g.group].name in ['LeftHand','RightHand'] for g in body.data.vertices[body.data.loops[li].vertex_index].groups) for li in polygon.loop_indices)
 skin_only=all(any(next((g.weight for g in vertex.groups if g.group==body.vertex_groups[name].index),0)>.5 and (arm.data.bones[name].matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world@vertex.co).y>1 for name in ['LeftHand','RightHand']) for vertex in [body.data.vertices[body.data.loops[li].vertex_index] for li in polygon.loop_indices])
 if eligible and skin_only and len(polygon.loop_indices)==3:
  source_triangles.append(([body.data.vertices[body.data.loops[li].vertex_index].co.copy() for li in polygon.loop_indices],[uv.data[li].uv.copy() for li in polygon.loop_indices]))
 for loop_index in polygon.loop_indices:
  vertex=body.data.vertices[body.data.loops[loop_index].vertex_index]
  if not any(g.weight>.5 and body.vertex_groups[g.group].name in ['LeftHand','RightHand'] for g in vertex.groups):continue
  hand_uv_samples.append((vertex.co.copy(),uv.data[loop_index].uv.copy()))
  material_votes[polygon.material_index]=material_votes.get(polygon.material_index,0)+1
skin_material=body.data.materials[max(material_votes,key=material_votes.get)]
uv_tree=KDTree(len(hand_uv_samples))
for i,(point,coord) in enumerate(hand_uv_samples):uv_tree.insert(point,i)
uv_tree.balance()
triangle_tree=KDTree(len(source_triangles))
for i,(points,coords) in enumerate(source_triangles):triangle_tree.insert(sum(points,Vector())/3,i)
triangle_tree.balance()
bm=bmesh.new();bm.from_mesh(body.data);deform=bm.verts.layers.deform.active
indices=[body.vertex_groups[n].index for n in ['LeftHand','RightHand']]
frames=[arm.data.bones[n].matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world for n in ['LeftHand','RightHand']]
selected=set(v for v in bm.verts if any(v[deform].get(g,0)>.05 and (frame@v.co).y>=-.6 for g,frame in zip(indices,frames)))
faces=[f for f in bm.faces if any(v in selected for v in f.verts)]
bmesh.ops.delete(bm,geom=faces,context='FACES')
bm.to_mesh(body.data);bm.free()
material=bpy.data.materials.new('AuthoredHandSkin');material.diffuse_color=(*skin_colour,1);material.use_nodes=True
node=material.node_tree.nodes.get('Principled BSDF');node.inputs['Base Color'].default_value=(*skin_colour,1);node.inputs['Roughness'].default_value=.58
parts=[];report=[]
for side in ['Left','Right']:
 verts=[];faces=[];sign=-1 if side=='Left' else 1
 def tube(centres,radii,sides=12):
  start=len(verts)
  for i,c in enumerate(centres):
   tangent=(centres[min(i+1,len(centres)-1)]-centres[max(0,i-1)]).normalized()
   across=Vector((1,0,0));across=(across-tangent*across.dot(tangent)).normalized()
   if across.length<.1:across=tangent.cross(Vector((0,0,1))).normalized()
   other=tangent.cross(across).normalized()
   for j in range(sides):
    a=j*math.tau/sides;verts.append(c+across*math.cos(a)*radii[i][0]+other*math.sin(a)*radii[i][1])
  for i in range(len(centres)-1):
   for j in range(sides):
    a=start+i*sides+j;b=start+i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
  faces.append(tuple(start+j for j in reversed(range(sides))))
  faces.append(tuple(start+(len(centres)-1)*sides+j for j in range(sides)))
 tube([Vector((0,y,0)) for y in [-2.5,0,2,4,6,7]],[(1.9,1.1),(1.9,1.1),(2.8,1.4),(3,1.5),(2.7,1.25),(2.3,1)])
 for index,x in enumerate([-2.05,-.7,.7,2.05]):
  length=[6.7,8,7.3,5.7][index]
  centres=[];radii=[]
  for i in range(13):
   t=i/12;angle=t*(2.6 if index<3 else 2.35);radius=2.6 if side=="Left" else 2.8
   centres.append(Vector((x,6+radius*math.sin(angle),(3.9 if side=="Left" else 4.1)-radius*math.cos(angle))))
   r=.65*(1-.35*t);radii.append((r,r*.82))
  tube(centres,radii)
 tube([Vector((sign*x,y,z)) for x,y,z in [(2.3,2.2,-.5),(3.2,3.1,-.3),(3.6,4.1,.2),(3.3,5.1,1),(2.6,5.8,1.7)]],[(.85,.7),(.8,.65),(.7,.6),(.6,.5),(.45,.4)])
 frame=body.matrix_world.inverted()@arm.matrix_world@arm.data.bones[side+'Hand'].matrix_local
 mesh=bpy.data.meshes.new(side+'AuthoredGrip');mesh.from_pydata([frame@v for v in verts],[],faces);mesh.update()
 obj=bpy.data.objects.new(side+'AuthoredGrip',mesh);bpy.context.collection.objects.link(obj);obj.matrix_world=body.matrix_world
 obj.data.materials.append(skin_material)
 layer=mesh.uv_layers.new(name=uv_name)
 for polygon in mesh.polygons:
  centre=sum((mesh.vertices[i].co for i in polygon.vertices),Vector())/len(polygon.vertices)
  _,nearest,_=triangle_tree.find(centre)
  points,coords=source_triangles[nearest]
  mapped=[Vector((c.x,c.y,0)) for c in coords]
  for loop_index in polygon.loop_indices:
   point=mesh.vertices[mesh.loops[loop_index].vertex_index].co
   projected=closest_point_on_tri(point,*points)
   transferred=barycentric_transform(projected,*points,*mapped)
   layer.data[loop_index].uv=(transferred.x,transferred.y)
 group=obj.vertex_groups.new(name=side+'Hand');group.add(list(range(len(verts))),1,'REPLACE')
 for polygon in mesh.polygons:polygon.use_smooth=True
 parts.append(obj)
 check=bmesh.new();check.from_mesh(mesh);report.append({'side':side,'vertices':len(verts),'boundary_edges':sum(e.is_boundary for e in check.edges)});check.free()
bpy.ops.object.select_all(action='DESELECT');body.select_set(True)
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
bpy.ops.export_scene.gltf(filepath=str(Path('build/chainsaw_pose_candidate/cass_remodeled_hands.glb').resolve()),export_format='GLB',export_animations=False)
Path('build/chainsaw_pose_candidate/remodeled_hand_report.json').write_text(json.dumps({'approved':False,'parts':report,'skin_colour':skin_colour,'source_skin_samples':len(skin_samples),'uv_transfer_samples':len(hand_uv_samples),'skin_material':skin_material.name,'remaining':'Visual validation, skin material matching, wrist join and contact validation.'},indent=2))

