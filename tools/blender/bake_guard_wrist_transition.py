"""Bake original wrist atlas into dedicated ImageGen hand texture, staging only."""
import bpy,json,os
from pathlib import Path
from mathutils import Vector
root=Path(os.environ.get('GUARD_BLEND_OUTPUT','build/guard_hand_blend_v28'));root.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(os.environ.get('GUARD_BLEND_SOURCE','build/guard_thumb_restored_v23/guard.glb')).resolve()))
original=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys)
old_uv=[tuple(p.uv) for p in original.data.uv_layers.active.data]
bpy.ops.wm.open_mainfile(filepath=str(Path(os.environ.get('GUARD_BLEND_UNWRAP','build/guard_hand_unwrap_v27/guard_hand_skin_review.blend')).resolve()))
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys)
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
assert len(old_uv)==len(body.data.loops)
material=bpy.data.materials['GuardHandSkin_ImageGen_v1']
slot=list(body.data.materials).index(material)
polygons=[p for p in body.data.polygons if p.material_index==slot]
for polygon in polygons:
 for li in polygon.loop_indices:body.data.uv_layers.active.data[li].uv/=4
repaired=[]
if os.environ.get('GUARD_BLEND_REPAIR_SMALL_UV')=='1':
 uv=body.data.uv_layers.active.data
 # Reserve a separate strip for tiny triangles rather than enlarging them
 # over neighboring UV islands. Geometry and skin weights stay unchanged.
 for polygon in polygons:
  for li in polygon.loop_indices:uv[li].uv.y=.2+.8*uv[li].uv.y
 for polygon in polygons:
  assert len(polygon.loop_indices)==3
  a,b,c=[uv[li].uv.copy() for li in polygon.loop_indices]
  area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))*.5*2048**2
  if area>=float(os.environ.get('GUARD_BLEND_MIN_UV_AREA','.5')):continue
  n=len(repaired);x=.005+(n%32)*.03;y=.003+(n//32)*.008
  assert y+.003<.2
  for li,point in zip(polygon.loop_indices,[(x,y),(x+.003,y),(x,y+.003)]):uv[li].uv=point
  repaired.append(polygon.index)
mesh=bpy.data.meshes.new('HandBakeSurface')
mesh.from_pydata([v.co for v in body.data.vertices],[],[tuple(p.vertices) for p in polygons])
mesh.update()
obj=bpy.data.objects.new('HandBakeSurface',mesh);bpy.context.collection.objects.link(obj)
mesh.materials.append(material)
target_uv=mesh.uv_layers.new(name='HandUV');atlas_uv=mesh.uv_layers.new(name='AtlasUV')
blend=mesh.color_attributes.new(name='WristBlend',type='FLOAT_COLOR',domain='CORNER')
frames=[arm.data.bones[s+'Hand'].matrix_local.inverted()@arm.matrix_world.inverted()@body.matrix_world for s in ('Left','Right')]
groups=[body.vertex_groups[s+'Hand'].index for s in ('Left','Right')]
for p,source in zip(mesh.polygons,polygons):
 for li,sli in zip(p.loop_indices,source.loop_indices):
  target_uv.data[li].uv=body.data.uv_layers.active.data[sli].uv
  atlas_uv.data[li].uv=old_uv[sli]
  vertex=body.data.vertices[body.data.loops[sli].vertex_index]
  side=max(range(2),key=lambda s:next((g.weight for g in vertex.groups if g.group==groups[s]),0))
  y=(frames[side]@vertex.co).y
  t=max(0,min(1,(y-1)/3));t=t*t*(3-2*t)
  blend.data[li].color=(t,t,t,1)
mesh.uv_layers.active=target_uv
nodes=material.node_tree.nodes;links=material.node_tree.links
generated=next(n for n in nodes if n.type=='TEX_IMAGE')
uv=nodes.new('ShaderNodeUVMap');uv.uv_map='HandUV'
mapping=nodes.new('ShaderNodeMapping');mapping.inputs['Scale'].default_value=(4,4,4)
links.new(uv.outputs['UV'],mapping.inputs['Vector']);links.new(mapping.outputs['Vector'],generated.inputs['Vector'])
atlas=nodes.new('ShaderNodeTexImage')
atlas.image=next(n.image for n in body.data.materials[0].node_tree.nodes if n.type=='TEX_IMAGE')
old=nodes.new('ShaderNodeUVMap');old.uv_map='AtlasUV';links.new(old.outputs['UV'],atlas.inputs['Vector'])
factor=nodes.new('ShaderNodeVertexColor');factor.layer_name='WristBlend'
mix=nodes.new('ShaderNodeMixRGB');links.new(factor.outputs['Color'],mix.inputs[0]);links.new(atlas.outputs['Color'],mix.inputs[1]);links.new(generated.outputs['Color'],mix.inputs[2])
emission=nodes.new('ShaderNodeEmission');links.new(mix.outputs['Color'],emission.inputs['Color'])
output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL');links.new(emission.outputs[0],output.inputs['Surface'])
resolution=int(os.environ.get('GUARD_BLEND_RESOLUTION','1024'))
assert resolution in (1024,2048)
baked=bpy.data.images.new('GuardHandWristBlend',resolution,resolution,alpha=False)
destination=nodes.new('ShaderNodeTexImage');destination.image=baked;nodes.active=destination
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
bpy.context.scene.render.engine='CYCLES';bpy.context.scene.cycles.samples=1
bpy.context.scene.render.bake.margin=16
bpy.ops.object.bake(type='EMIT')
baked.filepath_raw=str((root/'hand_albedo.png').resolve());baked.file_format='PNG';baked.save();baked.pack()
shader=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
links.new(destination.outputs['Color'],shader.inputs['Base Color']);links.new(shader.outputs[0],output.inputs['Surface'])
for node in list(nodes):
 if node not in (destination,shader,output):nodes.remove(node)
bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str((root/'guard_hand_skin_review.blend').resolve()))
bpy.ops.export_scene.gltf(filepath=str((root/'guard.glb').resolve()),export_format='GLB',export_animations=True,export_morph=True)
(root/'review.json').write_text(json.dumps({'approved':False,'hand_faces':len(polygons),'repaired_small_uv_polygons':repaired,'scope':'Blender emission bake of smooth 1-4 cm wrist transition; source atlas at seam, ImageGen skin distally. Body and animation isolation plus GPU review pending.'},indent=2))
