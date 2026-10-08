"""Authored handheld consumable candidates; metres, Z-up. Runtime unchanged."""
import bpy, math, random, os
from mathutils import Vector
OUT=os.path.abspath('build/idle_consumables_candidate')
os.makedirs(OUT,exist_ok=True)
random.seed(41)
def mat(name,col,metal=0,rough=.4):
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*col,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
 return m
def mesh(name,verts,faces,material):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(material)
 for p in me.polygons:p.use_smooth=True
 return o
def cyl(name,r,depth,z,material):
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=depth,location=(0,0,z));o=bpy.context.object;o.name=name;o.data.materials.append(material)
 mod=o.modifiers.new('rolled edge','BEVEL');mod.width=.0012;mod.segments=3
 for p in o.data.polygons:p.use_smooth=True
 return o
def torus(name,major,minor,z,material):
 bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=16,major_radius=major,minor_radius=minor,location=(0,0,z));o=bpy.context.object;o.name=name;o.data.materials.append(material)
 for p in o.data.polygons:p.use_smooth=True
 return o
def text(body,size,pos,material):
 # Wrap glyphs onto the cylindrical label instead of a floating flat plate.
 radius=abs(pos[1]);mid=(len(body)-1)*.5
 for i,ch in enumerate(body):
  theta=(i-mid)*size*.62/radius+(math.pi if pos[1]>0 else 0)
  cu=bpy.data.curves.new(body+' glyph','FONT');cu.body=ch;cu.size=size;cu.align_x='CENTER';cu.align_y='CENTER';cu.extrude=.00004
  o=bpy.data.objects.new(body+' '+str(i),cu);bpy.context.collection.objects.link(o);o.location=(radius*math.sin(theta),-radius*math.cos(theta),pos[2]);o.rotation_euler=(math.pi/2,0,theta);o.data.materials.append(material)
 return o
def can():
 silver=mat('brushed aluminium',(.54,.59,.64),.85,.24);red=mat('cherry enamel',(.46,.014,.045),.35,.27);cream=mat('cream label',(1,.83,.5));dark=mat('recess',(.017,.012,.022),.1,.6)
 cyl('pressed can body',.032,.108,.054,red)
 cyl('recessed top',.029,.002,.110,silver);cyl('bottom foot',.028,.003,.001,silver)
 for z in [.005,.105,.111]:torus('rolled metal rim',.030,.0017,z,silver)
 # Face an opening and pull tab on the lid.
 o=cyl('opening',.006,.0006,.1113,dark);o.location.y=-.009;o.scale.y=1.45
 o=torus('pull tab',.006,.0012,.113,silver);o.scale.y=1.5;o.location.y=.005
 cyl('tab rivet',.0018,.001,.114,silver)
 for z in [.024,.09]:torus('label pinstripe',.0322,.0005,z,cream)
 text('NIGHT',.013,(0,-.0325,.069),cream);text('SHIFT',.013,(0,-.0325,.054),cream);text('CHERRY COLA',.005,(0,-.0327,.036),cream)
 # Smaller rear ingredient marks are actual surface geometry.
 for i in range(7):
  text('||| ||| ||',.004,(0,.0325,.03+i*.004),cream)
 water=mat('condensation',(.65,.8,.85),.05,.13)
 for i in range(28):
  a=random.uniform(0,math.tau);z=random.uniform(.012,.101)
  bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=6,radius=random.uniform(.0004,.0009),location=(math.sin(a)*.0323,math.cos(a)*.0323,z));bpy.context.object.name='condensation bead';bpy.context.object.data.materials.append(water)
def donut():
 dough=mat('golden fried dough',(.56,.25,.06),0,.6);icing=mat('strawberry glaze',(.76,.10,.29),0,.27)
 # Noise modulates the crumb colour and adds fine baked pores.
 nt=dough.node_tree;bs=nt.nodes.get('Principled BSDF');noise=nt.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=140;noise.inputs['Detail'].default_value=3
 ramp=nt.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(.29,.08,.018,1);ramp.color_ramp.elements[1].color=(.78,.42,.13,1);nt.links.new(noise.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
 bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.16;bump.inputs['Distance'].default_value=.0005;nt.links.new(noise.outputs['Fac'],bump.inputs['Height']);nt.links.new(bump.outputs[0],bs.inputs['Normal'])
 torus('baked dough',.029,.013,.014,dough)
 verts=[];faces=[];n=64;k=13
 for i in range(n):
  a=i*math.tau/n
  edge=.18*math.sin(a*7)+.09*math.cos(a*11)
  for j in range(k):
   b=-edge+(math.pi+2*edge)*j/(k-1);r=.029+.0135*math.cos(b)
   verts.append((r*math.cos(a),r*math.sin(a),.014+.0137*math.sin(b)))
 for i in range(n):
  for j in range(k-1):faces.append((i*k+j,((i+1)%n)*k+j,((i+1)%n)*k+j+1,i*k+j+1))
 o=mesh('irregular icing',verts,faces,icing);m=o.modifiers.new('glaze thickness','SOLIDIFY');m.thickness=.00065
 colours=[mat('sugar '+str(i),c,0,.32) for i,c in enumerate([(1,.75,.1),(.2,.85,.8),(.95,.9,.78),(.34,.06,.04)])]
 for i in range(58):
  a=random.uniform(0,math.tau);b=random.uniform(.38,2.75);r=.029+.014*math.cos(b)
  bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=6,radius=.0008,location=(r*math.cos(a),r*math.sin(a),.014+.0146*math.sin(b)))
  o=bpy.context.object;o.name='sugar sprinkle';o.scale=(2.8,1,1);o.rotation_euler.z=random.uniform(0,math.tau);o.data.materials.append(random.choice(colours))
def save(name):
 assets=list(bpy.context.scene.objects)
 bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name+'.glb'),export_format='GLB',use_selection=True)
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,name+'.blend'))
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100;scene.render.film_transparent=True
 scene.world.color=(.25,.25,.25)
 for pos,power,size in [((.15,-.2,.3),3,.2),((-.15,.1,.18),1.5,.15)]:
  bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,.05))-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=(.16,-.25,.20));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.055 if name=='can' else .016))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=.16 if name=='can' else .105;scene.camera=cam
 scene.render.filepath=os.path.join(OUT,name+'_review.png');bpy.ops.render.render(write_still=True)
for name,fn in [('can',can),('donut',donut)]:
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.world=bpy.data.worlds.new('Studio');fn();save(name)
print('IDLE CONSUMABLE MODELS COMPLETE')
