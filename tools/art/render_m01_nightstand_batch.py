"""Authored bedside cabinet with ImageGen colour maps, four coherent views."""
from pathlib import Path
import sys,json,math
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/nightstand_family_v1'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,colour,source=None,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=(*colour,1)
 s.inputs['Roughness'].default_value=.6;s.inputs['Metallic'].default_value=metal
 if source:apply_reviewed_source(m,source)
 return m
wood=mat('Shared motel ImageGen walnut',(.3,.15,.08),'walnut')
linen=mat('Shared motel ImageGen shade linen',(.85,.82,.72),'towel')
brass=mat('Aged brushed brass',(.48,.32,.13),metal=.8)
dark=mat('Inset shadow / clock casing',(.045,.038,.033))
paper=mat('Folded cream paper',(.72,.65,.50))
root=bpy.data.objects.new('Motel nightstand with practical lamp and clock',None)
bpy.context.collection.objects.link(root)
def box(name,pos,size,material,bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
 obj=bpy.context.object;obj.name=name;obj.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 obj.parent=root;obj.data.materials.append(material)
 mod=obj.modifiers.new('Fine cabinet bevel','BEVEL');mod.width=bevel;mod.segments=3
 obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return obj
def cylinder(name,pos,radius,depth,material):
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=depth,location=pos)
 obj=bpy.context.object;obj.name=name;obj.parent=root;obj.data.materials.append(material)
 mod=obj.modifiers.new('Rounded metal rims','BEVEL');mod.width=.004;mod.segments=3
 return obj
for x in (-.285,.285):
 box('Walnut cabinet side',(x,0,.34),(.03,.46,.55),wood,.008)
box('Walnut cabinet back',(0,.215,.34),(.54,.03,.55),wood,.008)
box('Drawer compartment',(0,0,.475),(.54,.40,.27),wood,.008)
box('Overhanging walnut top',(0,0,.632),(.65,.50,.035),wood)
for x in (-.23,.23):
 for y in (-.17,.17):box('Tapered short foot',(x,y,.055),(.055,.055,.11),wood)
for z in (.40,.55):
 box('Dark drawer reveal',(0,-.236,z),(.55,.015,.127),dark,.003)
 box('Walnut drawer front',(0,-.247,z),(.535,.022,.112),wood,.004)
 for x in (-.045,.045):box('Handle standoff',(x,-.269,z),(.01,.02,.012),brass,.003)
 box('Brass pull',(0,-.282,z),(.11,.014,.012),brass,.004)
box('Lower open shelf',(0,-.03,.16),(.52,.37,.025),wood)
box('Shelf back shadow',(0,.195,.235),(.50,.005,.12),dark,.002)
box('Folded guest magazine',(-.11,-.015,.18),(.24,.19,.018),paper,.002)
cylinder('Lamp weighted base',(-.12,.065,.67),.095,.025,brass)
cylinder('Lamp brass stem',(-.12,.065,.85),.013,.35,brass)
bpy.ops.mesh.primitive_cone_add(vertices=64,radius1=.15,radius2=.09,depth=.20,end_fill_type='NOTHING',location=(-.12,.065,1.04))
shade=bpy.context.object;shade.name='Tapered linen lampshade';shade.parent=root;shade.data.materials.append(linen)
solid=shade.modifiers.new('Shade fabric thickness','SOLIDIFY');solid.thickness=.003
for name,radius,z in [('upper',.09,1.14),('lower',.15,.94)]:
 bpy.ops.mesh.primitive_torus_add(major_radius=radius,minor_radius=.003,
  major_segments=64,minor_segments=8,location=(-.12,.065,z))
 rim=bpy.context.object;rim.name='Open shade '+name+' brass rim';rim.parent=root;rim.data.materials.append(brass)
cylinder('Lamp bulb socket',(-.12,.065,1.02),.022,.065,brass)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=.026,location=(-.12,.065,1.07))
bulb=bpy.context.object;bulb.name='Visible ivory bulb';bulb.parent=root;bulb.data.materials.append(paper)
box('Clock radio',(.17,-.08,.695),(.20,.11,.09),dark,.012)
display=mat('Clock dark green display',(.025,.07,.045))
box('Inset clock face',(.17,-.139,.704),(.14,.005,.039),display,.002)
for x in (.23,.26):box('Clock buttons',(x,-.055,.744),(.018,.025,.008),brass,.002)
box('Guest note',(.14,.12,.653),(.17,.115,.003),paper,.001)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA';scene.view_settings.view_transform='Standard'
scene.world=bpy.data.worlds.new('Neutral prop world');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
look=Vector((0,0,.5));bpy.ops.object.camera_add(location=look+Vector((0,-4,4.75)))
camera=bpy.context.object;camera.rotation_euler=(look-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=1.8;scene.camera=camera
for pos,energy in [((-2,-3,4),150),((2,2,3),80)]:
 bpy.ops.object.light_add(type='AREA',location=pos)
 light=bpy.context.object;light.data.energy=energy;light.data.size=3
 light.rotation_euler=(look-light.location).to_track_quat('-Z','Y').to_euler()
anchor=world_to_camera_view(scene,camera,Vector((0,0,0)))
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'nightstand.blend'))
frames=[]
for degrees in (0,90,180,270):
 root.rotation_euler[2]=math.radians(degrees)
 filename=f'nightstand_{degrees:03d}.png';scene.render.filepath=str(OUT/filename)
 bpy.ops.render.render(write_still=True)
 frames.append({'file':filename,'rotation_degrees':degrees,'floor_anchor_px':[anchor.x*512,(1-anchor.y)*512]})
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':False,'footprint_metres':[.65,.5],
 'height_metres':1.143,'pixels_per_metre':512/1.8,'frames':frames,
 'source_kind':'Blender geometry; existing ImageGen walnut and linen colour maps',
 'pending':['visual and scale review','solid collider mapping','lamp light attachment','room layout validation']},indent=2))
print('M01_NIGHTSTAND_BATCH: four views, staging only')
