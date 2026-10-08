"""Shared ImageGen albedo mapped onto authored Blender materials."""
from pathlib import Path
import bpy

def apply_deck_material(material):
 return apply_generated_material(material, 'deck_pavers_albedo_v1.png', .5, .48)

def apply_generated_material(material, filename, repeat_per_meter, roughness):
 path=Path(__file__).resolve().parents[2]/'assets/art/materials/m01'/filename
 if not path.exists():raise FileNotFoundError(path)
 nodes=material.node_tree.nodes;links=material.node_tree.links
 bs=nodes.get('Principled BSDF')
 image=nodes.new('ShaderNodeTexImage');image.name='ImageGen '+filename;image.image=bpy.data.images.load(str(path),check_existing=True);image.extension='REPEAT'
 coords=nodes.new('ShaderNodeTexCoord');mapping=nodes.new('ShaderNodeVectorMath');mapping.operation='SCALE';mapping.inputs[3].default_value=repeat_per_meter
 links.new(coords.outputs['Object'],mapping.inputs[0]);links.new(mapping.outputs[0],image.inputs['Vector']);links.new(image.outputs['Color'],bs.inputs['Base Color'])
 bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.12;bump.inputs['Distance'].default_value=.025
 links.new(image.outputs['Color'],bump.inputs['Height']);links.new(bump.outputs[0],bs.inputs['Normal'])
 bs.inputs['Roughness'].default_value=roughness
 return material
