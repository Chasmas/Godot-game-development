"""Render a neutral, three-quarter reference review for a staged Meshy GLB.

Usage:
    blender -b --python tools/art/render_meshy_model_review.py -- INPUT.glb OUTPUT.png

The tool is deliberately presentation-only: it does not alter the imported
asset and therefore cannot accidentally promote a staging model to runtime.
"""
from pathlib import Path
import sys

import bpy
from mathutils import Vector


argv = sys.argv[sys.argv.index("--") + 1:]
source, output = map(lambda item: Path(item).resolve(), argv)
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(output)
world = bpy.data.worlds.new("Neutral review world")
world.color = (0.018, 0.021, 0.03)
scene.world = world

mesh_objects = [obj for obj in scene.objects if obj.type == "MESH"]
if not mesh_objects:
    raise RuntimeError("The staged GLB has no mesh objects")
corners = [obj.matrix_world @ Vector(corner) for obj in mesh_objects for corner in obj.bound_box]
low = Vector((min(point.x for point in corners), min(point.y for point in corners), min(point.z for point in corners)))
high = Vector((max(point.x for point in corners), max(point.y for point in corners), max(point.z for point in corners)))
center = (low + high) * .5
height = max(high.z - low.z, .01)


def aim(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


camera = bpy.data.objects.new("Review camera", bpy.data.cameras.new("Review camera"))
camera.data.type = "ORTHO"
camera.data.ortho_scale = height * 1.28
camera.location = center + Vector((height * 1.2, -height * 1.75, height * .68))
aim(camera, center + Vector((0, 0, height * .03)))
scene.collection.objects.link(camera)
scene.camera = camera

for name, offset, energy, color in (
    ("Key", (1.8, -2.6, 3.2), 1200, (1.0, .77, .57)),
    ("Rim", (-2.1, 1.8, 2.5), 900, (.23, .65, 1.0)),
    ("Fill", (0, 2.4, 1.4), 450, (1.0, .15, .46)),
):
    light = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
    light.data.energy = energy
    light.data.shape = "DISK"
    light.data.size = height * 1.6
    light.location = center + Vector(offset) * height / 2.5
    aim(light, center + Vector((0, 0, height * .35)))
    scene.collection.objects.link(light)

bpy.ops.render.render(write_still=True)
print("MESHY_MODEL_REVIEW", source.name, output)
