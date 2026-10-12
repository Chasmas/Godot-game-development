"""Render pistol-orientation candidates on a staged Meshy guard firing clip."""
from pathlib import Path
import math

import bpy
from mathutils import Matrix, Vector


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/meshy_guard_rebuild_review/pistol_fit"
OUT.mkdir(parents=True, exist_ok=True)
source = ROOT / "assets/art/Artwork/3d/cast_redesign_v1/guard/motions/library_batch.fbx"
pistol = ROOT / "assets/art/weapons3d/staging/service_pistol_v3/service_pistol.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source))
armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
action = next(action for action in bpy.data.actions if "Walk_Forward_While_Shooting" in action.name)
armature.animation_data_create()
armature.animation_data.action = action
scene = bpy.context.scene
scene.frame_set(round(sum(action.frame_range) * .5))

before = set(scene.objects)
bpy.ops.import_scene.gltf(filepath=str(pistol))
added = set(scene.objects) - before
root = next(obj for obj in added if obj.name.startswith("ServicePistol"))
anchor = next(obj for obj in added if obj.name.startswith("GripAnchor"))
hand = armature.pose.bones["RightHand"]
hand_matrix = armature.matrix_world @ hand.matrix
anchor_local = anchor.matrix_local.translation.copy()

scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
world = bpy.data.worlds.new("Fit review world")
world.color = (.025, .03, .045)
scene.world = world


def aim(obj: bpy.types.Object, target: Vector) -> None:
	obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


camera = bpy.data.objects.new("Fit camera", bpy.data.cameras.new("Fit camera"))
camera.data.type = "ORTHO"
camera.data.ortho_scale = .9
scene.collection.objects.link(camera)
scene.camera = camera
for name, loc, color in (("Key", (3, -3, 4), (1, .75, .55)), ("Rim", (-3, 2, 3), (.25, .7, 1))):
	light = bpy.data.objects.new(name, bpy.data.lights.new(name, "AREA"))
	light.data.energy, light.data.size, light.data.color = 650, 3.0, color
	light.location = loc
	scene.collection.objects.link(light)

report = []
for degrees in (0, 90, 180, 270):
	rotation = Matrix.Rotation(math.radians(degrees), 4, "Z")
	root.matrix_world = hand_matrix @ rotation @ Matrix.Translation(-anchor_local)
	bpy.context.view_layer.update()
	grip = anchor.matrix_world.translation
	left = (armature.matrix_world @ armature.pose.bones["LeftHand"].matrix).translation
	right = hand_matrix.translation
	target = (left + right) * .5
	camera.location = target + Vector((.75, -1.0, .55))
	aim(camera, target)
	for light in (obj for obj in scene.objects if obj.type == "LIGHT"):
		aim(light, target)
	scene.render.filepath = str(OUT / f"pistol_orientation_{degrees:03}.png")
	bpy.ops.render.render(write_still=True)
	report.append({"degrees": degrees, "grip_right_hand_distance_m": (grip - right).length, "left_to_grip_distance_m": (left - grip).length})
(OUT / "orientation_report.json").write_text(__import__("json").dumps(report, indent=2), encoding="utf-8")
print("GUARD_PISTOL_ORIENTATION_REVIEW", report)
