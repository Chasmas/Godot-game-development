"""Assemble existing ImageGen-backed Blender furniture into a coherent room study."""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
BASE=ROOT/'assets/art/prerendered/m01_sunset_palms/staging'
OUT=BASE/'guest_room_composition_v10';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,key):
    m=bpy.data.materials.new(name);m.use_nodes=True;apply_reviewed_source(m,key);return m
wood=material('Shared walnut architecture','walnut')
plaster=material('ImageGen ivory plaster','ivory_plaster')
carpet=material('ImageGen motel carpet','carpet')
tile=material('ImageGen bathroom tile','bathroom_tiles')
metal=bpy.data.materials.new('Painted motel appliance metal');metal.use_nodes=True
metal.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.38,.40,.36,1)
metal.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.52
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

def curtain_panel(name, x, y0, y1, z0, height, color, phase):
    """A real folded curtain surface on the window wall, with a weighted hem."""
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.82
    verts=[];faces=[];cols=30;rows=22
    for j in range(rows+1):
        v=j/rows
        for i in range(cols+1):
            u=i/cols
            y=y0+(y1-y0)*u
            # Regular folds and a slight gathered top read at game distance.
            fold=.042*math.sin(u*math.pi*8+phase)*(0.32+v*.68)
            hem=.018*math.sin(u*math.pi*3+phase)*v*v
            z=z0+height*(1-v)+hem
            verts.append((x+fold,y,z))
    for j in range(rows):
        for i in range(cols):
            k=j*(cols+1)+i;faces.append((k,k+1,k+cols+2,k+cols+1))
    mesh=bpy.data.meshes.new(name+' folds');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    solidify=obj.modifiers.new('Curtain fabric thickness','SOLIDIFY');solidify.thickness=.012
    for face in mesh.polygons: face.use_smooth=True
    return obj
box('Room floor',(0,0,-.06),(5.4,5.2,.12),carpet)
box('Headboard wall',(0,2.6,1.2),(5.4,.16,2.4),plaster)
# Real window opening: avoid hiding a window mesh inside a solid wall.
box('West wall south',(-2.7,-1.625,1.2),(.16,1.95,2.4),plaster)
box('West wall north',(-2.7,2.125,1.2),(.16,.95,2.4),plaster)
box('West wall below window',(-2.7,.5,.325),(.16,2.3,.65),plaster)
box('West wall above window',(-2.7,.5,2.15),(.16,2.3,.50),plaster)
furniture(BASE/'window_v1/window.blend',(-2.60,.5,.2),math.pi*.5)
# Layered motel curtains frame the real window mesh and leave the neon-blue
# exterior light visible.  They are staging geometry, not level blockers.
rod=box('Brass curtain rod',(-2.53,.50,2.02),(.045,2.15,.045),wood)
for y in (-.55,1.55):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.072,location=(-2.53,y,2.02))
    bpy.context.object.name='Curtain rod finial';bpy.context.object.data.materials.append(wood)
curtain_panel('Left patterned blackout curtain',-2.56,-.57,.03,.27,1.70,(.20,.29,.25),.35)
curtain_panel('Right patterned blackout curtain',-2.56,.97,1.57,.27,1.70,(.20,.29,.25),2.0)
curtain_panel('Sheer window curtain',-2.575,.04,.96,.30,1.63,(.77,.72,.57),1.1)
# A period motel PTAC below the window makes the wall functional rather than
# an empty backdrop.
ac=box('Motel PTAC air conditioner',(-2.49,.50,.36),(.12,1.25,.34),metal)
for y in [-.40,-.20,0,.20,.40]:
    box('PTAC grille slot',(-2.57,y,.43),(.012,.11,.028),wood)

for name,pos,size in [('North skirting',(0,2.50,.09),(5.3,.035,.18)),('West skirting',(-2.60,0,.09),(.035,5.1,.18))]:box(name,pos,size,wood)
furniture(BASE/'bed_family_v1/motel_bed.blend',(-.6,1.28,0))
furniture(BASE/'nightstand_family_v1/nightstand.blend',(-1.88,1.96,0))
furniture(BASE/'nightstand_family_v1/nightstand.blend',(.68,1.96,0))
furniture(BASE/'tv_dresser_family_v1/tv_dresser.blend',(-.6,-1.94,0),math.pi)
furniture(BASE/'armchair_runtime_v3/armchair_runtime_review.blend',(-1.92,-.95,0),0,'M01 upholstered armchair',(-.6,-1.94,0))
furniture(BASE/'rug_family_v1/motel_rug.blend',(-.6,-.65,.008))
# Authored room dressing remains a staging study, independent of gameplay geometry.
from m01_guest_room_dressing import dress_room
dress_room(box, wood, material)
# The reference room has a guest actively staying there: preserve a clear
# player route while adding an open suitcase, shoes and a small room-service
# tray to the otherwise unused entry edge.
leather=bpy.data.materials.new('Open luggage leather');leather.use_nodes=True
leather.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.085,.035,.018,1)
leather.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.48
linen=bpy.data.materials.new('Packed linen');linen.use_nodes=True
linen.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.30,.42,.44,1)
linen.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88
box('Open suitcase lower shell',(1.97,-1.23,.17),(.88,.55,.20),leather)
lid=box('Open suitcase raised lid',(1.97,-.95,.50),(.88,.055,.54),leather);lid.rotation_euler.x=.17
box('Folded shirt in open suitcase',(1.83,-1.23,.31),(.32,.30,.05),linen)
box('Folded jeans in open suitcase',(2.16,-1.23,.31),(.27,.30,.05),wood)
for x in (1.72,2.23):
    box('Open suitcase brass latch',(x,-1.515,.25),(.052,.018,.052),wood)
for y in (-1.62,-1.39):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=10,location=(2.30,y,.075))
    shoe=bpy.context.object;shoe.name='Guest shoe';shoe.scale=(.17,.075,.055);shoe.data.materials.append(leather)
tray=box('Room service tray',(1.52,-1.59,.10),(.48,.30,.05),wood)
bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.075,depth=.12,location=(1.52,-1.59,.19))
bpy.context.object.name='Room service glass';bpy.context.object.data.materials.append(metal)
# A distinct tiled bathroom bay and entrance leaf make the room read as a motel
# suite rather than a furniture sample.  Neither is production gameplay art.
box('Bathroom tile floor',(1.93,1.66,.006),(1.34,1.64,.025),tile)
box('Bathroom inner wall',(1.24,1.66,1.2),(.10,1.64,2.4),plaster)
box('Bathroom rear tile wall',(1.93,2.43,1.2),(1.34,.05,2.4),tile)
box('Bathroom east tile wall',(2.57,1.66,1.2),(.05,1.64,2.4),tile)
box('Entry threshold tile floor',(2.10,-1.55,.007),(1.18,.96,.026),tile)
box('Entry threshold north trim',(2.10,-1.08,.10),(1.18,.045,.20),wood)
ceramic=bpy.data.materials.new('Bathroom ceramic');ceramic.use_nodes=True
ceramic.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.76,.72,.59,1)
ceramic.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.25
mirror=bpy.data.materials.new('Bathroom mirror and chrome');mirror.use_nodes=True
mirror_shader=mirror.node_tree.nodes['Principled BSDF']
mirror_shader.inputs['Base Color'].default_value=(.20,.34,.34,1)
mirror_shader.inputs['Metallic'].default_value=.78
mirror_shader.inputs['Roughness'].default_value=.13
box('Bathroom compact vanity',(2.18,2.13,.46),(.52,.28,.86),wood)
box('Bathroom porcelain basin',(2.18,1.96,.92),(.44,.25,.10),ceramic)
# Give the bathroom a readable lived-in fixture wall rather than a dark tiled
# void: an inset mirror, chrome faucet, towel rail and a shallow shower curb
# all stay within the staging suite footprint.
box('Bathroom framed mirror',(2.18,2.385,1.36),(.60,.026,.58),mirror)
box('Bathroom mirror walnut frame top',(2.18,2.36,1.67),(.70,.045,.045),wood)
box('Bathroom mirror walnut frame bottom',(2.18,2.36,1.05),(.70,.045,.045),wood)
for x in (1.84,2.52):
    box('Bathroom mirror walnut side frame',(x,2.36,1.36),(.045,.045,.64),wood)
box('Bathroom chrome faucet',(2.18,2.02,1.08),(.06,.08,.22),mirror)
box('Bathroom shower curb',(1.58,1.05,.10),(.54,.12,.15),ceramic)
box('Bathroom frosted shower panel',(1.36,1.05,.95),(.024,.72,1.62),mirror)
box('Bathroom towel rail',(1.295,1.88,1.28),(.024,.48,.045),mirror)
box('Bathroom folded towel',(1.27,1.88,1.14),(.045,.30,.24),linen)
box('Bathroom toilet-paper holder',(1.34,1.04,.72),(.06,.14,.06),mirror)
bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.075,depth=.10,location=(1.39,1.04,.72),rotation=(math.pi*.5,0,0))
paper=bpy.context.object;paper.name='Bathroom toilet paper roll';paper.data.materials.append(ceramic)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=(1.61,1.22,.28))
toilet=bpy.context.object;toilet.name='Bathroom ceramic toilet';toilet.scale=(.23,.29,.28);toilet.data.materials.append(ceramic)
box('Bathroom toilet cistern',(1.61,1.43,.48),(.36,.15,.43),ceramic)
furniture(BASE/'guest_door_v1/guest_door.blend',(1.24,.83,0),math.pi/2)
furniture(BASE/'guest_door_v1/guest_door.blend',(2.62,-.72,0),math.pi/2)
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
area('Chair corner practical bounce',(2.1,-.6,2.3),45,(1,.72,.44),1.5)
area('Bathroom vanity practical',(2.13,1.82,2.05),32,(1,.74,.48),.38)
data=bpy.data.cameras.new('Game perspective study');camera=bpy.data.objects.new('Game perspective study',data)
bpy.context.collection.objects.link(camera);camera.location=(6,-9,11)
camera.rotation_euler=(Vector((0,.4,.85))-camera.location).to_track_quat('-Z','Y').to_euler()
data.type='ORTHO';data.ortho_scale=9.1;scene.camera=camera
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'guest_room_composition.blend'))
scene.render.filepath=str(OUT/'guest_room_composition.png');bpy.ops.render.render(write_still=True)
(OUT/'review.json').write_text(json.dumps({'runtime_approved':False,'source':'Existing ImageGen-backed Blender furniture and door reconstruction with authored textile and room dressing','scope':'v10 staging: v9 textiles, botanical artwork, curtains, PTAC and entry dressing, plus a refined bathroom fixture wall with mirror, faucet, shower panel, towel rail and practical lighting. This camera remains art review only, not an approved gameplay projection.','pending':['Reference-quality textile and botanical artwork refinement','Adapt to exact gameplay projection and room geometry','Validate collisions, door clearance and actor placement']},indent=2)+'\n',encoding='utf-8')
