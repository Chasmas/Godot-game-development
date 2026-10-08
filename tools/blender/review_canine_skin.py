"""Render rest and modest joint stress poses from a staged canine rig."""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
out = ROOT / "build/canine_review/shepherd"
animated = "--trot" in sys.argv
bpy.ops.wm.open_mainfile(filepath=str(out / ("trot_candidate.blend" if animated else "rig_candidate.blend")))
arm = bpy.data.objects["CanineRig"]
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name != "WeightProxy")
center = Vector((0, 0, 0))
bpy.ops.object.camera_add(location=(2.5, -3.5, 2.1))
camera = bpy.context.object
camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.5
bpy.context.scene.camera = camera
for location, energy in [((2, -3, 4), 1000), ((-2, 1, 3), 600)]:
    bpy.ops.object.light_add(type="AREA", location=location)
    lamp = bpy.context.object
    lamp.rotation_euler = (center - lamp.location).to_track_quat("-Z", "Y").to_euler()
    lamp.data.energy = energy
    lamp.data.size = 3
scene = bpy.context.scene
scene.world = bpy.data.worlds.new("ReviewWorld")
scene.world.color = (0.08, 0.08, 0.08)
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 900
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
for name in (["trot_01", "trot_07", "trot_13", "trot_19"] if animated else ["rest", "joint_stress"]):
    if animated:
        scene.frame_set(int(name.split("_")[1]))
    if name == "joint_stress":
        for bone_name, angle in [("FrontUpper.L", -20), ("FrontLower.L", 30), ("HindUpper.R", 20), ("HindLower.R", -30), ("Head", 10)]:
            bone = arm.pose.bones[bone_name]
            bone.rotation_mode = "XYZ"
            bone.rotation_euler.x = math.radians(angle)
    scene.render.filepath = str(out / (name + ".png"))
    bpy.ops.render.render(write_still=True)
