"""Author a staged diagonal trot with planted stance and lifted recovery."""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
out = ROOT / "build/canine_review/shepherd"
idle = "--idle" in sys.argv
walk = "--walk" in sys.argv
clip = "idle" if idle else ("walk" if walk else "trot")
bpy.ops.wm.open_mainfile(filepath=str(out / "rig_candidate.blend"))
arm = bpy.data.objects["CanineRig"]
scene = bpy.context.scene
scene.render.fps = 12 if idle else (20 if walk else 40)
scene.frame_start, scene.frame_end = 1, 25
targets = []
for limb in ["Front", "Hind"]:
    for side in ["L", "R"]:
        lower = arm.pose.bones[limb + "Lower." + side]
        ankle = arm.matrix_world @ lower.tail
        target = bpy.data.objects.new(limb + "Contact." + side, None)
        scene.collection.objects.link(target)
        target.location = ankle
        # Keep the paw's rest orientation in world space while the leg bends.
        # Inheriting the shin's rotation makes planted toes scrape through the floor.
        paw = arm.pose.bones[limb + "Paw." + side]
        orient = bpy.data.objects.new(limb + "SoleOrientation." + side, None)
        scene.collection.objects.link(orient)
        orient.matrix_world = arm.matrix_world @ paw.matrix
        rotation = paw.constraints.new("COPY_ROTATION")
        rotation.target = orient
        rotation.target_space = "WORLD"
        rotation.owner_space = "WORLD"
        ik = lower.constraints.new("IK")
        ik.target = target
        ik.chain_count = 2
        ik.use_stretch = False
        # Without a pole, the IK elbow/knee can flip across the limb's plane.
        # Match the rest knee before authoring any travel, then keep that plane.
        knee = arm.matrix_world @ lower.head
        pole = bpy.data.objects.new(limb + "BendPlane." + side, None)
        scene.collection.objects.link(pole)
        pole.location = knee + Vector((0, 0.5 if limb == "Front" else -0.5, 0))
        # The hind rest chain is close to straight: this provisional pole
        # reverses its bend and collapses the hip. Keep it disabled pending
        # anatomical landmark correction; only the front chain is constrained.
        ik.pole_target = pole if limb == "Front" else None
        best = (float("inf"), 0)
        for sample in range(48):
            angle = math.tau * sample / 48
            ik.pole_angle = angle
            bpy.context.view_layer.update()
            error = ((arm.matrix_world @ lower.head) - knee).length_squared
            if error < best[0]:
                best = (error, angle)
        ik.pole_angle = best[1]
        offset = {("Front", "L"): 0.0, ("Hind", "R"): 0.25,
                  ("Front", "R"): 0.5, ("Hind", "L"): 0.75}[(limb, side)] if walk else (0 if (limb == "Front") == (side == "L") else 0.5)
        targets.append((target, ankle.copy(), offset))
stride, lift, stance = 0.42, 0.11, 0.6
if walk:
    stride, lift, stance = 0.32, 0.065, 0.75
if idle:
    stride, lift, stance = 0.0, 0.0, 1.0
# A perfectly extended rest leg cannot reach a displaced stance contact.
# Lower the body slightly while keeping targets at the original floor height.
root = arm.pose.bones["Root"]
root.location = root.bone.matrix_local.to_3x3().inverted() @ Vector((0, 0, -0.06))
measurements = []
for frame in range(1, 26):
    scene.frame_set(frame)
    phase = (frame - 1) / 24
    for target, origin, offset in targets:
        t = (phase + offset) % 1
        if t < stance:
            y = stride * (t / stance - 0.5)
            z = 0
        else:
            recovery = (t - stance) / (1 - stance)
            smooth = recovery * recovery * (3 - 2 * recovery)
            y = stride * (0.5 - smooth)
            z = lift * math.sin(math.pi * recovery)
        target.location = origin + Vector((0, y, z))
        target.keyframe_insert(data_path="location", frame=frame)
        measurements.append({"frame": frame, "paw": target.name, "stance": t < stance, "lift": z})
    spine = arm.pose.bones["Spine"]
    spine.rotation_mode = "XYZ"
    spine.rotation_euler.x = math.radians(0.25 if idle else 1.5) * math.sin(phase * math.tau * (1 if idle else 2))
    spine.keyframe_insert(data_path="rotation_euler", frame=frame)
    if idle:
        # Restrained breathing and an alert glance, with all four soles planted.
        root.location = root.bone.matrix_local.to_3x3().inverted() @ Vector((0, 0, -0.06 + 0.002 * math.sin(phase * math.tau)))
        root.keyframe_insert(data_path="location", frame=frame)
        for name, axes in [("Neck", (0.8, 0.0, 0.8)), ("Head", (1.2, 0.0, 2.5)), ("Tail", (2.0, 0.0, 3.0))]:
            bone = arm.pose.bones[name]
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = tuple(math.radians(angle) * math.sin(phase * math.tau) for angle in axes)
            bone.keyframe_insert(data_path="rotation_euler", frame=frame)
# Targets are sampled every frame; linear interpolation preserves planted travel.
for target, _, _ in targets:
    action = target.animation_data.action
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = "LINEAR"
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(out / (clip + "_candidate.blend")))
duration = 24 / scene.render.fps
(out / (clip + "_contact_audit.json")).write_text(json.dumps({"candidate_only": True,
    "duration_seconds": duration, "stride_meters": stride, "paw_lift_meters": lift,
    "stance_fraction": stance,
    "paw_phase_offsets": {target.name: offset for target, _, offset in targets},
    "native_forward_speed_mps": stride / (stance * duration),
    "note": "Target contact audit only; skinned paw geometry and playback still require visual review.",
    "samples": measurements}, indent=2), encoding="utf-8")
print("Staged", clip, ": 4 IK contacts, 25 samples, stride", stride, "m, duration", duration, "seconds")
