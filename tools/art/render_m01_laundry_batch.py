"""One Blender session exports a coherent ImageGen-backed laundry prop batch."""
from pathlib import Path
import sys
import json
import math
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from m01_detergent import bottle, material

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/laundry_batch'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 48
scene.render.resolution_x = 256
scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.film_transparent = True
scene.world = bpy.data.worlds.new('Neutral prop illumination')
scene.world.use_nodes = True
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value = .3
scene.view_settings.look = 'AgX - Medium High Contrast'
bpy.ops.object.camera_add(location=(0,-3,3.58))
camera = bpy.context.object
target = Vector((0,0,.18))
camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = .54
scene.camera = camera
for location, energy, size in [((-1,-2,3),100,3),((2,1,2),35,2)]:
    bpy.ops.object.light_add(type='AREA',location=location)
    bpy.context.object.data.energy = energy
    bpy.context.object.data.size = size

manifest = {'status':'staging_unapproved','source_label':'assets/art/materials/m01/palm_fresh_label_v1.png','camera':'orthographic south, approximately 49 degrees elevation','assets':[]}
for name,tint in [('teal',(.40,.59,.61)),('ochre',(.78,.67,.48)),('red',(.63,.25,.19)),('ivory',(.74,.73,.62))]:
    before = set(bpy.data.objects)
    bottle(0,0,0,tint)
    created = set(bpy.data.objects)-before
    scene.render.filepath = str(OUT / ('detergent_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
    # Project ground anchor into the exported canvas for accurate runtime origin.
    from bpy_extras.object_utils import world_to_camera_view
    ground = world_to_camera_view(scene,camera,Vector((0,0,0)))
    manifest['assets'].append({'file':'detergent_'+name+'.png','canvas':[256,256],'ground_anchor':[round(ground.x*256,3),round((1-ground.y)*256,3)],'suggested_canvas_width_px':16})
    for obj in created: bpy.data.objects.remove(obj,do_unlink=True)
    # Only retain the shared ImageGen image; avoid accumulating per-variant meshes.
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0: bpy.data.meshes.remove(mesh)
# Composite assembly keeps shelf contact and cast shadows coherent at game scale.
steel = material('Worn service shelf steel', (.14,.18,.19), .58)
steel.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value = .65
enamel = material('Aged ivory shelf enamel', (.58,.57,.49), .62)
def box(name, location, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj=bpy.context.object
    obj.name=name
    obj.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    bevel=obj.modifiers.new('Rolled shelf edges','BEVEL')
    bevel.width=.008
    bevel.segments=3
    return obj
box('Service bench top',(0,0,.65),(1.10,.32,.035),enamel)
box('Service bench lower tray',(0,0,.22),(1.04,.28,.025),steel)
for x in (-.49,.49):
    for y in (-.12,.12):
        box('Service bench leg',(x,y,.32),(.025,.025,.64),steel)
box('Bench rear upstand',(0,.15,.71),(1.10,.015,.10),enamel)
for i,tint in enumerate([(.40,.59,.61),(.78,.67,.48),(.63,.25,.19),(.74,.73,.62)]):
    bottle(-.36+i*.24,-.015,.6675,tint)
target=Vector((0,0,.42))
camera.location=(0,-3,3.87)
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=1.5
scene.render.resolution_x=512
scene.render.resolution_y=512
scene.render.filepath=str(OUT/'detergent_service_bench.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'detergent_service_bench.blend'))
bpy.ops.render.render(write_still=True)
ground=world_to_camera_view(scene,camera,Vector((0,0,0)))
manifest['assembly']={'file':'detergent_service_bench.png','canvas':[512,512],'ground_anchor':[round(ground.x*512,3),round((1-ground.y)*512,3)],'suggested_canvas_width_px':48,'footprint_px':[-18,-5,36,10]}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('LAUNDRY PROP BATCH: exported four variants and projected ground anchors')
