"""Create an ImageGen-referenced Blender laundry washer bank for M01."""
from pathlib import Path
import bpy, json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/laundry_washer_v2'; OUT.mkdir(parents=True,exist_ok=True)
REF=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/laundry_washer_v2/laundry_washer_imagegen_reference.png'
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,color,metal=0.0,emit=0.0):
    m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*color,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=.36
    if emit:b.inputs['Emission Color'].default_value=(*color,1);b.inputs['Emission Strength'].default_value=emit
    return m
def image_material():
    m=material('ImageGen enamel patina',(0.44,.39,.30),.35)
    t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(REF),check_existing=True)
    b=m.node_tree.nodes.get('Principled BSDF');m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color'])
    return m
def box(name,loc,size,mat,bevel=.0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
    if bevel: mod=o.modifiers.new('rounded service edges','BEVEL');mod.width=bevel;mod.segments=2
    return o
patina=image_material(); ivory=material('washed ivory enamel',(.69,.63,.49),.28); dark=material('control panel charcoal',(.025,.05,.06),.65); glass=material('wet drum glass',(.015,.09,.13),.55); chrome=material('drum chrome',(.40,.45,.43),.84); cyan=material('status cyan',(0,.83,.95),emit=2.3); red=material('status red',(1,.03,.05),emit=2.0); towel_a=material('faded salmon towels',(.62,.22,.16)); towel_b=material('motel teal towels',(.05,.28,.29))
# physical back and two washer carcasses, proportioned for a 32 x 16px legacy footprint.
box('wall service plate',(0,.18,.05),(3.75,.18,.12),dark,.03)
for i,x in enumerate([-.92,.92]):
    box('ImageGen patina washer body', (x,0,.12),(1.72,.86,.20),patina,.05)
    box('powder enamel lid',(x,-.02,.245),(1.58,.75,.07),ivory,.035)
    box('recessed control panel',(x,.16,.29),(1.34,.22,.04),dark,.015)
    box('coin hardware',(x+.53,.16,.325),(.16,.16,.04),chrome,.015)
    for dx,led in [(-.34,cyan),(-.18,red)]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.045,location=(x+dx,.16,.335));bpy.context.object.data.materials.append(led)
    bpy.ops.mesh.primitive_torus_add(major_radius=.255,minor_radius=.067,major_segments=24,minor_segments=8,location=(x,-.13,.31)); bpy.context.object.data.materials.append(chrome)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.23,depth=.024,location=(x,-.13,.324)); bpy.context.object.data.materials.append(glass)
# towels and detergent provide a readable lived-in silhouette.
for loc,size,mat in [((-.94,-.12,.34),(.62,.35,.08),towel_a),((-.92,-.12,.405),(.50,.30,.065),towel_b),((.92,-.12,.34),(.48,.30,.075),towel_b)]: box('folded linen',loc,size,mat,.025)
box('detergent bottle',(.55,-.11,.39),(.20,.18,.22),ivory,.04); box('detergent cap',(.55,-.11,.52),(.11,.10,.05),cyan,.015)
scene=bpy.context.scene;scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=192;scene.render.resolution_y=96;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True;scene.view_settings.look='AgX - Medium High Contrast'
bpy.ops.object.camera_add(location=(0,0,5));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=4.55;cam.rotation_euler=(0,0,0);scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-2,-2,3));bpy.context.object.data.energy=120;bpy.context.object.data.color=(.3,.7,1);bpy.context.object.data.size=4
bpy.ops.object.light_add(type='AREA',location=(2,1,2));bpy.context.object.data.energy=90;bpy.context.object.data.color=(1,.26,.08);bpy.context.object.data.size=3
scene.render.filepath=str(OUT/'laundry_washer_bank.png');bpy.ops.render.render(write_still=True);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'laundry_washer_bank.blend'))
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':True,'file':'laundry_washer_bank.png','imagegen_reference':'res://assets/art/prerendered/m01_sunset_palms/staging/laundry_washer_v2/laundry_washer_imagegen_reference.png','production_method':'ImageGen prop reference plus Blender-modelled washer bank and lighting.','expected_count':2,'approval_scope':'M01 service-laundry visual replacement only; original Furniture collision remains authoritative.'},indent=2))
print('M01_LAUNDRY_WASHER_V2 rendered')
