"""Build the Sunset Palms motel neon board from an ImageGen panel in Blender.

The generated panel is deliberately used as a weathered material layer, while
the readable title, depth, lamps and mounting hardware stay native Blender
geometry.  That keeps the prop tactile at gameplay scale without relying on
unreliable generated lettering.
"""
from pathlib import Path
import bpy, json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/sunset_palms_sign_v1';OUT.mkdir(parents=True,exist_ok=True)
REFERENCE=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/sunset_palms_sign_v2/sunset_palms_sign_imagegen_reference.png'
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(n,c,metal=0,emit=0):
 m=bpy.data.materials.new(n);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*c,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=.38
 if emit:b.inputs['Emission Color'].default_value=(*c,1);b.inputs['Emission Strength'].default_value=emit
 return m
metal=mat('aged motel metal',(.022,.014,.04),.65);chrome=mat('chromed trim',(.32,.35,.40),.8);pink=mat('hot pink neon',(1,.005,.16),emit=4.1);cyan=mat('cyan accent',(0,.65,1),emit=3.0);bolt=mat('bolts',(.4,.25,.08),.75);amber=mat('sunset amber',(1,.14,.015),emit=3.2)
def imagegen_panel():
 m=bpy.data.materials.new('ImageGen weathered neon panel');m.use_nodes=True
 nodes=m.node_tree.nodes;links=m.node_tree.links;bsdf=nodes.get('Principled BSDF')
 image=bpy.data.images.load(str(REFERENCE), check_existing=True);image.colorspace_settings.name='sRGB'
 tex=nodes.new('ShaderNodeTexImage');tex.image=image
 links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
 links.new(tex.outputs['Color'],bsdf.inputs['Emission Color'])
 bsdf.inputs['Emission Strength'].default_value=.19;bsdf.inputs['Metallic'].default_value=.42;bsdf.inputs['Roughness'].default_value=.36
 return m
panel=imagegen_panel()
def cube(n,p,s,m,b=.0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=n;o.dimensions=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if b:mo=o.modifiers.new('soft edges','BEVEL');mo.width=b;mo.segments=2
 return o
cube('thick powder-coated sign enclosure',(0,0,.06),(3.8,.78,.16),metal,.07)
# This is the ImageGen material pass: wet, scratched, layered glass and the
# palm/sunset medallion are not faked by line art or procedurally drawn cells.
cube('imagegen inset glass panel',(0,0,.151),(3.62,.61,.013),panel,.024)
# Blender provides additional visible tube depth, service brackets and title.
for y in [-.29,.29]:cube('raised neon tube',(0,y,.18),(3.50,.026,.040),pink,.012)
for x in [-1.74,1.74]:cube('raised neon tube',(x,0,.18),(.026,.60,.040),pink,.012)
for x,y in [(-1.55,-.19),(-1.55,.19),(1.55,-.19),(1.55,.19)]:
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.045,location=(x,y,.18));bpy.context.object.name='brass rivet';bpy.context.object.data.materials.append(bolt)
# The generated palm medallion remains visible at the left.  Exact lettering
# is extruded in Blender so it is crisp and valid in every language build.
for text,y,size,material in [('SUNSET',.09,.255,pink),('PALMS',-.19,.185,cyan)]:
 bpy.ops.object.text_add(location=(.43,y,.205));o=bpy.context.object;o.name='extruded motel lettering '+text;o.data.body=text;o.data.align_x='CENTER';o.data.align_y='CENTER';o.data.size=size;o.data.extrude=.022;o.data.bevel_depth=.009;o.data.materials.append(material)
# back brackets
for x in [-1.25,1.25]:
 cube('mount bracket',(x,.47,.02),(.12,.35,.08),chrome,.015)
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=384;s.render.resolution_y=64;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.film_transparent=True;s.view_settings.look='AgX - Medium High Contrast'
bpy.ops.object.camera_add(location=(0,0,5));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=4.35;cam.rotation_euler=(0,0,0);s.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-2,-1,3));bpy.context.object.data.energy=90;bpy.context.object.data.color=(.25,.6,1);bpy.context.object.data.size=4
bpy.ops.object.light_add(type='AREA',location=(2,1,2));bpy.context.object.data.energy=65;bpy.context.object.data.color=(1,.04,.2);bpy.context.object.data.size=3
s.render.filepath=str(OUT/'sunset_palms_sign.png');bpy.ops.render.render(write_still=True);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'sunset_palms_sign.blend'))
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':True,'file':'sunset_palms_sign.png','target_text':'SUNSET PALMS','imagegen_reference':'res://assets/art/prerendered/m01_sunset_palms/staging/sunset_palms_sign_v2/sunset_palms_sign_imagegen_reference.png','production_method':'ImageGen weathered panel reference/material plus Blender geometry, lettering, tubes, lights and render.','approval_scope':'M01 main NeonSign visual child only; existing sign anchor, light and flicker remain authoritative.'},indent=2))
print('M01_SUNSET_PALMS_SIGN: rendered')
