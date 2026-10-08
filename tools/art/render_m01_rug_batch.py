"""ImageGen textile on authored Blender rug geometry; staging only."""
from pathlib import Path
import bpy, math, json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/rug_family_v1'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/art/prerendered/m01_sunset_palms/staging/nightstand_family_v1/nightstand.blend'))
old=next(o for o in bpy.data.objects if o.type=='EMPTY' and o.name.startswith('Motel nightstand'))
for obj in list(old.children_recursive)+[old]:bpy.data.objects.remove(obj,do_unlink=True)
root=bpy.data.objects.new('Sunset Palms woven rug',None);bpy.context.collection.objects.link(root)
mat=bpy.data.materials.new('ImageGen oxblood woven wool');mat.use_nodes=True
nodes=mat.node_tree.nodes;shader=nodes['Principled BSDF'];shader.inputs['Roughness'].default_value=.95
image=bpy.data.images.load(str(ROOT/'assets/art/materials/m01/batch_v1/motel_rug_oxblood_albedo_v1.png'))
tex=nodes.new('ShaderNodeTexImage');tex.image=image
mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=240
bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.002
mat.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);mat.node_tree.links.new(bump.outputs['Normal'],shader.inputs['Normal'])
mesh=bpy.data.meshes.new('Rectangular woven surface UV')
mesh.from_pydata([(-.75,-.375,.012),(.75,-.375,.012),(.75,.375,.012),(-.75,.375,.012)],[],[(0,1,2,3)])
mesh.uv_layers.new(name='Full textile surface')
for loop,uv in zip(mesh.uv_layers.active.data,[(0,0),(1,0),(1,1),(0,1)]):loop.uv=uv
obj=bpy.data.objects.new('Wool pile with real backing thickness',mesh);bpy.context.collection.objects.link(obj);obj.parent=root;obj.data.materials.append(mat)
solid=obj.modifiers.new('Woven backing','SOLIDIFY');solid.thickness=.012
bevel=obj.modifiers.new('Soft bound edges','BEVEL');bevel.width=.003;bevel.segments=3
thread=bpy.data.materials.new('Natural ivory fringe');thread.diffuse_color=(.52,.43,.30,1)
for side in (-1,1):
 for i in range(50):
  curve=bpy.data.curves.new('Individual twisted fringe','CURVE');curve.dimensions='3D';curve.bevel_depth=.0016;curve.bevel_resolution=2
  spline=curve.splines.new('POLY');spline.points.add(2)
  y=-.36+i*.72/49
  for point,co in zip(spline.points,[(side*.75,y,.008),(side*.768,y+.0015*math.sin(i),.006),(side*(.786+.002*math.sin(i*2)),y+.003*math.sin(i),.004)]):point.co=(*co,1)
  fringe=bpy.data.objects.new('Knotted edge fringe',curve);bpy.context.collection.objects.link(fringe);fringe.parent=root;curve.materials.append(thread)
scene=bpy.context.scene;camera=scene.camera;look=Vector((0,0,0))
camera.location=look+Vector((0,-4,4.75));camera.rotation_euler=(look-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=1.9
scene.cycles.samples=24;scene.render.resolution_x=512;scene.render.resolution_y=512
bpy.context.view_layer.update()
anchor=world_to_camera_view(scene,camera,Vector((0,0,0)))
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'motel_rug.blend'))
frames=[]
for degrees in (0,90):
 root.rotation_euler.z=math.radians(degrees)
 filename=f'rug_{degrees:03d}.png';scene.render.filepath=str(OUT/filename);bpy.ops.render.render(write_still=True)
 frames.append({'file':filename,'rotation_degrees':degrees,'floor_anchor_px':[anchor.x*512,(1-anchor.y)*512]})
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':False,'footprint_metres':[1.576,.75],'pixels_per_metre':512/1.9,'frames':frames,'source_kind':'Blender wool backing and fringe with ImageGen albedo','solid_collision':False,'reason':'Flat textile is walkable floor dressing'},indent=2))
