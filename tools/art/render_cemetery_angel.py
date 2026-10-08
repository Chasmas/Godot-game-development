"""Mourning angel sculpture candidate with modelled drapery and feather relief."""
from pathlib import Path
source=(Path(__file__).parent/'render_cemetery_mausoleum.py').read_text()
exec(compile(source.split('for i in range(3):')[0],__file__,'exec'))
def ellipsoid(name,p,s,ma=stone):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=p);o=bpy.context.object;o.name=name;o.scale=s;o.data.materials.append(ma)
 for face in o.data.polygons:face.use_smooth=True
 return o
def limb(name,a,b,r):
 mid=(Vector(a)+Vector(b))*.5;o=ellipsoid(name,mid,(r,r,(Vector(b)-Vector(a)).length*.5+r*.4));o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler();return o
box('broad funerary footing',(0,0,.08),(.95,.85,.16),stone)
box('pedestal lower moulding',(0,0,.22),(.78,.69,.12),stone)
box('inscribed pedestal',(0,0,.48),(.66,.59,.43),stone)
box('pedestal upper moulding',(0,0,.74),(.79,.70,.12),stone)
# One continuous skirt surface: fluted folds vary with height and gather at waist.
verts=[];faces=[];segments=80;rings=28
for row in range(rings):
 t=row/(rings-1);z=.80+t*1.20;radius=.35*(1-t)+.16*t
 for j in range(segments):
  a=j*math.tau/segments;fold=.028*math.sin(a*13+t*.8)*(1-.35*t)
  verts.append(((radius+fold)*math.cos(a),(radius*.65+fold)*math.sin(a),z))
for row in range(rings-1):
 for j in range(segments):faces.append((row*segments+j,row*segments+(j+1)%segments,(row+1)*segments+(j+1)%segments,(row+1)*segments+j))
mesh=bpy.data.meshes.new('continuous carved drapery');mesh.from_pydata(verts,[],faces);mesh.materials.append(stone)
o=bpy.data.objects.new('folded stone robe',mesh);bpy.context.collection.objects.link(o)
for p in mesh.polygons:p.use_smooth=True
ellipsoid('robed chest',(0,0,2.05),(.20,.135,.28))
ellipsoid('neck',(0,-.015,2.32),(.068,.067,.10))
head=ellipsoid('bowed head',(0,-.065,2.47),(.13,.12,.17));head.rotation_euler.x=.25
ellipsoid('hair mantle',(0,.01,2.50),(.142,.105,.17))
ellipsoid('carved nose',(0,-.180,2.45),(.020,.026,.041))
for side in [-1,1]:
 ellipsoid('lowered eyelid',(side*.048,-.178,2.48),(.027,.010,.008))
 limb('upper sleeve',(side*.17,-.01,2.14),(side*.27,-.11,1.92),.075)
 limb('forearm',(side*.27,-.11,1.92),(side*.05,-.21,2.08),.049)
 ellipsoid('folded praying hand',(side*.035,-.224,2.11),(.036,.036,.10))
 for i in range(13):
  t=i/12
  root=(side*(.14+.22*t),.09,2.19+.21*math.sin(t*math.pi))
  tip=(side*(.43+.32*t),.13,1.62+.72*t)
  limb('overlapping carved wing feather',root,tip,.045-.017*t)
 for i in range(8):ellipsoid('sculpted hair wave',((i-3.5)*.027,.055,2.46),(.025,.065,.16))
for i in range(10):
 x=rng.uniform(-.32,.32);ellipsoid('moss on pedestal',(x,-.29,.29),(.034,.009,.016),moss)
bpy.ops.object.text_add(location=(0,-.301,.48),rotation=(math.pi/2,0,0));o=bpy.context.object;o.data.body='REQUIEM';o.data.align_x='CENTER';o.data.size=.07;o.data.extrude=.001;o.data.materials.append(dark)
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=64;sc.render.resolution_x=768;sc.render.resolution_y=768;sc.render.resolution_percentage=100;sc.render.film_transparent=True
sc.world=bpy.data.worlds.new('neutral sculpture review');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[1].default_value=.4
for p,e in [((-3,-4,6),500),((3,2,5),250)]:
 bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=e;o.data.size=4;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-8,9));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.2))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.4;sc.camera=cam
out=ROOT/'build/cemetery_prop_review';out.mkdir(parents=True,exist_ok=True);sc.render.filepath=str(out/'angel_v1.png');bpy.ops.wm.save_as_mainfile(filepath=str(out/'angel_v1.blend'));bpy.ops.render.render(write_still=True)
