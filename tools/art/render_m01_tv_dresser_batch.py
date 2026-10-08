"""Coherent ImageGen-backed walnut dresser and authored CRT, staging only."""
from pathlib import Path
import sys,math,json
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
SOURCE=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/nightstand_family_v1/nightstand.blend'
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/tv_dresser_family_v1'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
old=next(o for o in bpy.data.objects if o.type=='EMPTY' and o.name.startswith('Motel nightstand'))
for obj in list(old.children_recursive)+[old]:bpy.data.objects.remove(obj,do_unlink=True)
wood=bpy.data.materials['Shared motel ImageGen walnut']
brass=bpy.data.materials['Aged brushed brass']
dark=bpy.data.materials['Inset shadow / clock casing']
paper=bpy.data.materials['Folded cream paper']
def material(name,colour,source=None):
 m=bpy.data.materials.new(name);m.use_nodes=True
 s=m.node_tree.nodes['Principled BSDF'];s.inputs['Base Color'].default_value=(*colour,1)
 s.inputs['Roughness'].default_value=.6
 if source:apply_reviewed_source(m,source)
 return m
plastic=material('ImageGen textured CRT casing',(.09,.09,.08),'rubber')
glass=material('Curved CRT glass',(.025,.045,.055))
glass.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.16
label=material('Ivory television markings',(.65,.60,.48))
root=bpy.data.objects.new('Sunset Palms walnut CRT dresser',None);bpy.context.collection.objects.link(root)
def box(name,pos,size,mat,bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
 obj=bpy.context.object;obj.name=name;obj.dimensions=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 obj.parent=root;obj.data.materials.append(mat)
 mod=obj.modifiers.new('Authored edge profile','BEVEL');mod.width=bevel;mod.segments=4
 obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return obj
box('Walnut cabinet',(0,0,.38),(1.55,.46,.58),wood,.015)
box('Walnut overhanging top',(0,0,.69),(1.62,.50,.04),wood,.009)
for x in (-.68,.68):
 for y in (-.17,.17):box('Short cabinet foot',(x,y,.055),(.07,.07,.11),wood,.006)
for x in (-.385,.385):
 for z in (.22,.40,.58):
  box('Drawer reveal',(x,-.238,z),(.725,.01,.163),dark,.002)
  box('Walnut drawer',(x,-.251,z),(.705,.026,.144),wood,.005)
  for dx in (-.075,.075):box('Pull standoff',(x+dx,-.271,z),(.012,.025,.013),brass,.003)
  box('Brushed brass pull',(x,-.289,z),(.18,.014,.014),brass,.004)
box('CRT recessed pedestal',(-.15,.03,.735),(.48,.31,.045),plastic,.012)
box('Rounded CRT casing',(-.15,.035,.98),(.72,.38,.46),plastic,.045)
box('Recessed black bezel',(-.205,-.161,.99),(.55,.012,.355),dark,.034)
# Rounded geometry creates a physical convex surface, not a flat scene picture.
box('Convex dark CRT glass',(-.215,-.172,.995),(.48,.048,.295),glass,.07)
for z in (.93,1.04):
 bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=.025,depth=.025,location=(.145,-.17,z),rotation=(math.pi/2,0,0))
 knob=bpy.context.object;knob.name='CRT tuning knob';knob.parent=root;knob.data.materials.append(plastic)
for z in (.835,.849,.863,.877):box('Speaker grille slot',(.12,-.161,z),(.12,.005,.005),dark,.001)
box('Small channel scale',(.12,-.165,1.115),(.10,.004,.025),label,.003)
for i in range(7):box('Back ventilation slot',(-.35+i*.065,.229,1.06),(.025,.006,.11),dark,.002)
box('Folded guest directory',(.53,.015,.716),(.24,.24,.012),paper,.002)
box('Remote control',(.40,-.13,.74),(.065,.19,.035),plastic,.006)
for i in range(4):
 for x in (.385,.415):box('Remote button',(x,-.19+i*.035,.759),(.011,.016,.004),label,.001)
scene=bpy.context.scene;camera=scene.camera;look=Vector((0,0,.56))
camera.location=look+Vector((0,-4,4.75))
camera.rotation_euler=(look-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=2.55;scene.cycles.samples=24
bpy.context.view_layer.update()
anchor=world_to_camera_view(scene,camera,Vector((0,0,0)))
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'tv_dresser.blend'))
frames=[]
for degrees in (0,90,180,270):
 root.rotation_euler[2]=math.radians(degrees)
 filename=f'tv_dresser_{degrees:03d}.png';scene.render.filepath=str(OUT/filename)
 bpy.ops.render.render(write_still=True)
 bpy.context.view_layer.update()
 screen=[]
 if degrees==0:
  # Inside the convex glass rim: authored surface coordinates projected by
  # the same Blender camera, never a guessed rectangle in game pixels.
  for x,z in [(-.385,1.085),(-.045,1.085),(-.025,1.065),(-.025,.925),
              (-.045,.905),(-.385,.905),(-.405,.925),(-.405,1.065)]:
   point=world_to_camera_view(scene,camera,root.matrix_world@Vector((x,-.199,z)))
   screen.append([point.x*512,(1-point.y)*512])
 frames.append({'file':filename,'rotation_degrees':degrees,'floor_anchor_px':[anchor.x*512,(1-anchor.y)*512],
                'screen_polygon_px':screen})
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':False,'footprint_metres':[1.62,.50],
 'height_metres':1.21,'pixels_per_metre':512/2.55,'frames':frames,
 'source_kind':'Blender geometry with existing ImageGen walnut and rubber colour maps',
 'pending':['visual review','screen playback overlay','solid collider mapping','room layout and actor occlusion review']},indent=2))
print('M01_TV_DRESSER_BATCH: four authored views, staging only')
