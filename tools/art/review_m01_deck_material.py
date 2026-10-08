"""Render the shared generated albedo on actual Blender geometry for review."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from m01_materials import apply_deck_material

root = Path(__file__).resolve().parents[2]
out = root / 'build/m01_material_review'
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
material = bpy.data.materials.new('Motel deck shared albedo')
material.use_nodes = True
apply_deck_material(material)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -.08))
slab = bpy.context.object
slab.scale = (6, 6, .16)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
slab.data.materials.append(material)
bpy.ops.object.light_add(type='AREA', location=(-3, -2, 6))
bpy.context.object.data.energy = 850
bpy.context.object.data.shape = 'DISK'
bpy.context.object.data.size = 5
bpy.ops.object.camera_add(location=(5, -7, 8))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 9
scene = bpy.context.scene
scene.camera = camera
scene.world = bpy.data.worlds.new('Review world')
scene.world.use_nodes = True
scene.world.node_tree.nodes.get('Background').inputs[0].default_value = (.12, .12, .12, 1)
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 768
scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.filepath = str(out / 'deck_material.png')
bpy.ops.wm.save_as_mainfile(filepath=str(out / 'deck_material.blend'))
bpy.ops.render.render(write_still=True)
