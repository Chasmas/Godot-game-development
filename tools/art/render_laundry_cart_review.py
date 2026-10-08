"""Isolated Blender prop review; never changes runtime assets or level layout."""
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'tools/art/build_m01_interiors.py'
ns={'__file__':str(source),'__name__':'prop_review_helpers'}
exec(compile(source.read_text().split("zone('North guest wing'")[0],str(source),'exec'),ns)
mb=ns['MB'];m=ns['M']
import math
canvas=ns['mat']('laundry canvas',(.28,.23,.16),rough=.92)
ns['add_surface_variation'](canvas,95,.025)
rubber=ns['mat']('caster rubber',(.018,.022,.025),rough=.85)
thread=ns['mat']('canvas seams',(.25,.22,.16),rough=.95)
# Open fabric basket: thin walls instead of a solid opaque block.
mb.box((0,0,.22),(.35,.23,.018),m['metal'])
for y in [-.235,.235]:
 # A suspended canvas bag tapers at the bottom and bows under the linen load.
 verts=[];faces=[];nu=24;nv=16;side=1 if y>0 else -1
 for a in range(nu+1):
  for b in range(nv+1):
   u=a/nu;v=b/nv
   bulge=.034*math.sin(math.pi*u)*math.sin(math.pi*v)
   crease=.008*math.sin(u*math.pi*8)*math.sin(math.pi*v)
   verts.append(((u*2-1)*(.28+.06*v),y+side*(bulge+crease),.25+.41*v-.022*math.sin(math.pi*u)*v**6))
 for a in range(nu):
  for b in range(nv):
   k=a*(nv+1)+b;faces.append((k,k+nv+1,k+nv+2,k+1))
 mesh=bpy.data.meshes.new('loaded canvas panel');mesh.from_pydata(verts,[],faces);mesh.materials.append(canvas)
 ob=bpy.data.objects.new('bowed canvas basket',mesh);bpy.context.collection.objects.link(ob)
 for p in mesh.polygons:p.use_smooth=True
 solid=ob.modifiers.new('canvas thickness','SOLIDIFY');solid.thickness=.006
 for x in [-.3,.3]: mb.cyl((x,y-.014,.26),(x,y-.014,.64),.005,thread,8)
 for x in [-.32,.32]: mb.cyl((x,y,.21),(x,y,.68),.016,m['chrome'],12)
 mb.cyl((-.34,y,.66),(.34,y,.66),.012,m['chrome'],12)
 mb.cyl((-.34,y,.21),(.34,y,.21),.014,m['chrome'],12)
 for x in [-.3,.3]:
  mb.box((x,y+side*.008,.62),(.013,.006,.045),thread)
for x in [-.345,.345]:
 # Side cloth bows under the load too; no rigid rectangular end panel.
 side=1 if x>0 else -1;verts=[];faces=[];nu=18;nv=16
 for a in range(nu+1):
  for b in range(nv+1):
   u=a/nu;v=b/nv
   sag=math.sin(math.pi*u)*math.sin(math.pi*v)
   px=x+side*(.028*sag+.005*math.sin(u*math.pi*6)*math.sin(math.pi*v))
   py=(u*2-1)*(.185+.05*v)
   pz=.25+.41*v-.016*math.sin(math.pi*u)*v**6
   verts.append((px,py,pz))
 for a in range(nu):
  for b in range(nv):
   k=a*(nv+1)+b;faces.append((k,k+nv+1,k+nv+2,k+1))
 mesh=bpy.data.meshes.new('side canvas folds');mesh.from_pydata(verts,[],faces);mesh.materials.append(canvas)
 ob=bpy.data.objects.new('loaded soft basket side',mesh);bpy.context.collection.objects.link(ob)
 for polygon in mesh.polygons:polygon.use_smooth=True
 solid=ob.modifiers.new('side cloth thickness','SOLIDIFY');solid.thickness=.006
 for y in [-.205,.205]:
  mb.cyl((x+side*.004,y,.3),(x+side*.004,y,.63),.004,thread,8)
 mb.cyl((x,-.235,.66),(x,.235,.66),.012,m['chrome'],12)
# Rounded folded bundles: thickness and broad folds remain legible after scaling.
for i,(x,y,z,w,d) in enumerate([(-.16,-.04,.64,.15,.15),(.15,.07,.65,.14,.14),(-.1,.1,.7,.17,.1),(.15,-.11,.71,.13,.1)]):
 fabric=ns['mat']('towel '+str(i),[(.75,.71,.61),(.25,.42,.43),(.84,.8,.7),(.56,.59,.53)][i],rough=.98)
 ns['add_surface_variation'](fabric,120,.025)
 for layer in range(2):
  bpy.ops.mesh.primitive_cube_add(size=1,location=(x,y,z+layer*.037))
  bundle=bpy.context.object;bundle.name='rounded folded linen';bundle.dimensions=(w*2,d*2,.038)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bundle.data.materials.append(fabric);bundle.rotation_euler.z=(i-1)*.13
  bevel=bundle.modifiers.new('soft fabric corners','BEVEL');bevel.width=.018;bevel.segments=4
  # Subdivided soft folds make each bundle irregular rather than a bevelled box.
  bpy.context.view_layer.objects.active=bundle
  bpy.ops.object.modifier_apply(modifier=bevel.name)
  subdiv=bundle.modifiers.new('cloth fold surface','SUBSURF');subdiv.subdivision_type='SIMPLE';subdiv.levels=2
  bpy.ops.object.modifier_apply(modifier=subdiv.name)
  for vertex in bundle.data.vertices:
   vx,vy,vz=vertex.co
   weight=max(0.0,1.0-abs(vx)/w)*max(0.0,1.0-abs(vy)/d)
   vertex.co.z += .008*weight*math.sin(vx*22+i+layer*.7)+.003*math.sin(vy*31+i)*weight
  bundle.modifiers.new('weighted fabric normals','WEIGHTED_NORMAL')
 for edge in [-1,1]: mb.cyl((x-w+.02,y+edge*d,z+.038),(x+w-.02,y+edge*d,z+.038),.006,thread,8)
 # A looser top sheet has broad creases, curled edges and visible thickness.
 verts=[];faces=[];nx=16;ny=10
 for a in range(nx+1):
  for b in range(ny+1):
   px=x-w+2*w*a/nx;py=y-d+2*d*b/ny
   crease=.025*math.sin(a*.65+i)*math.sin(math.pi*b/ny)
   curl=.025*(abs(2*b/ny-1)**5)
   verts.append((px,py,z+.065+crease+curl))
 for a in range(nx):
  for b in range(ny):
   k=a*(ny+1)+b;faces.append((k,k+ny+1,k+ny+2,k+1))
 mesh=bpy.data.meshes.new('cloth folds');mesh.from_pydata(verts,[],faces);mesh.materials.append(fabric)
 ob=bpy.data.objects.new('draped towel',mesh);bpy.context.collection.objects.link(ob)
 for p in mesh.polygons:p.use_smooth=True
 solid=ob.modifiers.new('cloth thickness','SOLIDIFY');solid.thickness=.006
 hem=ns['mat']('woven towel hem '+str(i),[(.48,.43,.35),(.16,.31,.32),(.6,.56,.46),(.35,.39,.33)][i],rough=.98)
 for edge in [-1,1]:
  points=[]
  for a in range(17):
   px=x-w+2*w*a/16;py=y+edge*(d-.014)
   crease=.025*math.sin(a*.65+i)*math.sin(math.pi*(py-y+d)/(2*d))
   curl=.025*(abs((py-y)/d)**5)
   points.append((px,py,z+.068+crease+curl))
  for a in range(16):mb.cyl(points[a],points[a+1],.0025,hem,6)
# A darker towel spilling over the front lip breaks the rigid basket silhouette.
spill=ns['mat']('teal draped towel',(.12,.28,.3),rough=.97)
ns['add_surface_variation'](spill,110,.03)
verts=[];faces=[];nx=20;ny=24
for a in range(nx+1):
 for b in range(ny+1):
  t=b/ny;px=-.23+.26*a/nx
  py=-.08-.22*min(t*2,1)-.016*math.sin(a*.8)*max(0,t-.5)*2
  pz=.79-.06*min(t*2,1)-.36*max(0,t-.5)*2+.018*math.sin(a*.7)*(1-.3*t)
  verts.append((px,py,pz))
for a in range(nx):
 for b in range(ny):
  k=a*(ny+1)+b;faces.append((k,k+ny+1,k+ny+2,k+1))
mesh=bpy.data.meshes.new('hanging cloth folds');mesh.from_pydata(verts,[],faces);mesh.materials.append(spill)
ob=bpy.data.objects.new('towel over basket rim',mesh);bpy.context.collection.objects.link(ob)
for p in mesh.polygons:p.use_smooth=True
solid=ob.modifiers.new('towel thickness','SOLIDIFY');solid.thickness=.008
for x in [-.32,.32]:
 for y in [-.2,.2]:
  mb.cyl((x-.025,y,.08),(x+.025,y,.08),.075,rubber,16)
  mb.cyl((x-.027,y,.08),(x+.027,y,.08),.025,m['chrome'],12)
  for fork in [-.027,.027]: mb.box((x+fork,y,.135),(.008,.018,.055),m['chrome'])
for x in [-.38,.38]:
 mb.cyl((x,.26,.35),(x,.26,.83),.018,m['chrome'],12)
mb.cyl((-.38,.26,.83),(.38,.26,.83),.018,m['chrome'],12)
mb.build(bevel=.008)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=32
sc.render.resolution_x=256;sc.render.resolution_y=256;sc.render.resolution_percentage=100;sc.render.film_transparent=True
sc.world=bpy.data.worlds.new('Neutral prop review');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.35,.38,.45,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.45
for loc,power,span in [((-3,-4,6),350,2),((3,2,4),180,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=span;o.rotation_euler=(Vector((0,0,.4))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-5,8));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.4))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.3;sc.camera=cam
out=ROOT/'build/blender_prop_review';out.mkdir(parents=True,exist_ok=True)
sc.render.filepath=str(out/'laundry_cart_v6.png');bpy.ops.wm.save_as_mainfile(filepath=str(out/'laundry_cart_v6.blend'));bpy.ops.render.render(write_still=True)
