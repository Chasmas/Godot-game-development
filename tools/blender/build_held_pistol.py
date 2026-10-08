"""Detailed native held-pistol review prop. Blender X forward, Z upward."""
import bpy,math,json,os
from pathlib import Path
from mathutils import Vector
out=Path(os.environ.get('HELD_PISTOL_OUTPUT','build/held_pistol_candidate')).resolve();out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,color,metallic=0,rough=.5):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=rough
    return m
steel=material('Blued worn steel',(.038,.047,.061),.85,.32)
edge=material('Machined steel edges',(.16,.18,.2),.9,.28)
polymer=material('Charcoal polymer',(.026,.025,.027),0,.66)
dark=material('Recess shadow',(.006,.007,.009),.3,.7)
brass=material('Sight dots',(.74,.67,.4),.25,.4)
parts=[]
def box(name,at,size,mat,bevel=.001):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    obj=bpy.context.object;obj.name=name;obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    if bevel:
        b=obj.modifiers.new('Machined edge','BEVEL');b.width=bevel;b.segments=3
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=b.name)
    parts.append(obj);return obj
def cylinder(name,at,radius,depth,mat,axis='Z'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=depth,location=at)
    obj=bpy.context.object;obj.name=name
    if axis=='X':obj.rotation_euler.y=math.pi/2
    if axis=='Y':obj.rotation_euler.x=math.pi/2
    obj.data.materials.append(mat)
    parts.append(obj);return obj
# Grip centre is the origin, with the bore 55mm above it.
box('Polymer grip',(0,0,-.004),(.038,.031,.092),polymer,.004)
if os.environ.get('HELD_PISTOL_MAGAZINE')=='1':
    box('Magazine body',(0,0,-.009),(.026,.019,.077),steel,.001)
    box('Magazine floorplate',(-.001,0,-.051),(.041,.034,.007),steel,.0015)
else:
    box('Grip heel',(-.001,0,-.051),(.041,.034,.007),steel,.0015)
box('Receiver',(.058,0,.033),(.174,.032,.022),polymer,.002)
box('Slide',(.062,0,.056),(.192,.034,.033),steel,.002)
box('Slide top flat',(.062,0,.073),(.175,.027,.003),edge,.0006)
cylinder('Muzzle barrel',(.163,0,.055),.0078,.012,edge,'X')
cylinder('Bore recess',(.1692,0,.055),.0049,.0006,dark,'X')
cylinder('Recoil guide',(.16,0,.039),.003,.006,steel,'X')
# Trigger guard: a rounded rectangular ring extruded across the receiver.
outer=[(.018,.026),(.047,.026),(.058,.016),(.058,-.011),(.047,-.021),(.017,-.021)]
inner=[(.024,.019),(.045,.019),(.051,.012),(.051,-.008),(.044,-.014),(.024,-.014)]
vertices=[(x,y,z) for y in (-.012,.012) for loop in (outer,inner) for x,z in loop]
faces=[];n=len(outer)
for i in range(n):
    j=(i+1)%n
    faces += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
              (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
mesh=bpy.data.meshes.new('Guard ring');mesh.from_pydata(vertices,[],faces);mesh.update()
obj=bpy.data.objects.new('Trigger guard',mesh);bpy.context.collection.objects.link(obj)
obj.data.materials.append(polymer);parts.append(obj)
trigger=box('Curved trigger',(.031,0,.003),(.004,.012,.025),steel,.001)
trigger.rotation_euler.y=-.18
for side in (-1,1):
    box('Grip side panel',(0,.016*side,-.006),(.03,.0015,.067),polymer,.001)
    for row in range(9):
        for col in range(4):
            box('Grip checkering',(-.011+col*.007,.0172*side,-.033+row*.006),(.003,.0007,.003),steel,.0002)
    for i in range(9):
        box('Slide serration',(-.018+i*.004,.0172*side,.055),(.0012,.0008,.021),dark,.0001)
    cylinder('Frame pin',(.009,.017*side,.025),.0023,.0015,edge,'Y')
    box('Slide catch',(.024,.018*side,.026),(.014,.002,.004),edge,.0005)
    box('Magazine latch',(.008,.017*side,.008),(.005,.002,.005),edge,.0004)
box('Ejection port',(.063,-.0176,.059),(.028,.001,.015),dark,.0005)
box('Chamber steel',(.064,-.0179,.064),(.021,.0006,.005),edge,.0002)
box('Rear sight',(-.018,0,.077),(.009,.027,.008),steel,.001)
box('Front sight',(.141,0,.078),(.004,.005,.006),steel,.0005)
for side in (-1,1):box('Rear sight dot',(-.023,.008*side,.079),(.0005,.002,.002),brass,.0001)
box('Front sight dot',(.1385,0,.079),(.0005,.002,.002),brass,.0001)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'pistol.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'pistol.glb'),export_format='GLB',use_selection=True,export_animations=False)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.render.resolution_x=800;scene.render.resolution_y=600;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Review studio');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.22,.22,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.camera_add(location=(.31,-.4,.24));camera=bpy.context.object
camera.rotation_euler=(Vector((.065,0,.02))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=.31;camera.data.clip_start=.001;scene.camera=camera
for at,power in [((.1,-.2,.3),12),((-.1,.15,.2),8)]:
    bpy.ops.object.light_add(type='AREA',location=at);light=bpy.context.object
    light.rotation_euler=(Vector((.05,0,.03))-light.location).to_track_quat('-Z','Y').to_euler()
    light.data.energy=power;light.data.size=.25
scene.render.filepath=str(out/'review.png');bpy.ops.render.render(write_still=True)
(out/'report.json').write_text(json.dumps({'approved':False,'parts':len(parts),'grip_origin':[0,0,0],
    'gltf_forward_axis':'X','gltf_up_axis':'Y','gltf_muzzle':[.169,.055,0],
    'scope':'Native detailed prop; hand contact, runtime muzzle and all facing validation pending.'},indent=2))
