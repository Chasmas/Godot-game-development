"""Authored shelf/books/flowers study; preserve v19 and gameplay geometry."""
from pathlib import Path
import bpy, json, math
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging'
OUT = BASE / 'room_101_v20'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'room_101_v19/room_101.blend'))
wood = bpy.data.materials['101 walnut']
paper = bpy.data.materials['101 cream paper']
def material(name, color, roughness=.65):
    m = bpy.data.materials.new(name); m.use_nodes = True
    shader = m.node_tree.nodes['Principled BSDF']
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    return m
brass = material('101 aged shelf brass', (.31,.20,.07), .35)
green = material('101 eucalyptus leaves', (.07,.14,.085))
ceramic = material('101 glazed ochre vase', (.38,.19,.08), .25)
petal = material('101 faded cream flowers', (.76,.61,.43))
def box(name, pos, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    o=bpy.context.object; o.name=name; o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    b=o.modifiers.new('Worn edges','BEVEL'); b.width=.004; b.segments=3
    return o
def stem(name, a, b, radius=.004):
    direction=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=radius,depth=direction.length,location=(Vector(a)+Vector(b))*.5)
    o=bpy.context.object; o.name=name; o.rotation_euler=direction.to_track_quat('Z','Y').to_euler(); o.data.materials.append(green)
def ellipsoid(name, pos, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=pos)
    o=bpy.context.object; o.name=name; o.scale=scale; o.data.materials.append(mat)
    for face in o.data.polygons: face.use_smooth=True
    return o
# One shallow shelf over free wall space, away from door and window openings.
box('101 walnut book shelf',(4.35,-.15,1.35),(1.0,.26,.035),wood)
for x in (3.96,4.74):
    box('101 shelf brass wall plate',(x,-.02,1.27),(.025,.02,.16),brass)
    box('101 shelf brass support',(x,-.14,1.325),(.025,.24,.018),brass)
colors=[(.17,.08,.055),(.11,.17,.15),(.29,.20,.10),(.12,.12,.19),(.30,.12,.10)]
for i in range(7):
    x=3.94+i*.052; height=.20+(i%3)*.025; width=.042
    jacket=material('101 cloth book binding %d'%i,colors[i%len(colors)])
    box('101 book page block %d'%i,(x,-.13,1.372+height*.5),(width-.008,.15,height-.012),paper)
    for dx in (-width*.5,width*.5):box('101 book cover %d'%i,(x+dx,-.13,1.372+height*.5),(.004,.16,height),jacket)
    box('101 book spine %d'%i,(x,-.214,1.372+height*.5),(width,.012,height),jacket)
    for z in (1.40,1.372+height-.025):box('101 spine gold tooling',(x,-.222,z),(width*.7,.002,.003),brass)
    box('101 spine title label',(x,-.222,1.41+height*.35),(width*.65,.002,.025),paper)
# Lathed ceramic vase with an open lip, rather than a solid primitive cylinder.
profile=[(.038,0),(.065,.02),(.078,.08),(.065,.14),(.031,.19),(.033,.22),(.025,.22),(.024,.19),(.056,.13),(.060,.07),(.028,.02)]
vertices=[]; faces=[]; count=40
for radius,z in profile:
    for i in range(count):
        angle=i*math.tau/count; vertices.append((4.64+radius*math.cos(angle),-.14+radius*math.sin(angle),1.37+z))
for row in range(len(profile)-1):
    for i in range(count):
        j=row*count+i; k=row*count+(i+1)%count; faces.append((j,k,k+count,j+count))
mesh=bpy.data.meshes.new('101 hollow vase mesh'); mesh.from_pydata(vertices,[],faces); mesh.update()
vase=bpy.data.objects.new('101 hollow glazed vase',mesh); bpy.context.collection.objects.link(vase); vase.data.materials.append(ceramic)
for face in mesh.polygons:face.use_smooth=True
for i in range(5):
    angle=i*math.tau/5; tip=(4.64+.075*math.cos(angle),-.14+.045*math.sin(angle),1.75+(i%2)*.045)
    stem('101 flower stem',(4.64,-.14,1.55),tip)
    for side in (-1,1):
        leaf=ellipsoid('101 eucalyptus leaf',(4.64+side*.035,-.14,1.64+i*.015),(.036,.010,.018),green)
        leaf.rotation_euler.y=side*.5
    ellipsoid('101 flower centre',tip,(.013,.013,.012),brass)
    for j in range(5):
        a=j*math.tau/5
        flower=ellipsoid('101 flower petal',(tip[0]+.018*math.cos(a),tip[1]+.018*math.sin(a),tip[2]),(.025,.012,.008),petal)
        flower.rotation_euler.z=a
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'room_101.blend'))
scene=bpy.context.scene;scene.cycles.samples=24
for o in scene.objects:
    if o.name.startswith(('101 south wall','101 wall above window','101 entrance lintel')):o.hide_render=True
scene.render.filepath=str(OUT/'room_101_cutaway.png');bpy.ops.render.render(write_still=True)
(OUT/'review.json').write_text(json.dumps({'runtime_approved':False,'source':'room_101_v19','added':'Shallow walnut shelf, seven bound books, hollow ceramic vase, eucalyptus and five flowers','physics_changed':False,'pending':['Visual reference-quality review','Shelf wall/actor sightlines','Reconcile staged cabinet scale with current production composite','Full-map camera and environment integration']},indent=2))
print('M01 ROOM101 DRESSING STUDY BUILT')
