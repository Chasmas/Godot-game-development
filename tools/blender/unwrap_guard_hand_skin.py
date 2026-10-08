"""Dedicated staged hand UVs and ImageGen albedo; never replace runtime rig."""
import bpy, json, os
from pathlib import Path

root=Path(os.environ.get('GUARD_SKIN_OUTPUT','build/guard_hand_unwrap_v26'));root.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(os.environ.get('GUARD_SKIN_SOURCE','build/guard_thumb_restored_v23/guard.glb')).resolve()))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.data.shape_keys)
material=bpy.data.materials.new('GuardHandSkin_ImageGen_v1');material.use_nodes=True
shader=material.node_tree.nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value=.62
texture=material.node_tree.nodes.new('ShaderNodeTexImage')
texture.image=bpy.data.images.load(str(Path('assets/art/materials/characters/guard_hand_skin_v1/albedo.png').resolve()))
texture.interpolation='Linear'
material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
slot=len(body.data.materials);body.data.materials.append(material)
hand_groups={body.vertex_groups[s+'Hand'].index for s in ('Left','Right')}
eligible={v.index for v in body.data.vertices if sum(g.weight for g in v.groups if g.group in hand_groups)>=.99}
selected=[]
for polygon in body.data.polygons:
 polygon.select=all(i in eligible for i in polygon.vertices)
 if polygon.select:polygon.material_index=slot;selected.append(polygon.index)
assert len(selected)>1000
bpy.ops.object.select_all(action='DESELECT');body.select_set(True)
bpy.context.view_layer.objects.active=body
bpy.context.tool_settings.mesh_select_mode=(False,False,True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.uv.smart_project(angle_limit=1.151917,island_margin=.025)
bpy.ops.object.mode_set(mode='OBJECT')
uv_repeat=float(os.environ.get('GUARD_SKIN_UV_REPEAT','1'))
assert 1 <= uv_repeat <= 8
for index in selected:
 for loop_index in body.data.polygons[index].loop_indices:
  body.data.uv_layers.active.data[loop_index].uv *= uv_repeat
texture.image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str((root/'guard_hand_skin_review.blend').resolve()))
bpy.ops.export_scene.gltf(filepath=str((root/'guard.glb').resolve()),export_format='GLB',export_animations=True,export_morph=True)
(root/'review.json').write_text(json.dumps({'approved':False,'selected_hand_faces':len(selected),'uv_repeat':uv_repeat,'material':material.name,'albedo':'assets/art/materials/characters/guard_hand_skin_v1/albedo.png','scope':'Blender staging export only. Re-exported rig animations require isolation before any integration. Wrist material transition, UV distortion, both hand views and motion review pending.'},indent=2))
print('HAND_SKIN_UNWRAP',len(selected))
