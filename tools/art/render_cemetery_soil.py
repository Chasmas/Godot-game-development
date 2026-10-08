"""Blender-authored periodic cemetery soil, neutral albedo for Godot lighting."""
from pathlib import Path
import bpy, math, random
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(1988)
ma=bpy.data.materials.new('damp cemetery earth');ma.use_nodes=True
n=ma.node_tree.nodes;l=ma.node_tree.links;n.clear()
out=n.new('ShaderNodeOutputMaterial');em=n.new('ShaderNodeEmission');l.new(em.outputs[0],out.inputs[0])
tc=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(tc.outputs['Generated'],sep.inputs[0])
combine=n.new('ShaderNodeCombineXYZ')
for axis,socket in [('X','X'),('Y','Y')]:
 mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=math.tau;l.new(sep.outputs[axis],mul.inputs[0])
 cos=n.new('ShaderNodeMath');cos.operation='COSINE';l.new(mul.outputs[0],cos.inputs[0]);l.new(cos.outputs[0],combine.inputs[socket])
sx=n.new('ShaderNodeMath');sx.operation='ADD';l.new(sep.outputs['X'],sx.inputs[0]);l.new(sep.outputs['Y'],sx.inputs[1])
mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=math.tau;l.new(sx.outputs[0],mul.inputs[0])
sin=n.new('ShaderNodeMath');sin.operation='SINE';l.new(mul.outputs[0],sin.inputs[0]);l.new(sin.outputs[0],combine.inputs['Z'])
noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=7;noise.inputs['Detail'].default_value=6;l.new(combine.outputs[0],noise.inputs['Vector'])
ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.065,.049,.032,1);ramp.color_ramp.elements[1].color=(.105,.081,.052,1)
l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],em.inputs[0])
bpy.ops.mesh.primitive_plane_add(size=2);bpy.context.object.data.materials.append(ma)
def flatmat(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Roughness'].default_value=.95;return m
rock=flatmat('small damp stones',(.12,.13,.11));leaf=flatmat('decayed leaves',(.14,.085,.03))
for i in range(90):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(rng.uniform(-.94,.94),rng.uniform(-.94,.94),.003))
 o=bpy.context.object;s=rng.uniform(.004,.013);o.scale=(s,s*rng.uniform(.6,1.5),s*.3);o.rotation_euler.z=rng.random()*math.tau;o.data.materials.append(rock if i%3 else leaf)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32;sc.render.resolution_x=512;sc.render.resolution_y=512;sc.render.resolution_percentage=100
sc.world=bpy.data.worlds.new('neutral soil lighting');sc.world.color=(.6,.6,.6)
bpy.ops.object.light_add(type='AREA',location=(0,0,4));bpy.context.object.data.energy=250;bpy.context.object.data.size=5
bpy.ops.object.camera_add(location=(0,0,4));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=2;sc.camera=cam
sc.view_settings.view_transform='Standard'
outdir=ROOT/'assets/art/floors';outdir.mkdir(parents=True,exist_ok=True)
sc.render.filepath=str(outdir/'cemetery_soil.png')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'build/cemetery_prop_review/cemetery_soil.blend'));bpy.ops.render.render(write_still=True)
