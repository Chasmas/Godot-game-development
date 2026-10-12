"""Create the M01 office desk as an ImageGen-directed Blender render."""
from pathlib import Path
import bpy,json
ROOT=Path(__file__).resolve().parents[2]; OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/office_desk_v2';OUT.mkdir(parents=True,exist_ok=True); REF=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/office_desk_v2/office_desk_imagegen_reference.png'
bpy.ops.wm.read_factory_settings(use_empty=True)
def m(name,c,metal=0,emit=0):
 x=bpy.data.materials.new(name);x.use_nodes=True;b=x.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*c,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=.38
 if emit:b.inputs['Emission Color'].default_value=(*c,1);b.inputs['Emission Strength'].default_value=emit
 return x
def image_mat():
 x=m('ImageGen worn walnut reference',(.16,.055,.018),.22);t=x.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(REF),check_existing=True);x.node_tree.links.new(t.outputs['Color'],x.node_tree.nodes.get('Principled BSDF').inputs['Base Color']);return x
def box(n,p,s,mat,b=.0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=n;o.dimensions=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 if b:q=o.modifiers.new('soft worn edge','BEVEL');q.width=b;q.segments=2
 return o
wood=image_mat();dark=m('charcoal plastic',(.015,.022,.024),.45);paper=m('faded paper',(.7,.56,.32));brass=m('oxidized brass',(.45,.23,.04),.7);cyan=m('security monitor glow',(0,.65,.62),emit=2.0);amber=m('desk lamp glow',(1,.38,.06),emit=2.7);leather=m('brown leather',(.10,.025,.012),.1)
box('ImageGen walnut desk carcass',(0,0,.10),(4.5,1.23,.18),wood,.06);box('worn desk inset',(0,0,.205),(4.18,.98,.035),wood,.04)
for x in [-1.74,1.74]:
 for y in [-.28,0,.28]: box('drawer front',(x,y,.22),(.55,.20,.05),leather,.015);bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=5,radius=.04,location=(x,y,.255));bpy.context.object.data.materials.append(brass)
# CRT, screen, phone and manager desk clutter
box('security CRT',(-1.22,-.08,.29),(.72,.48,.19),dark,.05);box('cyan surveillance screen',(-1.22,-.08,.395),(.49,.30,.025),cyan,.018);box('monitor pedestal',(-1.22,.23,.28),(.22,.14,.10),dark,.02)
box('rotary phone',(.28,-.08,.285),(.55,.40,.10),dark,.08);bpy.ops.mesh.primitive_torus_add(major_radius=.13,minor_radius=.036,major_segments=18,minor_segments=6,location=(.28,-.08,.35));bpy.context.object.data.materials.append(brass)
box('open ledger',(.95,.10,.275),(.75,.46,.045),paper,.014);box('brass desk lamp',(1.64,-.22,.29),(.25,.20,.08),brass,.04);bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.15,location=(1.64,-.22,.36));bpy.context.object.data.materials.append(amber)
for p in [(-.48,.28,.275),(-.18,.29,.278)]:box('paper note',p,(.22,.14,.025),paper,.01)
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=256;s.render.resolution_y=96;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.film_transparent=True;s.view_settings.look='AgX - Medium High Contrast'
bpy.ops.object.camera_add(location=(0,0,5));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=5.3;cam.rotation_euler=(0,0,0);s.camera=cam
for loc,col,energy in [((-2,-2,3),(.3,.7,1),120),((2,1,2),(1,.22,.04),90)]:bpy.ops.object.light_add(type='AREA',location=loc);bpy.context.object.data.energy=energy;bpy.context.object.data.color=col;bpy.context.object.data.size=4
s.render.filepath=str(OUT/'office_desk.png');bpy.ops.render.render(write_still=True);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'office_desk.blend'))
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':True,'file':'office_desk.png','imagegen_reference':'res://assets/art/prerendered/m01_sunset_palms/staging/office_desk_v2/office_desk_imagegen_reference.png','production_method':'ImageGen manager-desk reference plus Blender geometry, props and render.','expected_count':1,'approval_scope':'M01 office-desk visual only; existing Furniture collision stays authoritative.'},indent=2));print('M01_OFFICE_DESK_V2 rendered')
