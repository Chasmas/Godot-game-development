"""Review existing ImageGen-directed Blender seating at the game's elevation."""
from pathlib import Path
import math
import json
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/imagegen_upholstery_v1/interiors_material_review.blend'
OUT = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/armchair_runtime_v3'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
chairs = [o for o in bpy.data.objects if o.type == 'EMPTY' and o.name.startswith('M01 upholstered armchair')]
assert chairs, 'Authored upholstered chair missing'
source = chairs[0]
parts = [source] + list(source.children_recursive)
fabric = bpy.data.materials.new('ImageGen sage woven upholstery v1')
fabric.use_nodes = True
nodes = fabric.node_tree.nodes
links = fabric.node_tree.links
shader = nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value = .86
shader.inputs['Specular IOR Level'].default_value = .2
shader.inputs['Sheen Weight'].default_value = .18
texture = nodes.new('ShaderNodeTexImage')
texture.image = bpy.data.images.load(str(ROOT / 'assets/art/materials/m01/batch_v1/armchair_sage_fabric_albedo_v1.png'))
texture.projection = 'BOX'
texture.projection_blend = .15
coords = nodes.new('ShaderNodeTexCoord')
mapping = nodes.new('ShaderNodeVectorMath')
mapping.operation = 'SCALE'
mapping.inputs[3].default_value = 2.0  # one source tile per half metre
links.new(coords.outputs['Object'], mapping.inputs[0])
links.new(mapping.outputs[0], texture.inputs['Vector'])
links.new(texture.outputs['Color'], shader.inputs['Base Color'])
fabric['source_kind'] = 'ImageGen colour only; no derived normal or displacement'
for part in parts:
    if part.type == 'MESH' and 'walnut leg' not in part.name:
        part.data = part.data.copy()
        part.data.materials.clear()
        part.data.materials.append(fabric)
    elif part.type == 'CURVE' and 'piping' in part.name:
        part.data = part.data.copy()
        part.data.materials.clear()
        part.data.materials.append(fabric)
for obj in bpy.context.scene.objects:
    obj.hide_render = True
review_roots = []
for index in range(4):
    copies = {}
    for old in parts:
        new = old.copy()
        if old.data is not None:
            new.data = old.data.copy()
        bpy.context.collection.objects.link(new)
        new.hide_render = False
        copies[old] = new
    for old, new in copies.items():
        new.parent = copies.get(old.parent)
    chair = copies[source]
    chair.location = (index * 1.2 - 1.8, 0, 0)
    chair.rotation_euler = (0, 0, index * math.pi / 2)
    review_roots.append(chair)

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 1200
scene.render.resolution_y = 420
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.use_compositing = False
scene.world = bpy.data.worlds.new('Runtime seating neutral world')
scene.world.use_nodes = True
scene.world.node_tree.nodes.get('Background').inputs[0].default_value = (.10, .10, .12, 1)
scene.world.node_tree.nodes.get('Background').inputs[1].default_value = .8
scene.view_settings.exposure = .4
camera_data = bpy.data.cameras.new('Game elevation 50 degrees')
camera = bpy.data.objects.new('Game elevation camera', camera_data)
bpy.context.collection.objects.link(camera)
target = Vector((0, 0, .4))
camera.location = target + Vector((0, -math.cos(math.radians(50)) * 10, math.sin(math.radians(50)) * 10))
camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 5
scene.camera = camera
for name, location, energy, color in [('Key', (-3, -4, 6), 900, (1, .92, .84)), ('Fill', (4, 1, 4), 500, (.75, .85, 1))]:
    light_data = bpy.data.lights.new(name, 'AREA')
    light_data.energy = energy
    light_data.color = color
    light_data.shape = 'DISK'
    light_data.size = 4
    light = bpy.data.objects.new(name, light_data)
    bpy.context.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (target - light.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.filepath = str(OUT / 'armchair_four_directions.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'armchair_runtime_review.blend'))
bpy.ops.render.render(write_still=True)
scene.render.resolution_x = scene.render.resolution_y = 512
camera_data.ortho_scale = 1.4
entries = []
for index, chair in enumerate(review_roots):
    for other in review_roots:
        for part in [other] + list(other.children_recursive):
            part.hide_render = other != chair
    chair.location = (0, 0, 0)
    bpy.context.view_layer.update()
    filename = 'armchair_%03d.png' % (index * 90)
    scene.render.filepath = str(OUT / filename)
    bpy.ops.render.render(write_still=True)
    anchor = world_to_camera_view(scene, camera, Vector((0, 0, 0)))
    entries.append({'file': filename, 'rotation_degrees': index * 90,
                    'floor_anchor_px': [anchor.x * 512, (1 - anchor.y) * 512]})
(OUT / 'runtime_contract.json').write_text(json.dumps({
    'source_reference': 'assets/art/materials/m01/batch_v1/guest_room_direction.png',
    'fabric_source': 'assets/art/materials/m01/batch_v1/armchair_sage_fabric_albedo_v1.png',
    'camera_elevation_degrees': 50, 'pixels_per_metre': 512 / 1.4,
    'game_pixels_per_metre': 16, 'sprite_scale': 16 / (512 / 1.4),
    'runtime_approved': False, 'frames': entries}, indent=2), encoding='utf-8')
print('M01_ARMCHAIR_RUNTIME: four facings rendered from existing authored seating; preview only')
