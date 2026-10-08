import bpy,os
out=os.path.abspath('build/idle_consumables_candidate')
bpy.ops.wm.open_mainfile(filepath=os.path.join(out,'donut.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
obj=bpy.data.objects['baked dough'];mat=obj.data.materials[0];nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
textures={}
for kind in ['DIFFUSE','NORMAL']:
 image=bpy.data.images.new('dough_'+kind.lower(),width=512,height=512)
 if kind=='NORMAL':image.colorspace_settings.name='Non-Color'
 node=nt.nodes.new('ShaderNodeTexImage');node.image=image;nt.nodes.active=node
 scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True;scene.render.bake.margin=8
 bpy.ops.object.bake(type=kind)
 image.filepath_raw=os.path.join(out,'dough_'+kind.lower()+'.png');image.file_format='PNG';image.save();textures[kind]=node
nt.links.new(textures['DIFFUSE'].outputs['Color'],bs.inputs['Base Color'])
normal=nt.nodes.new('ShaderNodeNormalMap');nt.links.new(textures['NORMAL'].outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs['Normal'],bs.inputs['Normal'])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=os.path.join(out,'donut.glb'),export_format='GLB',use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,'donut_textured.blend'))
print('CONSUMABLE TEXTURES BAKED')
