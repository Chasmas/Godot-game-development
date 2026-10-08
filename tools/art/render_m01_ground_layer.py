"""Render a neutral static ground colour layer for lighting in Godot."""
from pathlib import Path
import json
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1'
contract = json.loads((OUT / 'layout_contract.json').read_text(encoding='utf-8'))
width, height = contract['grid_size']
bpy.ops.wm.open_mainfile(filepath=str(OUT / 'layout_reconstruction.blend'))
included = []
materials = set()
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        obj.hide_render = not obj.name.startswith('Floor_') or obj.name.startswith('Floor_~')
        if not obj.hide_render:
            included.append(obj.name)
            materials.update(slot.material for slot in obj.material_slots if slot.material)
# Render source colour without baking a second lighting pass. Runtime Godot
# lights remain authoritative; the unchanged .blend keeps its physical shaders.
for material in materials:
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = next(node for node in nodes if node.type == 'BSDF_PRINCIPLED')
    output = next(node for node in nodes if node.type == 'OUTPUT_MATERIAL')
    emission = nodes.new('ShaderNodeEmission')
    emission.inputs['Strength'].default_value = 1
    if shader.inputs['Base Color'].is_linked:
        links.new(shader.inputs['Base Color'].links[0].from_socket, emission.inputs['Color'])
    else:
        emission.inputs['Color'].default_value = shader.inputs['Base Color'].default_value
    links.new(emission.outputs['Emission'], output.inputs['Surface'])
scene = bpy.context.scene
camera = scene.camera
camera.location = (width*.25,-height*.25,45)
camera.rotation_euler = (0,0,0)
camera.data.type = 'ORTHO'
camera.data.ortho_scale = width*.5
texels_per_world_pixel = 4
scene.render.resolution_x = width*16*texels_per_world_pixel
scene.render.resolution_y = height*16*texels_per_world_pixel
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.filepath = str(OUT / 'ground_layer_candidate_v3.png')
scene.view_settings.view_transform = 'Standard'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.cycles.samples = 4
scene.cycles.pixel_filter_type = 'BOX'
scene.cycles.filter_width = .01
bpy.ops.render.render(write_still=True)
(OUT / 'ground_layer_contract_v3.json').write_text(json.dumps({
    'source_level_sha256': contract['source_sha256'],
    'image': 'ground_layer_candidate_v3.png',
    'size_px': [width*16*texels_per_world_pixel,height*16*texels_per_world_pixel],
    'godot_position_px': [0,0], 'godot_sprite_centered': False,
    'godot_scale': [.25,.25], 'pixels_per_cell': 64,
    'lighting': 'neutral source colour; runtime Godot lights',
    'included_meshes': included, 'water_excluded': True,
    'runtime_approved': False,
    'pending': ['pixel alignment capture in Godot', 'lighting and scale review',
                'performance and interaction checks'],
}, indent=2), encoding='utf-8')
print(f'M01_GROUND_LAYER_V3: {scene.render.resolution_x}x{scene.render.resolution_y}; water excluded; scale=.25; neutral colour; narrow box pixel filter')
