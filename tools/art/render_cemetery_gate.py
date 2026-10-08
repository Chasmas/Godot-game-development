"""Iron cemetery gate candidate with masonry pillars and forged scrollwork."""
from pathlib import Path
# Reuse the reviewed stone/iron materials and bevelled mesh helpers only.
source=(Path(__file__).parent/'render_cemetery_mausoleum.py').read_text()
exec(compile(source.split('for i in range(3):')[0],__file__,'exec'))
def curve(name,points,ma,r=.013):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=3
 s=c.splines.new('POLY');s.points.add(len(points)-1)
 for p,co in zip(s.points,points):p.co=(*co,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(ma)
for side in [-1,1]:
 x=side*1.55
 box('pillar footing',(x,0,.12),(.64,.63,.24),stone)
 for row in range(7):box('weathered pillar course',(x,0,.34+row*.255),(.46,.46,.242),stone)
 box('pillar cap',(x,0,2.08),(.59,.58,.14),stone)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,radius=.16,location=(x,0,2.32));bpy.context.object.data.materials.append(stone)
 for z in [.35,1.65]:cylinder('iron hinge socket',(x-side*.24,-.10,z),.045,.12,iron)
 # Each leaf retains its frame and central latch rather than a flat grille.
 for xx in [side*.04,side*1.29]:box('gate vertical frame',(xx,-.08,.94),(.045,.07,1.8),iron)
 for z in [.20,.70,1.54]:box('gate cross rail',(side*.66,-.08,z),(1.28,.055,.035),iron)
 for j in range(8):
  xx=side*(.10+j*.165);h=1.70+.20*math.cos(abs(xx)*1.1)
  box('forged upright',(xx,-.08,h*.5),(.018,.025,h),iron)
  bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.041,radius2=0,depth=.115,location=(xx,-.08,h+.055));bpy.context.object.data.materials.append(iron)
 for cx in [.34,.94]:
  points=[]
  for i in range(40):
   a=i*math.tau*1.15/39;r=.14*(1-i/48)
   points.append((side*(cx+math.cos(a)*r),-.10,1.20+math.sin(a)*r))
  curve('hand forged scroll',points,iron,.010)
 box('gate latch',(side*.045,-.13,.92),(.08,.04,.12),bronze)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=48;sc.render.resolution_x=768;sc.render.resolution_y=768;sc.render.resolution_percentage=100;sc.render.film_transparent=True
sc.world=bpy.data.worlds.new('neutral gate review');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[1].default_value=.45
for p,e in [((-3,-4,6),550),((3,2,5),300)]:
 bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=e;o.data.size=4;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-8,9));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.6;sc.camera=cam
out=ROOT/'build/cemetery_prop_review';out.mkdir(parents=True,exist_ok=True);sc.render.filepath=str(out/'gate_v1.png');bpy.ops.wm.save_as_mainfile(filepath=str(out/'gate_v1.blend'));bpy.ops.render.render(write_still=True)
