"""Guest-room ashtray and bottle clutter; existing ImageGen references, Blender geometry."""
from pathlib import Path
import bpy, math, json, hashlib, random
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/guest_clutter_v1'
OUT.mkdir(parents=True,exist_ok=True)
REFS={'clutter_ashtray':ROOT/'assets/art/materials/m01/batch_v1/ashtray_reference.png',
      'clutter_bottles':ROOT/'assets/art/materials/m01/batch_v1/bottle_weapon_reference.png'}
ROOM_REF=ROOT/'assets/art/materials/m01/batch_v1/guest_room_rebuild_direction_v2.png'
assert ROOM_REF.exists() and all(p.exists() for p in REFS.values())
rng=random.Random(1988)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,color,metal=0,rough=.4,trans=0,ior=1.5,emit=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    p.inputs['Transmission Weight'].default_value=trans;p.inputs['IOR'].default_value=ior
    if emit:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
    return m
def lathe(name,profile,m,segments=64,notch=None):
    """Revolve (radius,z) profile into a hollow shell. notch(angle,z)->dz lowers rim cuts."""
    verts=[];faces=[];N=segments
    for r,z in profile:
        for i in range(N):
            a=i*math.tau/N;dz=notch(a,z) if notch else 0
            verts.append((r*math.cos(a),r*math.sin(a),z+dz))
    for k in range(len(profile)-1):
        for i in range(N):faces.append((k*N+i,k*N+(i+1)%N,(k+1)*N+(i+1)%N,(k+1)*N+i))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    for poly in mesh.polygons:poly.use_smooth=True
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(m);return o
def cyl(name,loc,r,depth,m,rot=(0,0,0),verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc,rotation=rot)
    o=bpy.context.object;o.name=name;o.data.materials.append(m);bpy.ops.object.shade_smooth();return o
def stage(width):
    s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=96;s.cycles.use_denoising=True
    s.render.resolution_x=128;s.render.resolution_y=128;s.render.resolution_percentage=100
    s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
    s.view_settings.look='AgX - Medium High Contrast'
    s.world=bpy.data.worlds.new('Guest-room ambient');s.world.color=(.12,.11,.10)
    # Same three-quarter top-down orthographic camera as the guest ice-bucket batch.
    bpy.ops.object.camera_add(location=(0,-2.8,3.35));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=width
    cam.rotation_euler=(Vector((0,0,.08))-cam.location).to_track_quat('-Z','Y').to_euler();s.camera=cam
    for loc,col,energy in [((-2,-2,3),(.65,.8,1),120),((2,1,2),(1,.55,.25),110),((0,2.5,2.5),(1,.85,.7),60)]:
        bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=energy;light.data.color=col;light.data.size=3
        light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
    return s

def build_ashtray():
    reset()
    amber=mat('Amber pressed glass',(.62,.27,.04),0,.12,.55,1.52)
    amber_rim=mat('Smoked amber rim',(.40,.15,.025),0,.2,.3,1.52)
    ash=mat('Grey cigarette ash',(.16,.15,.14),0,.95)
    paper=mat('Cigarette paper',(.80,.77,.68),0,.8)
    cork=mat('Cork filter tipping',(.70,.42,.18),0,.7)
    ember=mat('Burnt tip',(.05,.04,.035),0,.9)
    notches=[i*math.tau/4+.3 for i in range(4)]
    def notch(a,z):
        if z<.11:return 0
        d=min(abs((a-n+math.pi)%math.tau-math.pi) for n in notches)
        return -.045*max(0,1-d/.16)
    # Thick hollow glass: outer wall, flat rim, inner bowl and floor.
    lathe('Ashtray body',[(.30,.0),(.335,.02),(.35,.10),(.345,.125),(.265,.13),(.25,.06),(.0,.055)],amber,96,notch)
    lathe('Rim highlight band',[(.348,.122),(.34,.128),(.27,.13)],amber_rim,96,notch)
    # Pressed vertical flutes around the outside.
    for i in range(18):
        a=i*math.tau/18
        bpy.ops.mesh.primitive_cube_add(size=1,location=(.343*math.cos(a),.343*math.sin(a),.062),rotation=(0,0,a))
        o=bpy.context.object;o.dimensions=(.012,.03,.07);o.data.materials.append(amber)
    # Star-cut floor.
    for i in range(12):
        a=i*math.tau/12
        bpy.ops.mesh.primitive_cube_add(size=1,location=(.10*math.cos(a),.10*math.sin(a),.058),rotation=(0,0,a))
        o=bpy.context.object;o.dimensions=(.19,.012,.006);o.data.materials.append(amber_rim)
    for i in range(30):
        a=rng.random()*math.tau;r=rng.random()*.2
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.008+rng.random()*.012,location=(r*math.cos(a),r*math.sin(a),.065))
        o=bpy.context.object;o.scale.z=.45;o.data.materials.append(ash)
    for k,(x,y,ang,tilt) in enumerate([(-.06,-.03,.4,0),(.08,.06,-1.1,0),(.13,-.11,2.2,0),(-.15,.12,2.6,0)]):
        rot=(math.pi/2-tilt,0,ang);dirv=Vector((math.cos(ang+math.pi/2),math.sin(ang+math.pi/2),0))
        z=.075+tilt*.12
        cyl('Filter',(x,y,z),.018,.07,cork,rot,16)
        p=Vector((x,y,z))+dirv*.06;cyl('Crumpled paper',p,.0175,.05,paper,rot,16)
        e=Vector((x,y,z))+dirv*.088;cyl('Charred end',e,.017,.008,ember,rot,16)
    return 'ashtray.png'

def build_bottles():
    reset()
    green=mat('Bottle green glass',(.10,.42,.12),0,.08,.6,1.5)
    amber=mat('Brown beer glass',(.35,.14,.03),0,.08,.6,1.5)
    label=mat('Cream label with coral print',(.88,.72,.58),0,.75)
    coral=mat('Coral sunset ink',(.86,.36,.25),0,.7)
    foil=mat('Crimped steel cap',(.30,.24,.16),.8,.45)
    beer=mat('Last mouthful of lager',(.55,.30,.04),0,.1,.4,1.33)
    def bottle(glass,loc,rot,with_cap=False,fill=0.0):
        prof=[(.0,.0),(.075,.0),(.085,.015),(.085,.20),(.07,.27),(.035,.33),(.03,.43),(.036,.445),(.03,.46),(.026,.46)]
        o=lathe('Bottle',prof,glass,48)
        parts=[o]
        bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.087,depth=.09,location=(0,0,.11));lb=bpy.context.object;lb.data.materials.append(label);parts.append(lb)
        bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.0885,depth=.02,location=(0,0,.11));st=bpy.context.object;st.data.materials.append(coral);parts.append(st)
        if with_cap:
            bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.036,depth=.018,location=(0,0,.465));cp=bpy.context.object;cp.data.materials.append(foil);parts.append(cp)
        if fill>0:
            bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.07,depth=fill,location=(0,0,.01+fill/2));lq=bpy.context.object;lq.data.materials.append(beer);parts.append(lq)
        root=bpy.data.objects.new('Bottle root',None);bpy.context.collection.objects.link(root)
        for p in parts:p.parent=root
        root.location=loc;root.rotation_euler=rot;return root
    bottle(green,(-.17,.08,0),(0,0,0),False,.05)
    bottle(green,(.0,.14,0),(0,0,.6),True,.0)
    bottle(amber,(-.04,-.12,.086),(math.pi/2,0,1.75),False,.0)  # tipped over, resting on its side
    cap_mat=bpy.data.materials['Crimped steel cap']
    for x,y in [(.16,.02),(-.28,-.1)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=20,radius=.036,depth=.01,location=(x,y,.005));bpy.context.object.data.materials.append(cap_mat)
    return 'bottles.png'

variants={}
for cat,builder,width in [('clutter_ashtray',build_ashtray,.9),('clutter_bottles',build_bottles,1.0)]:
    name=builder();s=stage(width)
    s.render.filepath=str(OUT/name);bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/name.replace('.png','.blend')))
    variants[cat]=name
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':False,
 'source_level_sha256':hashlib.sha256((ROOT/'levels/m01_sunset_palms.json').read_bytes()).hexdigest(),
 'imagegen_reference':str(ROOM_REF.relative_to(ROOT)).replace('\\','/'),
 'object_references':{k:str(v.relative_to(ROOT)).replace('\\','/') for k,v in REFS.items()},
 'reference_role':'Existing ImageGen ashtray/bottle studies and approved guest-room palette direct the look; final assets are modeled in Blender.',
 'variants':variants,'expected_placements':12,'world_width_px':{'clutter_ashtray':9,'clutter_bottles':10},
 'scope':'Visual-only Decor replacement. Preserve original transforms, navigation and collision.'},indent=2)+'\n')
print('M01 GUEST CLUTTER RENDERED')
