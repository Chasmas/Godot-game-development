"""Detailed burial plot candidate; staging only, no runtime replacement."""
from pathlib import Path
import math, random, os
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(1988)
STYLE=os.environ.get('CEMETERY_GRAVE_STYLE','arched')
def material(name,color,rough=.8):
 m=bpy.data.materials.new(name);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough
 noise=m.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=38;noise.inputs['Detail'].default_value=5
 ramp=m.node_tree.nodes.new('ShaderNodeValToRGB')
 ramp.color_ramp.elements[0].color=(*[v*.55 for v in color],1);ramp.color_ramp.elements[1].color=(*color,1)
 bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.28;bump.inputs['Distance'].default_value=.018
 m.node_tree.links.new(noise.outputs['Fac'],ramp.inputs['Fac']);m.node_tree.links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
 m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
 return m
stone=material('weathered limestone',(.42,.45,.39));soil=material('fresh damp burial earth',(.13,.075,.04));wax=material('aged ivory wax',(.72,.59,.38),.5);ink=material('dark inscription',(.035,.035,.028));moss=material('moss patches',(.12,.18,.07))
flame=material('warm candle flame',(1,.35,.035))
bs=flame.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(1,.3,.025,1);bs.inputs['Emission Strength'].default_value=4
def sphere(name,loc,scale,ma):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(ma)
 for p in o.data.polygons:p.use_smooth=True
 return o
def cube(name,loc,scale,ma):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(ma)
 mod=o.modifiers.new('worn bevel','BEVEL');mod.width=.012;mod.segments=3
 return o
sphere('uneven burial mound',(0,.55,.025),(.4,.77,.075),soil)
profile=[(-.28,.07),(.28,.07)]+[(.28*math.cos(i*math.pi/24),.62+.28*math.sin(i*math.pi/24)) for i in range(25)]
if STYLE=='pointed':profile=[(-.28,.07),(.28,.07),(.28,.68),(0,1.02),(-.28,.68)]
elif STYLE=='broken':profile=[(-.28,.07),(.28,.07),(.28,.65),(.16,.70),(.09,.58),(-.02,.69),(-.14,.61),(-.28,.73)]
n=len(profile);verts=[(x,y,z) for y in [-.09,.09] for x,z in profile]
faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
mesh=bpy.data.meshes.new('arched headstone');mesh.from_pydata(verts,[],faces);mesh.materials.append(stone)
ob=bpy.data.objects.new('arched limestone headstone',mesh);bpy.context.collection.objects.link(ob)
bevel=ob.modifiers.new('soft chipped stone edges','BEVEL');bevel.width=.013;bevel.segments=3
cube('stone foot',(0,0,.065),(.68,.3,.13),stone)
def strand(name,points,radius,ma):
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=2
 spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
 for p,co in zip(spline.points,points):p.co=(*co,1)
 ob=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(ob);ob.data.materials.append(ma)
 return ob
# Raised inset border, damaged face and segmented burial edging carry detail
# at gameplay scale; micro-noise alone disappears when the sprite is reduced.
border=[(-.22,-.108,.18),(-.22,-.108,.59)]+[(.22*math.cos(math.pi-i*math.pi/24),-.108,.59+.22*math.sin(math.pi-i*math.pi/24)) for i in range(25)]+[(.22,-.108,.18),(-.22,-.108,.18)]
if STYLE=='pointed':border=[(-.22,-.108,.18),(-.22,-.108,.65),(0,-.108,.92),(.22,-.108,.65),(.22,-.108,.18),(-.22,-.108,.18)]
elif STYLE=='broken':border=[(-.22,-.108,.53),(-.22,-.108,.18),(.22,-.108,.18),(.22,-.108,.53)]
strand('carved inset border',border,.007,stone)
for points in [[(-.19,.75),(-.14,.69),(-.16,.62),(-.10,.57)],[(.25,.35),(.18,.30),(.19,.24)]]:
 strand('hairline stone fracture',[(x,-.111,z) for x,z in points],.0025,ink)
for side in [-1,1]:
 for i in range(7):
  block=cube('sunken burial edging',(side*.43,.22+i*.155,.035),(.065,.145,.075),stone);block.rotation_euler.z=rng.uniform(-.06,.06)
for i in range(5):cube('burial foot edging',(-.34+i*.17,1.3,.035),(.16,.065,.075),stone)
petal=material('faded funeral rose',(.36,.055,.09),.85)
for i in range(5):
 x=-.12+i*.045;y=.32+rng.uniform(-.035,.035)
 strand('laid flower stem',[(x+.08,y+.35,.085),(x,y,.09)],.004,moss)
 for j in range(5):
  a=j*math.tau/5;sphere('wilted rose petal',(x+math.cos(a)*.019,y+math.sin(a)*.019,.10),(.018,.013,.008),petal)
for text,z,size in [('IN MEMORY',.48 if STYLE=='broken' else .60,.048),('1988',.34 if STYLE=='broken' else .42,.065)]:
 bpy.ops.object.text_add(location=(0,-.105,z),rotation=(math.pi/2,0,0));o=bpy.context.object;o.name='weathered inscription';o.data.body=text;o.data.align_x='CENTER';o.data.size=size;o.data.extrude=.0008;o.data.materials.append(ink)
for i in range(28):
 x=rng.uniform(-.36,.36);y=rng.uniform(.15,1.2)
 sphere('soil clod',(x,y,.03),(.025*rng.uniform(.6,1.4),.035,.018),soil)
for x,y,height in [(-.22,-.18,.17),(.23,-.15,.12),(.30,.12,.21)]:
 bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=.035,depth=height,location=(x,y,height/2+.04));o=bpy.context.object;o.name='part burned candle';o.data.materials.append(wax)
 for a in [.2,1.6,3.4,4.7]:
  sphere('wax drip',(x+math.cos(a)*.034,y+math.sin(a)*.034,height*.62),(.009,.009,.032),wax)
 cube('charred wick',(x,y,height+.045),(.005,.005,.018),ink)
 sphere('candle flame',(x,y,height+.071),(.012,.012,.025),flame)
for i in range(6): sphere('moss at stone foot',(rng.uniform(-.27,.27),rng.uniform(-.09,.09),.13),(.045,.018,.012),moss)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=48;sc.render.resolution_x=512;sc.render.resolution_y=512;sc.render.resolution_percentage=100;sc.render.film_transparent=True
world=bpy.data.worlds.new('neutral cemetery review');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.28,.32,.4,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45;sc.world=world
for loc,power,span in [((-3,-4,6),350,3),((3,2,4),180,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=span;o.rotation_euler=(Vector((0,.4,.3))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-6,7.2));cam=bpy.context.object;cam.rotation_euler=(Vector((0,.35,.3))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.05;sc.camera=cam
out=ROOT/'build/cemetery_prop_review';out.mkdir(parents=True,exist_ok=True)
name='grave_v2' if STYLE=='arched' else 'grave_'+STYLE
sc.render.filepath=str(out/(name+'.png'));bpy.ops.wm.save_as_mainfile(filepath=str(out/(name+'.blend')));bpy.ops.render.render(write_still=True)
