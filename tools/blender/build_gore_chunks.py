"""Render organic tissue candidates; integration requires visual review."""
import bpy, math, random
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parents[2]/"build/gore_chunk_review"
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name, color, roughness):
 m=bpy.data.materials.new(name);m.use_nodes=True
 n=m.node_tree.nodes;p=n.get("Principled BSDF")
 p.inputs["Base Color"].default_value=(*color,1);p.inputs["Roughness"].default_value=roughness
 noise=n.new("ShaderNodeTexNoise");noise.inputs["Scale"].default_value=18
 bump=n.new("ShaderNodeBump");bump.inputs["Strength"].default_value=.32;bump.inputs["Distance"].default_value=.045
 m.node_tree.links.new(noise.outputs["Fac"],bump.inputs["Height"]);m.node_tree.links.new(bump.outputs["Normal"],p.inputs["Normal"])
 return m
flesh=material("Wet dark muscle",(.24,.009,.024),.26)
fiber=material("Torn connective fibres",(.48,.22,.19),.4)
scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=32
scene.render.resolution_x=48;scene.render.resolution_y=48;scene.render.resolution_percentage=100;scene.render.film_transparent=True
scene.world=bpy.data.worlds.new("Soft ambient");scene.world.color=(.18,.18,.18)
for location,energy in [((-2,-3,4),220),((3,1,3),100)]:
 bpy.ops.object.light_add(type="AREA",location=location);o=bpy.context.object;o.data.energy=energy;o.data.size=3;o.rotation_euler=(-o.location).to_track_quat("-Z","Y").to_euler()
bpy.ops.object.camera_add(location=(0,-2,4));camera=bpy.context.object;camera.rotation_euler=(-camera.location).to_track_quat("-Z","Y").to_euler();camera.data.type="ORTHO";camera.data.ortho_scale=1.6;scene.camera=camera
for variant in range(3):
 for o in list(bpy.data.objects):
  if o.type in ("MESH","CURVE"):bpy.data.objects.remove(o,do_unlink=True)
 rng=random.Random(731+variant)
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4,radius=.45)
 o=bpy.context.object;o.name="Torn muscle tissue"
 for vertex in o.data.vertices:
  v=vertex.co;factor=1+.18*math.sin(v.x*21+variant)+.11*math.sin(v.y*32)
  v.x*=factor*(1.1+variant*.13);v.y*=factor*.8;v.z*=factor*.45
 o.data.materials.append(flesh)
 for polygon in o.data.polygons:polygon.use_smooth=True
 for strand in range(5):
  curve=bpy.data.curves.new("Exposed fibre","CURVE");curve.dimensions="3D";curve.bevel_depth=.009;curve.bevel_resolution=2
  spline=curve.splines.new("BEZIER");spline.bezier_points.add(3)
  angle=rng.uniform(0,math.tau)
  for i,point in enumerate(spline.bezier_points):
   r=.15+i*.095;point.co=(math.cos(angle)*r,math.sin(angle)*r,.17-i*.025+rng.uniform(-.015,.015));point.handle_left_type="AUTO";point.handle_right_type="AUTO"
  strand_object=bpy.data.objects.new("Torn fibre",curve);scene.collection.objects.link(strand_object);curve.materials.append(fiber)
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f"chunk_{variant}.blend"))
 scene.render.filepath=str(OUT/f"chunk_{variant}.png");bpy.ops.render.render(write_still=True)
