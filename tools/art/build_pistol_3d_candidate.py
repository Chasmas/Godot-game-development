"""Staged 1990s service pistol with explicit grip and muzzle anchors."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/weapons3d/staging/service_pistol_v3';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name,color,metal,rough):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
steel=material('Blued service steel',(.14,.17,.20),.55,.40)
grip=material('Black textured grip',(.025,.028,.031),0,.83)
dark=material('Bore shadow',(.003,.003,.004),0,1)
root=bpy.data.objects.new('ServicePistol',None);bpy.context.collection.objects.link(root)
def box(name,pos,size,mat,bevel=.002):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.parent=root;o.data.materials.append(mat)
    mod=o.modifiers.new('Machined edge','BEVEL');mod.width=bevel;mod.segments=3
    return o
box('Slide',(0,-.045,.078),(.029,.188,.031),steel)
box('Frame',(0,-.025,.055),(.026,.150,.018),steel)
handle=box('Grip',(0,.025,.008),(.027,.037,.093),grip,.004);handle.rotation_euler.x=math.radians(-12)
for side in [-1,1]:
    for i in range(9):box('Grip traction rib',(side*.014,.019,-.025+i*.008),(.001,.024,.0015),grip,.0005)
    for i in range(7):box('Slide rear serration',(side*.015,.011+i*.004,.079),(.0015,.0014,.018),dark,.0003)
box('Front sight',(0,-.119,.097),(.004,.008,.005),steel,.0007)
for side in [-1,1]:box('Rear sight notch',(side*.005,.035,.097),(.004,.008,.005),steel,.0007)
box('Trigger guard front',(0,-.034,.028),(.011,.006,.036),steel)
box('Trigger guard bottom',(0,-.010,.012),(.011,.047,.005),steel)
box('Trigger',(0,-.006,.032),(.006,.006,.027),steel)
box('Ejection port',(.008,-.018,.094),(.012,.033,.001),dark,.0005)
box('Slide stop',(.016,.004,.057),(.003,.018,.006),steel)
# Open muzzle annulus and recessed bore, rather than a capped cylinder.
vertices=[];faces=[]
for depth,radius in [(-.143,.008),(-.143,.005),(-.129,.005)]:
    for i in range(32):
        angle=2*math.pi*i/32
        vertices.append((math.cos(angle)*radius,depth,.079+math.sin(angle)*radius))
for ring in range(2):
    for i in range(32):
        j=(i+1)%32
        faces.append((ring*32+i,ring*32+j,(ring+1)*32+j,(ring+1)*32+i))
mesh=bpy.data.meshes.new('Open barrel tube');mesh.from_pydata(vertices,[],faces);mesh.update()
tube=bpy.data.objects.new('Open barrel muzzle',mesh);bpy.context.collection.objects.link(tube);tube.parent=root
tube.data.materials.append(steel);tube.data.materials.append(dark)
for polygon in tube.data.polygons:polygon.material_index=0 if polygon.index<32 else 1
box('Deep bore shadow',(0,-.128,.079),(.010,.001,.010),dark,0)
for name,pos in [('Muzzle',(0,-.142,.079)),('GripAnchor',(0,.025,.015))]:
    marker=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(marker);marker.parent=root;marker.location=pos
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=900;scene.render.resolution_y=600;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Neutral studio');scene.world.color=(.2,.2,.2)
lamp=bpy.data.lights.new('Softbox','AREA');lamp.energy=35;lamp.size=.4
light=bpy.data.objects.new('Softbox',lamp);bpy.context.collection.objects.link(light);light.location=(.2,-.2,.4)
camera=bpy.data.objects.new('Review camera',bpy.data.cameras.new('Review camera'));bpy.context.collection.objects.link(camera)
camera.location=(.32,-.32,.24);camera.rotation_euler=(Vector((0,-.025,.04))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=.32;scene.camera=camera
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'service_pistol.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in [root]+list(root.children_recursive):o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'service_pistol.glb'),export_format='GLB',use_selection=True,export_apply=True)
scene.render.filepath=str(OUT/'review.png');bpy.ops.render.render(write_still=True)
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':False,'units':'metres','forward_blender':'-Y','muzzle':'Muzzle','grip_anchor':'GripAnchor','pending':['visual quality review','actual skeleton grip alignment','aim pose and recoil','laser barrel binding']},indent=2))
print('PISTOL CANDIDATE BUILT')
