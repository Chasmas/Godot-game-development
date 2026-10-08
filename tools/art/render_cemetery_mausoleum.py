"""Authored funerary architecture candidate; review before gameplay placement."""
from pathlib import Path
import bpy, math, random
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(1988)
def material(name,color,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;b=n.get('Principled BSDF')
 b.inputs['Base Color'].default_value=(*color,1);b.inputs['Roughness'].default_value=.78;b.inputs['Metallic'].default_value=metal
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=14;noise.inputs['Detail'].default_value=5
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(*[x*.65 for x in color],1);ramp.color_ramp.elements[1].color=(*color,1)
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.22;bump.inputs['Distance'].default_value=.018
 l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],b.inputs['Base Color']);l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],b.inputs['Normal'])
 return m
stone=material('aged limestone',(.38,.4,.35));dark=material('recess and joints',(.025,.031,.028));iron=material('blackened iron',(.06,.07,.065),.75);moss=material('moss in wet joints',(.07,.12,.04));bronze=material('tarnished bronze',(.23,.15,.065),.65)
def box(name,p,s,ma):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=name;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(ma)
 be=o.modifiers.new('worn edge bevel','BEVEL');be.width=.018;be.segments=3;return o
def cylinder(name,p,r,h,ma):
 bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=h,location=p);o=bpy.context.object;o.name=name;o.data.materials.append(ma);be=o.modifiers.new('stone edge','BEVEL');be.width=.009;be.segments=2;return o
for i in range(3):box('broad entry step',(0,-.6-i*.19,.055+i*.08),(2.6-i*.12,2.0-i*.12,.11),stone)
# Masonry courses, staggered joints and a recessed iron doorway.
box('dark masonry core',(0,.1,1.08),(2.25,1.55,1.85),dark)
for row in range(6):
 for side in [-1,1]:
  for depth in range(4):box('side ashlar block',(side*1.11,-.46+depth*.37,.34+row*.29),(.2,.355,.277),stone)
 for side in [-1,1]:box('facade ashlar pier',(side*.79,-.7,.34+row*.29),(.56,.18,.277),stone)
box('door recessed panel',(0,-.696,1.04),(1.01,.035,1.54),iron)
for x in [-.52,.52]:box('carved door surround',(x,-.77,1.06),(.12,.18,1.75),stone)
box('lintel',(0,-.76,1.94),(1.22,.23,.15),stone)
for x in [-.37,-.19,0,.19,.37]:box('iron door ribs',(x,-.729,1.04),(.018,.02,1.45),bronze)
for z in [.54,1.12,1.61]:box('door cross rail',(0,-.735,z),(.95,.025,.026),iron)
for x in [-.075,.075]:
 bpy.ops.mesh.primitive_torus_add(major_radius=.036,minor_radius=.006,location=(x,-.758,1.05),rotation=(math.pi/2,0,0));bpy.context.object.data.materials.append(bronze)
for x in [-.93,.93]:
 box('column plinth',(x,-.95,.27),(.34,.34,.17),stone)
 cylinder('column base',(x,-.95,.40),.16,.10,stone)
 cylinder('column shaft',(x,-.95,1.10),.105,1.32,stone)
 for i in range(12):
  a=i*math.tau/12;cylinder('fine column fluting',(x+math.cos(a)*.099,-.95+math.sin(a)*.099,1.10),.010,1.26,stone)
 cylinder('capital collar',(x,-.95,1.81),.15,.12,stone)
 box('capital slab',(x,-.95,1.90),(.35,.35,.09),stone)
box('cornice',(0,.05,2.04),(2.57,1.9,.16),stone)
verts=[(-1.3,y,2.12) for y in [-.95,.99]]+[(1.3,y,2.12) for y in [-.95,.99]]+[(0,y,2.77) for y in [-.95,.99]]
mesh=bpy.data.meshes.new('pediment');mesh.from_pydata(verts,[],[(0,2,4),(1,5,3),(0,1,3,2),(0,4,5,1),(2,3,5,4)]);mesh.materials.append(stone)
o=bpy.data.objects.new('gable pediment',mesh);bpy.context.collection.objects.link(o)
for side in [-1,1]:
 trim=box('sloping pediment moulding',(side*.65,-.99,2.46),(1.48,.14,.09),stone);trim.rotation_euler.y=side*math.atan(.65/1.3)
 for course in range(4):
  x=side*(.17+course*.32)
  for tile in range(7):
   y=-.84+tile*.275
   roof=box('individual weathered roof slate',(x,y,2.80-abs(x)*.5),(.35,.264,.033),stone)
   roof.rotation_euler.y=side*math.atan(.5)
box('pediment cross vertical',(0,-1.012,2.43),(.046,.018,.30),bronze);box('pediment cross horizontal',(0,-1.019,2.46),(.20,.018,.045),bronze)
for i in range(18):
 x=rng.uniform(-1.16,1.16);box('moss along stone foot',(x,rng.uniform(-.81,.77),.24),(.08,.06,.025),moss)
bpy.ops.object.text_add(location=(0,-1.034,2.13),rotation=(math.pi/2,0,0));o=bpy.context.object;o.data.body='ESTRELLA';o.data.align_x='CENTER';o.data.size=.12;o.data.extrude=.002;o.data.materials.append(dark)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=48;sc.render.resolution_x=768;sc.render.resolution_y=768;sc.render.resolution_percentage=100;sc.render.film_transparent=True
sc.world=bpy.data.worlds.new('neutral review');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[1].default_value=.4
for p,e in [((-3,-4,6),550),((3,2,5),250)]:
 bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=e;o.data.size=4;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-8,9));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.7;sc.camera=cam
out=ROOT/'build/cemetery_prop_review';out.mkdir(parents=True,exist_ok=True);sc.render.filepath=str(out/'mausoleum_v1.png');bpy.ops.wm.save_as_mainfile(filepath=str(out/'mausoleum_v1.blend'));bpy.ops.render.render(write_still=True)
