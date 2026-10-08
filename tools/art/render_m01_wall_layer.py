"""Render static cutaway walls, excluding floors and interactive openings."""
from pathlib import Path
import json
import os
import sys
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1'
version = os.environ.get('M01_WALL_VERSION', 'v3')
assert version in ('v3', 'v4', 'v5', 'v6')
sys.path.insert(0, str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source
contract = json.loads((OUT / 'layout_contract.json').read_text(encoding='utf-8'))
width, height = contract['grid_size']
bpy.ops.wm.open_mainfile(filepath=str(OUT / 'layout_reconstruction.blend'))
if version in ('v5','v6'):
    cap_material = next(mat for mat in bpy.data.materials if 'cream wall remate' in mat.name)
    apply_reviewed_source(cap_material, 'ivory_plaster')
if version == 'v6':
    # Interior cutaway wall body uses the reviewed motel plaster rather
    # than the old exterior stucco tint; walnut trim remains separate.
    body_material = bpy.data.materials['ImageGen stucco cutaway']
    apply_reviewed_source(body_material, 'ivory_plaster')
# Keep the original source intact. Add a separate, grounded walnut reveal
# beneath the inset cream crown, using its reviewed ImageGen wood material.
cream = next(obj for obj in bpy.data.objects if 'cream wall remate' in obj.name and obj.type == 'MESH')
walnut = next(mat for mat in bpy.data.materials if 'walnut wall skirting' in mat.name)
reveal = cream.copy()
reveal.data = cream.data.copy()
reveal.name = 'Walnut crown reveal authored detail'
bpy.context.collection.objects.link(reveal)
reveal.data.materials.clear()
reveal.data.materials.append(walnut)
for start in range(0, len(reveal.data.vertices), 8):
    vertices = list(reveal.data.vertices)[start:start+8]
    for axis in (0, 1):
        low = min(v.co[axis] for v in vertices)
        high = max(v.co[axis] for v in vertices)
        centre = (low+high)*.5
        ratio = (high-low-.02)/(high-low)
        for vertex in vertices:
            vertex.co[axis] = centre+(vertex.co[axis]-centre)*ratio
    for vertex in vertices:
        vertex.co.z -= .012
reveal.data.update()
included = []
materials = set()
for obj in bpy.data.objects:
    if obj.type == 'MESH':
        obj.hide_render = not (obj.name.startswith('Wall_') or 'authored detail' in obj.name)
        if not obj.hide_render:
            if obj.name.startswith('Wall_'):
                obj.scale.x *= .999
                obj.scale.y *= .999
                bevel = obj.modifiers.new('Cutaway edge profile', 'BEVEL')
                bevel.width = .022
                bevel.segments = 3
            elif 'cream wall remate' in obj.name:
                # Each authored cap box has eight vertices. Inset its top
                # footprint independently, never scale the whole map mesh.
                for start in range(0, len(obj.data.vertices), 8):
                    vertices = list(obj.data.vertices)[start:start+8]
                    assert len(vertices) == 8
                    top = max(vertex.co.z for vertex in vertices)
                    for vertex in vertices:
                        if abs(vertex.co.z-top)<1e-6:
                            vertex.co.z += .09
                    for axis in (0, 1):
                        low = min(v.co[axis] for v in vertices)
                        high = max(v.co[axis] for v in vertices)
                        centre = (low + high) * .5
                        extent = high - low
                        assert extent >= .49
                        ratio = (extent - .06) / extent
                        for vertex in vertices:
                            vertex.co[axis] = centre + (vertex.co[axis] - centre) * ratio
                obj.data.update()
                bevel = obj.modifiers.get('Fine moulding edges')
                if bevel:
                    bevel.width = .045
                    bevel.segments = 4
            elif 'walnut wall skirting' in obj.name:
                for start in range(0, len(obj.data.vertices), 8):
                    vertices = list(obj.data.vertices)[start:start+8]
                    for axis in (0, 1):
                        low = min(v.co[axis] for v in vertices)
                        high = max(v.co[axis] for v in vertices)
                        centre = (low + high) * .5
                        ratio = (high - low - .001) / (high - low)
                        for vertex in vertices:
                            vertex.co[axis] = centre + (vertex.co[axis] - centre) * ratio
                obj.data.update()
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
    # A local edge profile provides depth without baking scene illumination.
    geometry = nodes.new('ShaderNodeNewGeometry')
    facing = nodes.new('ShaderNodeVectorMath')
    facing.operation = 'DOT_PRODUCT'
    facing.inputs[1].default_value = (0, 0, 1)
    links.new(geometry.outputs['Normal'], facing.inputs[0])
    remap = nodes.new('ShaderNodeMapRange')
    remap.inputs['From Min'].default_value = 0
    remap.inputs['From Max'].default_value = 1
    remap.inputs['To Min'].default_value = .65 if version in ('v4','v5','v6') else .35
    remap.inputs['To Max'].default_value = 1
    links.new(facing.outputs['Value'], remap.inputs['Value'])
    shade = nodes.new('ShaderNodeMixRGB')
    shade.blend_type = 'MULTIPLY'
    shade.inputs[0].default_value = 1
    links.new(remap.outputs['Result'], shade.inputs[2])
    if shader.inputs['Base Color'].is_linked:
        links.new(shader.inputs['Base Color'].links[0].from_socket, shade.inputs[1])
    else:
        shade.inputs[1].default_value = shader.inputs['Base Color'].default_value
    # Short-range geometric contact occlusion, with no environment lighting.
    # This reveals the moulding steps without converting colour into height.
    ao = nodes.new('ShaderNodeAmbientOcclusion')
    ao.inputs['Distance'].default_value = .10
    ao.samples = 8
    contact = nodes.new('ShaderNodeMapRange')
    contact.inputs['From Min'].default_value = 0
    contact.inputs['From Max'].default_value = 1
    contact.inputs['To Min'].default_value = .85 if version in ('v4','v5','v6') else .65
    contact.inputs['To Max'].default_value = 1
    links.new(ao.outputs['AO'],contact.inputs['Value'])
    final_colour = nodes.new('ShaderNodeMixRGB')
    final_colour.blend_type = 'MULTIPLY'
    final_colour.inputs[0].default_value = 1
    links.new(shade.outputs[0],final_colour.inputs[1])
    links.new(contact.outputs['Result'],final_colour.inputs[2])
    links.new(final_colour.outputs[0], emission.inputs['Color'])
    links.new(emission.outputs['Emission'], output.inputs['Surface'])
scene = bpy.context.scene
camera = scene.camera
camera.location = (width*.25,-height*.25,45)
camera.rotation_euler = (0,0,0)
camera.data.type = 'ORTHO'
camera.data.ortho_scale = width*.5
texels_per_world_pixel = 2
scene.render.resolution_x = width*16*texels_per_world_pixel
scene.render.resolution_y = height*16*texels_per_world_pixel
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.filepath = str(OUT / f'wall_layer_candidate_{version}.png')
scene.view_settings.view_transform = 'Standard'
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
scene.cycles.samples = 4
scene.cycles.pixel_filter_type = 'BOX'
scene.cycles.filter_width = .01
bpy.ops.render.render(write_still=True)
(OUT / f'wall_layer_contract_{version}.json').write_text(json.dumps({
    'source_level_sha256': contract['source_sha256'],
    'image': f'wall_layer_candidate_{version}.png',
    'size_px': [width*16*texels_per_world_pixel,height*16*texels_per_world_pixel],
    'godot_position_px': [0,0], 'godot_sprite_centered': False,
    'godot_scale': [.5,.5], 'pixels_per_cell': 32,
    'lighting': 'source colour with short-range geometric contact occlusion; runtime Godot lights',
    'included_meshes': included, 'water_excluded': True,
    'runtime_approved': False,
    'pending': ['pixel alignment capture in Godot', 'lighting and scale review',
                'performance and interaction checks'],
}, indent=2), encoding='utf-8')
print(f'M01_WALL_LAYER_V3: {scene.render.resolution_x}x{scene.render.resolution_y}; chamfered raised crown, walnut reveal, contact occlusion; scale=.5')
