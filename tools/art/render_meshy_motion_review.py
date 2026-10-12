"""Render one representative pose from every FBX action into an art-review folder.

Use: blender -b --python tools/art/render_meshy_motion_review.py -- INPUT.fbx OUT_DIR
"""
from pathlib import Path
import sys

import bpy
from mathutils import Vector


argv = sys.argv[sys.argv.index("--") + 1:]
source, out_dir = map(Path, argv)
source, out_dir = source.resolve(), out_dir.resolve()
out_dir.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source))
armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
world = bpy.data.worlds.new("Review world")
world.color = (0.025, 0.028, 0.04)
scene.world = world


def aim(object_: bpy.types.Object, target: Vector) -> None:
	object_.rotation_euler = (target - object_.location).to_track_quat("-Z", "Y").to_euler()


camera = bpy.data.objects.new("Review camera", bpy.data.cameras.new("Review camera"))
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.55
camera.location = (4.3, -6.5, 3.0)
aim(camera, Vector((0, 0, 0.72)))
scene.collection.objects.link(camera)
scene.camera = camera
for name, location, energy, color in (
	("Key", (4, -3, 5), 1100, (1.0, 0.78, 0.60)),
	("Rim", (-4, 2, 4), 750, (0.30, 0.72, 1.0)),
	("Fill", (0, 4, 2), 320, (1.0, 0.22, 0.55)),
):
	light = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
	light.data.energy = energy
	light.data.shape = "DISK"
	light.data.size = 4.0
	light.location = location
	aim(light, Vector((0, 0, 0.75)))
	scene.collection.objects.link(light)

for action in bpy.data.actions:
	armature.animation_data_create()
	armature.animation_data.action = action
	start, end = action.frame_range
	scene.frame_set(round((start + end) * 0.5))
	clean = "".join(c if c.isalnum() else "_" for c in action.name).strip("_")
	scene.render.filepath = str(out_dir / (clean + ".png"))
	bpy.ops.render.render(write_still=True)
	print("MESHY_MOTION_FRAME", action.name, start, end)
