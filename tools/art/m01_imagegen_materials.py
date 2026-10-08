"""Reviewed ImageGen sources for Blender reconstruction, with physical repeats.

These are colour candidates, not measured PBR or height maps. No colour-to-height
conversion is made. BOX mapping uses object-space metres and supports vertical
walls and the existing batched authored geometry without flattened wall UVs.
"""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / 'assets/art/materials/m01/batch_v1'
SPECS = {
    'ivory_plaster': ('interior_ivory_plaster_albedo_v1.png', 2.0, .88),
    'deck': ('../deck_pavers_albedo_v1.png', 2.0, .54),
    'stucco': ('exterior_stucco_albedo.png', 2.0, .86),
    'wallpaper': ('guest_wallpaper_albedo.png', 2.0, .84),
    'reception_panels': ('reception_wood_albedo.png', 2.4, .56),
    'bathroom_tiles': ('bathroom_wall_tiles_albedo.png', 2.0, .38),
    'bedspread': ('guest_bedspread_albedo.png', 1.6, .92),
    'carpet': ('corridor_carpet_albedo.png', 2.4, .96),
    'asphalt': ('asphalt_albedo.png', 2.0, .88),
    'towel': ('towel_fabric_albedo.png', .12, .97),
    'painted_metal': ('painted_metal_albedo.png', 1.0, .52),
    'rubber': ('rubber_albedo.png', .3, .91),
    'walnut': ('furniture_walnut_albedo.png', 1.2, .55),
    'pool_tiles': ('pool_tiles_albedo.png', 1.2, .34),
    'reception_floor': ('reception_floor_albedo.png', 2.4, .42),
}


def apply_reviewed_source(material, key):
    filename, repeat_metres, roughness = SPECS[key]
    path = BATCH / filename
    if not path.is_file():
        raise FileNotFoundError(path)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if shader is None:
        raise ValueError(f'No Principled shader in {material.name}')
    for node in list(nodes):
        if node.get('m01_reviewed_source'):
            nodes.remove(node)
    coords = nodes.new('ShaderNodeTexCoord')
    scale = nodes.new('ShaderNodeVectorMath')
    scale.operation = 'SCALE'
    scale.inputs[3].default_value = 1.0 / repeat_metres
    image = nodes.new('ShaderNodeTexImage')
    image.image = bpy.data.images.load(str(path), check_existing=True)
    image.projection = 'BOX'
    image.projection_blend = .08
    image.extension = 'REPEAT'
    image.interpolation = 'Linear'
    for node in (coords, scale, image):
        node['m01_reviewed_source'] = True
    image.label = f'ImageGen colour candidate: {filename}'
    links.new(coords.outputs['Object'], scale.inputs[0])
    links.new(scale.outputs['Vector'], image.inputs['Vector'])
    links.new(image.outputs['Color'], shader.inputs['Base Color'])
    # Old noise/bump networks remain disconnected; source colour is not height.
    for link in list(shader.inputs['Normal'].links):
        links.remove(link)
    shader.inputs['Roughness'].default_value = roughness
    material['imagegen_source'] = str(path.relative_to(ROOT))
    material['repeat_metres'] = repeat_metres
    material['height_data_validated'] = False
    material['native_scale_approved'] = False
    return material
