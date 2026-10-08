"""Render ribbons from actual Godot-projected Blender hand/weapon trajectories."""
import bpy, json, math, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
args=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
dense="--dense" in args
weapon_filter=args[args.index("--weapon")+1] if "--weapon" in args else None
OUT=ROOT/("build/melee_trail_review/measured_dense" if dense else "build/melee_trail_review/measured")
variant=args[args.index("--variant")+1] if "--variant" in args else None
if variant:
 assert variant.replace('_','').isalnum()
 OUT=OUT/variant
history=int(args[args.index("--history")+1]) if "--history" in args else 8
assert 1 <= history <= 32
OUT.mkdir(parents=True,exist_ok=True)
source_name=args[args.index("--source")+1] if "--source" in args else "actual_weapon_paths.json"
source=json.loads((ROOT/"build/melee_trail_review"/source_name).read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=scene.render.resolution_y=256
scene.render.resolution_percentage=100;scene.render.film_transparent=True
scene.render.image_settings.file_format="PNG";scene.render.image_settings.color_mode="RGBA"
scene.view_settings.view_transform="Standard"
bpy.ops.object.camera_add(location=(0,0,100))
scene.camera=bpy.context.object;scene.camera.data.type="ORTHO";scene.camera.data.ortho_scale=80
materials=[]
for name,color,opacity in [("Silver swept ribbon",(.65,.82,.95),.45),("Narrow luminous core",(.9,.98,1),.8)]:
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear()
 out=n.new("ShaderNodeOutputMaterial");mix=n.new("ShaderNodeMixShader");mix.inputs[0].default_value=opacity
 transparent=n.new("ShaderNodeBsdfTransparent");emission=n.new("ShaderNodeEmission");emission.inputs[0].default_value=(*color,1)
 m.node_tree.links.new(transparent.outputs[0],mix.inputs[1]);m.node_tree.links.new(emission.outputs[0],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],out.inputs[0]);materials.append(m)
phases=[min(i/64,.995) for i in range(65)] if dense else [.22,.30,.38,.46,.54,.62,.78,.995]
for sample in source['samples']:
 if weapon_filter and sample['weapon']!=weapon_filter:continue
 if '--intermediate-only' in args and round(math.degrees(sample['angle']),1)%45==0:continue
 folder=OUT/sample['weapon']/str(round(math.degrees(sample['angle']),1)).removesuffix('.0')
 folder.mkdir(parents=True,exist_ok=True)
 points=sample['points']
 for frame,phase in enumerate(phases):
  for obj in list(bpy.data.objects):
   if obj.type=="MESH":bpy.data.objects.remove(obj,do_unlink=True)
  end=min(round(phase*64),64);start=max(0,end-history)
  centers=[(p['tip'][0],-p['tip'][1]) for p in points[start:end+1]]
  for strand,width in enumerate([.75,.18]):
   vertices=[];faces=[]
   for i,p in enumerate(centers):
    prev=centers[max(0,i-1)];nxt=centers[min(len(centers)-1,i+1)]
    dx,dy=nxt[0]-prev[0],nxt[1]-prev[1];length=max(math.hypot(dx,dy),1e-6)
    u=i/max(len(centers)-1,1);w=width*math.sin(math.pi*u)**.8
    nx,ny=-dy/length,dx/length
    vertices.extend([(p[0]+nx*w,p[1]+ny*w,strand*.01),(p[0]-nx*w,p[1]-ny*w,strand*.01)])
    if i:faces.append((2*i-2,2*i-1,2*i+1,2*i))
   mesh=bpy.data.meshes.new("Measured ribbon");mesh.from_pydata(vertices,[],faces);mesh.update()
   obj=bpy.data.objects.new("Measured ribbon",mesh);scene.collection.objects.link(obj);mesh.materials.append(materials[strand])
  scene.render.filepath=str(folder/f"{frame:03}.png");bpy.ops.render.render(write_still=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/"source.blend"))
(OUT/(f"review_{weapon_filter}.json" if weapon_filter else "review.json")).write_text(json.dumps({"approved":False,"history":history,"frames":len(phases),"weapon_filter":weapon_filter,"phases":phases,"size":[256,256],"world_size_px":80,"origin":"actor floor anchor","projection":"already projected from runtime fixed 50-degree camera; no second projection","source":"../"+source_name},indent=2))
