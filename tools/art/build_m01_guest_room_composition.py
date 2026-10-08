"""Assemble existing ImageGen-backed Blender furniture into a coherent room study."""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
BASE=ROOT/'assets/art/prerendered/m01_sunset_palms/staging'
OUT=BASE/'guest_room_composition_v4';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,key):
    m=bpy.data.materials.new(name);m.use_nodes=True;apply_reviewed_source(m,key);return m
wood=material('Shared walnut architecture','walnut')
plaster=material('ImageGen ivory plaster','ivory_plaster')
carpet=material('ImageGen motel carpet','carpet')
def box(name,pos,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    bevel=o.modifiers.new('Physical edge bevel','BEVEL');bevel.width=.015;bevel.segments=3
    return o
def furniture(path,pos,angle=0,root_prefix=None,look_at=None):
    with bpy.data.libraries.load(str(path),link=False) as (src,dst):
        dst.objects=src.objects
    selected=set(dst.objects)
    if root_prefix:
        roots=[o for o in dst.objects if o and o.type=='EMPTY' and o.name.startswith(root_prefix)]
        assert roots,root_prefix
        selected={roots[0],*roots[0].children_recursive}
    imported=[]
    for o in dst.objects:
        if o in selected and o and o.type not in {'CAMERA','LIGHT'}:
            bpy.context.collection.objects.link(o);imported.append(o)
    group=bpy.data.objects.new(path.stem+' placement',None);bpy.context.collection.objects.link(group)
    for o in imported:
        if o.parent not in imported:o.parent=group
    group.location=pos;group.rotation_euler.z=angle
    if root_prefix:
        bpy.context.view_layer.update()
        if look_at:
            seat=next(o for o in imported if o.name.startswith('Armchair separate seat cushion'))
            back=next(o for o in imported if o.name.startswith('Armchair inclined back shell'))
            front=seat.matrix_world.translation-back.matrix_world.translation
            target=Vector(look_at)-Vector(pos)
            group.rotation_euler.z+=math.atan2(target.y,target.x)-math.atan2(front.y,front.x)
            bpy.context.view_layer.update()
        corners=[o.matrix_world @ Vector(c) for o in imported if o.type=='MESH' for c in o.bound_box]
        assert corners
        low=Vector(tuple(min(c[i] for c in corners) for i in range(3)))
        high=Vector(tuple(max(c[i] for c in corners) for i in range(3)))
        group.location+=Vector((pos[0]-(low.x+high.x)/2,pos[1]-(low.y+high.y)/2,pos[2]-low.z))
    return group
box('Room floor',(0,0,-.06),(5.4,5.2,.12),carpet)
box('Headboard wall',(0,2.6,1.2),(5.4,.16,2.4),plaster)
# Real window opening: avoid hiding a window mesh inside a solid wall.
box('West wall south',(-2.7,-1.625,1.2),(.16,1.95,2.4),plaster)
box('West wall north',(-2.7,2.125,1.2),(.16,.95,2.4),plaster)
box('West wall below window',(-2.7,.5,.325),(.16,2.3,.65),plaster)
box('West wall above window',(-2.7,.5,2.15),(.16,2.3,.50),plaster)
furniture(BASE/'window_v1/window.blend',(-2.60,.5,.2),math.pi*.5)

for name,pos,size in [('North skirting',(0,2.50,.09),(5.3,.035,.18)),('West skirting',(-2.60,0,.09),(.035,5.1,.18))]:box(name,pos,size,wood)
furniture(BASE/'bed_family_v1/motel_bed.blend',(-.6,1.28,0))
furniture(BASE/'nightstand_family_v1/nightstand.blend',(-1.88,1.96,0))
furniture(BASE/'nightstand_family_v1/nightstand.blend',(.68,1.96,0))
furniture(BASE/'tv_dresser_family_v1/tv_dresser.blend',(-.6,-1.94,0),math.pi)
furniture(BASE/'armchair_runtime_v3/armchair_runtime_review.blend',(1.7,-.4,0),0,'M01 upholstered armchair',(-.6,-1.94,0))
furniture(BASE/'rug_family_v1/motel_rug.blend',(-.6,-.65,.008))
# Picture placeholder is replaced by a deliberate walnut wall relief using shared materials.

box('Walnut picture frame',(1.75,2.49,1.13),(.7,.055,.52),wood)
for i in range(7):
    box('Wall relief walnut slat',(1.49+i*.085,2.455,1.13),(.038,.025,.38),wood)
# Real lamp sources provide local falloff and warm shadows, without baking fake halos.
for x in (-2.0,.56):
    light=bpy.data.lights.new('Bedside practical warm bulb','POINT')
    light.energy=18;light.color=(1,.62,.30);light.shadow_soft_size=.07
    bulb=bpy.data.objects.new(light.name,light);bpy.context.collection.objects.link(bulb)
    bulb.location=(x,2.025,1.04)

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1280;scene.render.resolution_y=960;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Guest room night world')
scene.world.color=(.025,.025,.04)
scene.view_settings.view_transform='AgX'
def area(name,pos,power,color,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);obj.location=pos
    obj.rotation_euler=(Vector((0,0,.3))-obj.location).to_track_quat('-Z','Y').to_euler()
area('Soft night window',(-3,.5,1.4),80,(.20,.50,1),1.2)
area('Warm room bounce',(-2,2,3),65,(1,.58,.28),3)
area('Gentle neutral fill',(0,-4,5),50,(.65,.73,1),5)
data=bpy.data.cameras.new('Game perspective study');camera=bpy.data.objects.new('Game perspective study',data)
bpy.context.collection.objects.link(camera);camera.location=(6,-9,11)
camera.rotation_euler=(Vector((0,.15,.1))-camera.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO';data.ortho_scale=8.4;scene.camera=camera
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'guest_room_composition.blend'))
scene.render.filepath=str(OUT/'guest_room_composition.png');bpy.ops.render.render(write_still=True)
(OUT/'review.json').write_text(json.dumps({'runtime_approved':False,'source':'Existing ImageGen-backed Blender bed, nightstand and TV dresser families','scope':'Coherent room composition study with authored opening and existing ImageGen-backed window, curtains and blinds; camera is an art-review view, not an approved gameplay projection','pending':['Inspect render','Adapt to exact gameplay projection and room geometry','Validate collisions, door clearance and actor placement']},indent=2)+'\n',encoding='utf-8')
