"""Build and render the rare chainsaw from actual bevelled, textured geometry."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'build/chainsaw_review';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color,metal=0,rough=.45):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 noise=m.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=130
 bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.13;bump.inputs['Distance'].default_value=.002;m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal']);return m
orange=mat('Worn safety orange',(.65,.12,.018));black=mat('Rubber grip',(.012,.017,.022));steel=mat('Oiled steel',(.25,.29,.32),.8,.27);dark=mat('Chain steel',(.035,.045,.052),.75);cream=mat('Manufacturer plate',(.7,.64,.44),.3)
def box(name,loc,dim,material,bevel=.015):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=dim;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material);b=o.modifiers.new('Rounded machined edges','BEVEL');b.width=bevel;b.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return o
box('Engine housing',(-.24,0,.08),(.34,.22,.23),orange,.045)
box('Metal chain cover',(-.12,-.12,.06),(.22,.025,.18),steel)
box('Guide bar',(.21,0,.08),(.60,.035,.115),steel,.05)
for i in range(24):
 x=-.065+i*.024
 for z in [.016,.144]:
  tooth=box('Alternating cutting link',(x,0,z),(.013,.043,.014),dark,.002);tooth.rotation_euler.y=(-.32 if i%2 else .32)
for z in [.037,.067,.097,.127]:box('Tip chain',(.505,0,z),(.015,.043,.014),dark,.002)
for i in range(7):box('Cooling vents',(-.31+i*.023,-.112,.11),(.011,.012,.105),black,.003)
box('Rear handle top',(-.47,0,.13),(.23,.05,.04),black)
box('Rear handle bottom',(-.47,0,-.025),(.23,.05,.04),black)
box('Rear handle end',(-.575,0,.054),(.035,.05,.18),black)
box('Trigger',(-.45,0,.08),(.035,.03,.045),orange,.004)
for y in [-.14,.14]:box('Front wrap handle',(-.09,y,.19),(.04,.035,.27),black)
box('Front handle crossbar',(-.09,0,.31),(.04,.31,.04),black)
box('Hand guard',(-.025,0,.21),(.028,.24,.12),black)
box('Safety label',(-.24,0,.201),(.13,.095,.003),cream,.001)
for x in [-.19,-.32]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.017,location=(x,-.131,.05));bpy.context.object.data.materials.append(steel)
box('Fuel cap',(-.36,.065,.20),(.06,.06,.025),black,.01)

for obj in bpy.context.scene.objects:
 obj.select_set(obj.type == "MESH")
bpy.ops.export_scene.gltf(filepath=str(OUT/"chainsaw.glb"),export_format="GLB",use_selection=True,export_apply=True)
