"""Guest-room ice service props; approved ImageGen room palette, Blender geometry."""
from pathlib import Path
import bpy, math, json, hashlib, random
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/guest_ice_buckets_v1'
OUT.mkdir(parents=True,exist_ok=True)
REF=ROOT/'assets/art/materials/m01/batch_v1/guest_room_rebuild_direction_v2.png'
assert REF.exists()
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color,metal=0,rough=.4):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
steel=mat('Brushed stainless steel',(.34,.40,.44),.85,.3)
brass=mat('Aged champagne brass',(.43,.25,.08),.75)
wood=mat('Dark walnut hospitality tray',(.10,.035,.018),0,.65)
linen=mat('Cream cotton service napkin',(.72,.65,.49),0,.9)
ice=mat('Frosted cyan ice',(.45,.75,.79),.05,.21)
dark=mat('Bucket interior shadow',(.023,.028,.03),.6)
def box(name,loc,size,m,bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
    if bevel:b=o.modifiers.new('Rounded edges','BEVEL');b.width=bevel;b.segments=3
    return o
def torus(name,z,r,minor,m):
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=minor,major_segments=48,minor_segments=8,location=(0,0,z))
    o=bpy.context.object;o.name=name;o.data.materials.append(m);return o
box('Walnut tray',(0,0,.025),(.78,.66,.05),wood,.045)
for x in [-.37,.37]:box('Tray raised edge',(x,0,.065),(.035,.62,.06),wood)
for y in [-.31,.31]:box('Tray raised edge',(0,y,.065),(.74,.035,.06),wood)
box('Folded cotton napkin',(.10,0,.071),(.54,.47,.025),linen,.012)
# Hollow bucket wall: an open mesh with actual thickness and rim, not a solid cylinder.
verts=[];faces=[];N=64
for radius,z in [(.215,.10),(.26,.43),(.243,.43),(.20,.12)]:
    for i in range(N):
        a=i*math.tau/N;verts.append((radius*math.cos(a),radius*math.sin(a),z))
for layer in range(3):
    for i in range(N):faces.append((layer*N+i,layer*N+(i+1)%N,(layer+1)*N+(i+1)%N,(layer+1)*N+i))
mesh=bpy.data.meshes.new('Double wall bucket');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('Open stainless steel ice bucket',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(steel)
for poly in mesh.polygons:poly.use_smooth=True
torus('Rolled lip',.435,.251,.012,brass);torus('Base foot',.105,.215,.01,brass)
for z in [.17,.23,.29,.35]:torus('Fine brushed metal band',z,.215+(.26-.215)*(z-.10)/.33,.003,steel)
bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.20,depth=.012,location=(0,0,.123));bpy.context.object.data.materials.append(dark)
for x in [-.25,.25]:
    handle=torus('Brass handle',.33,.064,.01,brass);handle.location.x=x;handle.rotation_euler=(math.pi/2,0,0)
rng=random.Random(1988);ice_parts=[]
for i in range(13):
    a=rng.random()*math.tau;r=rng.random()*.16
    cube=box('Irregular frosted ice cube',(r*math.cos(a),r*math.sin(a),.34+rng.random()*.07),(.083,.075,.07),ice,.012)
    cube.rotation_euler=(rng.random()*.4,rng.random()*.4,a);ice_parts.append(cube)
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=128;s.render.resolution_y=128;s.render.resolution_percentage=100
s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.view_settings.look='AgX - Medium High Contrast'
s.world=bpy.data.worlds.new('Guest-room ambient');s.world.color=(.15,.15,.15)
bpy.ops.object.camera_add(location=(0,-2.8,3.35));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=1.0
cam.rotation_euler=(Vector((0,0,.15))-cam.location).to_track_quat('-Z','Y').to_euler();s.camera=cam
for loc,col,energy in [((-2,-2,3),(.65,.8,1),140),((2,1,2),(1,.55,.25),100)]:
    bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=energy;light.data.color=col;light.data.size=3
    light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
for full in [False,True]:
    for part in ice_parts:part.hide_render=not full
    s.render.filepath=str(OUT/('bucket_full.png' if full else 'bucket_empty.png'));bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'guest_ice_buckets.blend'))
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':False,'source_level_sha256':hashlib.sha256((ROOT/'levels/m01_sunset_palms.json').read_bytes()).hexdigest(),'imagegen_reference':str(REF.relative_to(ROOT)).replace('\\','/'),'reference_role':'Approved guest-room palette and hospitality styling; final asset is modeled in Blender.','variants':{'motel_ice_bucket':'bucket_empty.png','motel_ice_bucket_full':'bucket_full.png'},'expected_placements':3,'world_width_px':12,'scope':'Visual-only Decor replacement. Preserve original transforms, navigation and collision.'},indent=2)+'\n')
print('M01 GUEST ICE BUCKETS RENDERED')
