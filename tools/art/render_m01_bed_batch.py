"""ImageGen-backed motel bed family, Blender source and four runtime views.

Staging only. Geometry is authored in metres; no image pixels become geometry.
"""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
OUT = ROOT/'assets/art/prerendered/m01_sunset_palms/staging/bed_family_v1'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, colour, source=None):
    result=bpy.data.materials.new(name); result.use_nodes=True
    shader=result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*colour,1)
    shader.inputs['Roughness'].default_value=.85
    if source: apply_reviewed_source(result,source)
    return result

wood=material('Shared ImageGen motel walnut',(.3,.15,.08),'walnut')
cloth=material('Shared ImageGen motel bedspread',(.4,.3,.2),'bedspread')
linen=material('Shared ImageGen ivory linen',(.85,.82,.72),'towel')
shadow=material('Recessed bed plinth',(.07,.055,.045))
root=bpy.data.objects.new('Sunset Palms unified double bed',None)
bpy.context.collection.objects.link(root)

def box(name, location, dimensions, mat, bevel):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object; obj.name=name; obj.dimensions=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat);obj.parent=root
    modifier=obj.modifiers.new('Authored rounded edges','BEVEL')
    modifier.width=bevel;modifier.segments=4
    obj.modifiers.new('Weighted upholstery normals','WEIGHTED_NORMAL')
    return obj

box('Recessed support',(0,0,.15),(1.2,1.72,.3),shadow,.025)
box('Walnut perimeter frame',(0,0,.34),(1.62,2.12,.18),wood,.035)
box('Ivory mattress',(0,0,.48),(1.54,2.02,.23),linen,.075)
box('Padded walnut headboard',(0,1.055,.65),(1.72,.10,1.12),wood,.04)
box('Inset headboard upholstery',(0,.992,.79),(1.5,.035,.55),cloth,.025)
box('Bedspread with rounded hanging edge',(0,-.24,.60),(1.57,1.53,.085),cloth,.04)
for x in (-.39,.39):
    pillow=box('Soft ivory pillow',(x,.69,.66),(.66,.42,.15),linen,.065)
    pillow.rotation_euler[2]=.025 if x<0 else -.025
# Real piping geometry gives the cover an edge without deriving height from colour.
curve=bpy.data.curves.new('Bedspread edge piping','CURVE');curve.dimensions='3D'
curve.bevel_depth=.007;curve.bevel_resolution=2
spline=curve.splines.new('POLY');spline.points.add(3)
for point,coordinate in zip(spline.points,[(-.76,.50,.625),(-.76,-.97,.625),(.76,-.97,.625),(.76,.50,.625)]):
    point.co=(*coordinate,1)
obj=bpy.data.objects.new('Sewn bedspread perimeter',curve);bpy.context.collection.objects.link(obj)
obj.parent=root;curve.materials.append(linen)

scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=768;scene.render.resolution_y=768
scene.render.resolution_percentage=100;scene.render.film_transparent=True
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.view_settings.view_transform='Standard'
scene.world=bpy.data.worlds.new('Neutral bed review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
bpy.ops.object.camera_add(location=(0,-5,6.25))
camera=bpy.context.object;look=Vector((0,0,.35))
camera.rotation_euler=(look-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=3.25;scene.camera=camera
for location,energy in [((-2,-3,5),200),((3,2,4),110)]:
    bpy.ops.object.light_add(type='AREA',location=location)
    light=bpy.context.object;light.data.energy=energy;light.data.size=4
    light.rotation_euler=(look-light.location).to_track_quat('-Z','Y').to_euler()
anchor=world_to_camera_view(scene,camera,Vector((0,0,0)))
frames=[]
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'motel_bed.blend'))
for degrees in (0,90,180,270):
    root.rotation_euler[2]=math.radians(degrees)
    filename=f'bed_{degrees:03d}.png';scene.render.filepath=str(OUT/filename)
    bpy.ops.render.render(write_still=True)
    frames.append({'file':filename,'rotation_degrees':degrees,
                   'floor_anchor_px':[anchor.x*768,(1-anchor.y)*768]})
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':False,
    'source_kind':'Authored Blender geometry with existing ImageGen walnut, bedspread and linen colour sources',
    'footprint_metres':[1.72,2.16],'camera_elevation_degrees':49.72,
    'pixels_per_metre':768/3.25,'frames':frames,
    'pending':['visual review','game-scale projection','mapping all existing bed variants','collision and navigation validation']},indent=2))
print('M01_BED_BATCH: four coherent views; staging only')
