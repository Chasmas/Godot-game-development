"""Blender (run inside it): every animation of a rigged character rendered
from straight above into frame strips for the game.

  blender -b --python tools/art/render_cast3d.py -- <char_dir> <out_dir> [--size 256] [--meters 2.4] [--fps 12]

<char_dir> holds anim_<name>.glb (Meshy). For each animation, frames are
sampled at `fps`, the camera fixed in scale (`meters` of floor across the
frame, the same for every animation and every character, so they share one
scale) and following the hips so a travelling move stays centred. The
figure faces +X (the game's forward). Per frame the hands' positions are
written (pixels from the frame centre, +x forward, +y to her right as seen
from above) so the game can put a gun in the right hand.

Writes <out_dir>/<anim>/f00.png ... and <out_dir>/meta.json.
"""
import bpy, sys, os, math, json, glob
from mathutils import Vector, Quaternion, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = map(os.path.abspath, argv[:2])
size = int(argv[argv.index("--size") + 1]) if "--size" in argv else 256
meters = float(argv[argv.index("--meters") + 1]) if "--meters" in argv else 2.4
fps = float(argv[argv.index("--fps") + 1]) if "--fps" in argv else 24.0
close_path = json.load(open(argv[argv.index("--car-door-path") + 1])) if "--car-door-path" in argv else None
only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None
hold_compact = "--hold-compact" in argv
held_tucked = "--held-tucked" in argv
smoke_fitted = "--smoke-fitted" in argv
smoke_fixed_pole = "--smoke-fixed-pole" in argv
seat_world = "--seat-world" in argv
seat_reference = json.load(open(argv[argv.index("--seat-reference")+1])) if "--seat-reference" in argv else None
car_exit_door = "--car-exit-door" in argv
car_exit_planted = "--car-exit-planted" in argv or car_exit_door
car_exit_grounded = "--car-exit-grounded" in argv or car_exit_planted
car_exit_smooth = "--car-exit-smooth" in argv or car_exit_grounded
punch_extended = "--punch-extended" in argv
stab_extended = "--stab-extended" in argv or os.path.basename(src).lower() == "cass"
# Oblique mode: a fixed camera `elev` degrees above the floor and the figure
# turned on the spot into `dirs` facings (game angle 0 = right, 90 = screen down),
# so the game picks a facing instead of rotating a top-down picture.
elev = float(argv[argv.index("--elev") + 1]) if "--elev" in argv else None
dirs = int(argv[argv.index("--dirs") + 1]) if "--dirs" in argv else 1
LOOK_Z = 0.82   # the camera aims this high above the ground point under the hips
# Bake mode: no rendering. Every clip's final pose (Meshy clip + the grip IK below)
# is recorded per sample and written as one action per clip onto a clean copy of
# the rig, exported as a single GLB the game draws in real time (CastModel).
bake_out = os.path.abspath(argv[argv.index("--bake") + 1]) if "--bake" in argv else None
baked, baked_rate = {}, {}
if bake_out:
    dirs, elev = 1, None
os.makedirs(out, exist_ok=True)

meta = {"size": size, "meters": meters, "fps": fps, "anims": {}}
if elev is not None:
    meta.update({"elevation": elev, "directions": dirs})

CALM = ("idle", "punch", "punch_left", "stab", "melee", "grab", "held", "doze", "smoke", "drink", "eat", "aim_melee", "drive", "car_exit", "car_close")
SEATED = ("drive", "car_exit", "doze", "car_close")

def sit_pose(arm, s):
    """Blend the rest pose toward sitting in a car seat (s 0..1): hips down 45 cm,
    thighs forward, knees bent. Bone frames: armature Z up, centimetres, the
    figure facing -Y, each leg bone's local X lateral (see tools/art notes)."""
    hips = arm.pose.bones.get("Hips")
    if hips:
        hips.location = (0.0, -45.0 * s, 0.0)
    for side in ("Left", "Right"):
        thigh = arm.pose.bones.get(side + "UpLeg")
        shin = arm.pose.bones.get(side + "Leg")
        if thigh:
            thigh.rotation_quaternion = Quaternion((1, 0, 0), -math.radians(88) * s)
        if shin:
            shin.rotation_quaternion = Quaternion((1, 0, 0), math.radians(85) * s)
        if seat_world:
            # Convert the actual world lateral hinge into each bone frame.
            for pb, angle in ((thigh,-88),(shin,85)):
                if pb:
                    orientation = (arm.matrix_world @ pb.bone.matrix_local).to_quaternion()
                    axis = orientation.inverted() @ Vector((0,1,0))
                    pb.rotation_quaternion = Quaternion(axis,math.radians(angle)*s)

def face_offset(x, y, theta):
    """A forward/side offset (+x forward) turned to the game facing `theta`."""
    return x * math.cos(theta) + y * math.sin(theta), -x * math.sin(theta) + y * math.cos(theta)

def combat_curve(k, keys):
    """Authored anticipation, contact and recovery; holds both endpoint poses."""
    for (a, va), (b, vb) in zip(keys, keys[1:]):
        if k <= b:
            t = max(0.0, min(1.0, (k - a) / (b - a)))
            t = t * t * (3.0 - 2.0 * t)
            return va + (vb - va) * t
    return keys[-1][1]

def repair_arms(arm):
    """Meshy exports arm tails 100x too long despite correct joint heads.
    Repair lengths without changing the joint positions (the IK needs real
    lengths). Baked clips are keyed against this same repaired rest."""
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for side in ("Right", "Left"):
        for parent, child in (("Shoulder", "Arm"), ("Arm", "ForeArm"), ("ForeArm", "Hand")):
            b = arm.data.edit_bones.get(side + parent)
            c = arm.data.edit_bones.get(side + child)
            if b and c:
                b.tail = c.head
        hand = arm.data.edit_bones.get(side + "Hand")
        if hand:
            hand.length = 7.0
    bpy.ops.object.mode_set(mode="OBJECT")

def setup_scene(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    sc = bpy.context.scene
    objs = list(sc.objects)
    facing = bpy.data.objects.new("game_facing", None)
    sc.collection.objects.link(facing)
    for o in [o for o in objs if o.parent is None]:
        o.parent = facing
    facing.rotation_euler.z = math.radians(90)  # parent survives animated root transforms
    bpy.context.view_layer.update()
    arm = next((o for o in objs if o.type == "ARMATURE"), None)
    if arm:
        repair_arms(arm)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = meters
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    cam.location = (0, 0, 20)
    if elev is not None:
        # looking toward +Y and down: screen down stays world -Y, as in top-down mode
        cam.rotation_euler = (math.radians(90 - elev), 0, 0)
    sc.camera = cam
    for name, e, col, rot in (("key", 3.2, (1.0, 0.9, 0.8), (35, 0, 135)), ("rim", 1.6, (0.35, 0.8, 1.0), (60, 0, -45)), ("fill", 0.6, (1.0, 0.4, 0.7), (50, 0, 45))):
        ld = bpy.data.lights.new(name, "SUN"); ld.energy = e; ld.color = col
        lo = bpy.data.objects.new(name, ld); lo.rotation_euler = [math.radians(a) for a in rot]
        sc.collection.objects.link(lo)
    w = bpy.data.worlds.new("w"); w.color = (0.03, 0.02, 0.05); sc.world = w
    if elev is not None:
        # seen from the side, dark uniforms lose their folds without some sky light
        w.color = (0.30, 0.30, 0.38)
        sc.objects["key"].data.energy = 4.2
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.eevee.taa_render_samples = 8
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    return sc, arm, cam

def bone(arm, keys):
    for b in arm.pose.bones:
        n = b.name.lower()
        if all(k in n for k in keys):
            return b
    return None

from bpy_extras.object_utils import world_to_camera_view

clips = [(os.path.basename(p)[5:-4], p) for p in sorted(glob.glob(os.path.join(src, "anim_*.glb"))) if not p.endswith("anim_doze.glb")]
clips += [("armed_" + n, os.path.join(src, "anim_" + n + ".glb")) for n in ("walk", "run", "sneak")]
clips += [("reload_" + n, os.path.join(src, "anim_aim.glb")) for n in ("mag", "shell", "dual")]
clips += [("punch_left", os.path.join(src, "anim_idle.glb"))]
clips += [("stab", os.path.join(src, "anim_idle.glb"))]
clips += [("aim_dual", os.path.join(src, "anim_aim.glb"))]
clips += [("armed_dual_" + n, os.path.join(src, "anim_" + n + ".glb")) for n in ("walk", "run", "sneak")]
clips += [("aim_melee", os.path.join(src, "anim_idle.glb"))]
clips += [("armed_melee_" + n, os.path.join(src, "anim_" + n + ".glb")) for n in ("walk", "run", "sneak")]
clips += [(n, os.path.join(src, "anim_idle.glb")) for n in ("smoke", "drink", "eat")]
clips += [(n, os.path.join(src, "anim_idle.glb")) for n in ("grab", "held")]
clips += [(n, os.path.join(src, "anim_idle.glb")) for n in SEATED]
clips += [("chainsaw_raise", os.path.join(src, "anim_idle.glb"))]
for name, path in clips:
    if name in ("aim", "punch", "punch_left", "melee"):
        path = os.path.join(src, "anim_idle.glb")
    if only and name not in only:
        continue
    if not os.path.exists(path):
        print("skip", name, "(no", os.path.basename(path) + ")")
        continue
    sc, arm, cam = setup_scene(path)
    if name in ("chainsaw_raise", "aim", "aim_dual", "aim_melee", "smoke", "drink", "eat", "idle", "walk", "run", "sneak", "punch", "punch_left", "stab", "melee", "grab", "held") + SEATED or name.startswith(("armed_", "reload_")):
        # Local IK reuses the purchased rig: hands share a stable firing line.
        for side, x, y in (("Right", 0.28, -0.14), ("Left", 0.34, -0.10)):
            forearm = arm.pose.bones.get(side + "ForeArm")
            if forearm:
                target = bpy.data.objects.new(side + "_grip", None)
                sc.collection.objects.link(target)
                hips_b = bone(arm, ["hip"])
                target.parent = arm
                target.parent_type = "BONE"
                target.parent_bone = hips_b.name
                bpy.context.view_layer.update()
                # Set per-frame below, following hips without inheriting their spin.
                target.parent = None
                ik = forearm.constraints.new("IK")
                ik.target = target
                ik.chain_count = 2
                ik.use_stretch = False
                pole = bpy.data.objects.new(side + "_elbow", None)
                sc.collection.objects.link(pole)
                pole["side"] = -1 if side == "Right" else 1
                ik.pole_target = pole
                target["grip_x"], target["grip_y"] = x, y
    # Meshy's idle is a wide-legged combat stance: everything built on it stands
    # on the rig's rest pose instead (arms brought down by the grip IK, a breath
    # in the spine), so standing still reads calm.
    calm = name in CALM or name in ("aim", "chainsaw_raise")
    if calm and arm and arm.animation_data:
        arm.animation_data.action = None
        for pb in arm.pose.bones:
            pb.location, pb.rotation_quaternion, pb.scale = (0, 0, 0), (1, 0, 0, 0), (1, 1, 1)
    foot_support = []
    foot_plants = {}
    close_feet = {}
    if (name == "car_exit" and car_exit_grounded) or name == "car_close" or (name == "doze" and seat_world):
        # Exported leg tails can exceed the actual knee/ankle joints. IK must
        # solve the anatomical lengths, without moving heads or changing bind.
        bpy.context.view_layer.objects.active = arm
        arm.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        for side in ("Left", "Right"):
            for parent, child in (("UpLeg", "Leg"), ("Leg", "Foot")):
                arm.data.edit_bones[side + parent].tail = arm.data.edit_bones[side + child].head
        bpy.ops.object.mode_set(mode="POSE")
        bpy.context.view_layer.update()
        for side in ("Left", "Right"):
            foot = arm.pose.bones.get(side + "Foot")
            shin = arm.pose.bones.get(side + "Leg")
            if not foot or not shin:
                raise RuntimeError("Car exit needs named leg/foot bones")
            rest_at = arm.matrix_world @ foot.head
            target = bpy.data.objects.new(side + "_foot_support", None)
            sc.collection.objects.link(target)
            target.location = rest_at
            ik = shin.constraints.new("IK")
            ik.target = target
            ik.chain_count = 2
            ik.use_stretch = False
            ik.influence = 0.0
            if name == "doze" and seat_world:
                pole = bpy.data.objects.new(side + "_knee_support",None)
                sc.collection.objects.link(pole)
                ik.pole_target = pole
            foot_support.append((foot, target, ik, rest_at.z))
            close_feet[foot.name] = rest_at.copy()
    act = arm.animation_data.action if arm and arm.animation_data and arm.animation_data.action else None
    f0, f1 = tuple(act.frame_range) if act else (1.0, 1.0)
    authored = name in ("chainsaw_raise", "aim", "punch", "punch_left", "stab", "melee", "grab", "held", "smoke", "drink", "eat", "idle", "aim_melee") + SEATED
    if authored:
        f1 = f0
    src_fps = sc.render.fps / sc.render.fps_base
    step = max(1, int(round(src_fps / fps)))
    hips = bone(arm, ["hip"]) or bone(arm, ["pelvis"])
    close_hip_rest = hips.matrix.copy() if name == "car_close" and hips else None
    hand_r = bone(arm, ["right", "hand"]) or bone(arm, ["hand", "r"])
    hand_l = bone(arm, ["left", "hand"]) or bone(arm, ["hand", "l"])
    duration = max((f1 - f0) / src_fps, 1.0 / fps)
    if authored:
        duration = {"chainsaw_raise": 0.45, "smoke": 4.0, "drink": 5.0, "eat": 4.5, "idle": 3.2, "doze": 3.2, "aim_melee": 2.4, "drive": 2.0, "car_exit": 0.9, "grab": 0.8, "held": 0.8}.get(name, 0.4)
    if name == "car_exit" and car_exit_smooth:
        duration = 1.2
    if name == "car_close":
        duration = 0.85
    sample_fps = max(fps, 120) if punch_extended and name in ("punch", "punch_left") else fps
    count = min(512, max(2, math.ceil(duration * sample_fps)))
    frames = [f0 + (f1 - f0) * i / (count - 1) for i in range(count)]
    if "--preview" in argv:
        frames = [f0]
    os.makedirs(os.path.join(out, name), exist_ok=True)
    info = {"frames": len(frames), "duration": duration, "fps": len(frames) / duration, "hands": [], "hips": [], "angles": []}
    px = size / meters
    anchor = None
    facing_obj = sc.objects["game_facing"]
    for d, i, f in [(d, i, f) for d in range(dirs) for i, f in enumerate(frames)]:
        theta = 2 * math.pi * d / dirs if elev is not None else 0.0
        facing_obj.rotation_euler.z = math.radians(90) - theta
        sc.frame_set(math.floor(f), subframe=f % 1.0)
        hp = arm.matrix_world @ hips.head if hips else Vector((0, 0, 0))
        k = i / max(len(frames) - 1, 1)
        if close_hip_rest is not None:
            hips.matrix = close_hip_rest.copy()
        if calm:
            # one slow breath per loop (k 0 and 1 match, so it loops cleanly)
            spine = bone(arm, ["spine"])
            if spine:
                spine.rotation_quaternion = Quaternion((1, 0, 0), 0.03 * math.sin(k * 2 * math.pi))
        if name in ("punch", "punch_left", "melee"):
            turn = combat_curve(k, [(0, 0), (0.22, -0.35), (0.48, 0.42), (0.58, 0.42), (1, 0)] if punch_extended and name in ("punch", "punch_left") else [(0, 0), (0.22, -0.35), (0.52, 0.42), (1, 0)])
            if name == "punch_left":
                turn = -turn
            for spine_name, share in (("Spine", 0.35), ("Spine01", 0.35), ("Spine02", 0.30)):
                pb = arm.pose.bones.get(spine_name)
                if pb:
                    pb.rotation_quaternion = Quaternion((0, 1, 0), turn * share)
        if name == "stab":
            turn = combat_curve(k, [(0, 0), (0.22, -0.12), (0.52, 0.18), (1, 0)])
            for spine_name, share in (("Spine", 0.35), ("Spine01", 0.35), ("Spine02", 0.30)):
                pb = arm.pose.bones.get(spine_name)
                if pb:
                    pb.rotation_quaternion = Quaternion((0, 1, 0), turn * share)
        seat = 0.0
        if name in SEATED:
            # how far into the seat: held for "drive"; "car_exit" rises out of it
            # (the game plays it backwards to get in)
            # getting out starts with the legs already swung out, feet on the ground: half
            # seated. Fully seated (thighs flat) seen from 50 deg outside the car reads as lying down.
            seat = 1.0 if name in ("drive", "doze") else 0.55 * (1.0 - k * k * (3.0 - 2.0 * k))
            if name == "car_exit" and car_exit_smooth:
                # Match the fully seated drive pose before shifting weight and rising.
                seat = combat_curve(k, [(0, 1), (0.18, 1), (0.38, 0.65), (0.88, 0), (1, 0)])
            if name == "car_close": seat = 0.0
            sit_pose(arm, seat)
            if seat_world and name in SEATED and hips:
                # Use world height; retargeted hip local axes differ by model.
                pose = hips.bone.matrix_local.copy()
                drop = -0.45*seat
                if seat_reference and name == "doze":
                    rest_height = (arm.matrix_world @ pose.translation).z
                    drop = (0.55-rest_height)*seat
                pose.translation += arm.matrix_world.inverted().to_3x3() @ Vector((0,0,drop))
                hips.matrix = pose
            if name == "car_close":
                lean = combat_curve(k, [(0,0), (.18,1), (.32,1), (.65,0), (1,0)])
                offset = arm.matrix_world.inverted().to_3x3() @ Vector((-0.10,-0.22,-0.08))
                pose = close_hip_rest.copy()
                pose.translation += offset * lean
                hips.matrix = pose
            bpy.context.view_layer.update()
            hp = arm.matrix_world @ hips.head if hips else hp   # the grips follow the lowered hips
        for target in [o for o in sc.objects if "grip_x" in o]:
            x, y, z = target["grip_x"], target["grip_y"], 0.30
            right = target.name.startswith("Right")
            if name in ("idle", "walk", "run", "sneak") + SEATED:
                swing = math.sin(k * math.pi * 2) * (0.10 if name != "idle" else 0.005)
                x, y, z = 0.04 + swing * (1 if right else -1), (-0.22 if right else 0.22), 0.04
                if name in SEATED:
                    # hands on the wheel while seated, down by the thighs once standing
                    wx, wy, wz = 0.36, (-0.17 if right else 0.17), 0.30
                    sx, sy, sz = 0.03, (-0.25 if right else 0.25), -0.12
                    x, y, z = sx + (wx - sx) * seat, sy + (wy - sy) * seat, sz + (wz - sz) * seat
                    if name == "doze":
                        x, y, z = 0.18, (-0.18 if right else 0.18), -0.14
                if name == "idle":
                    # standing on the rest pose: arms hang beside the thighs, not on the hips
                    x, y, z = 0.03, (-0.25 if right else 0.25), -0.12
            elif name == "stab":
                strike = combat_curve(k, [(0, 0), (0.22, -0.45), (0.55, 1), (0.62, 1), (1, 0)] if stab_extended else [(0, 0), (0.22, -0.35), (0.52, 1), (0.62, 0.8), (1, 0)])
                if right:
                    x, y, z = 0.20 + (0.42 if stab_extended else 0.25) * strike, -0.12 + 0.04 * max(0, strike), 0.28
                else:
                    x, y, z = 0.10 - 0.025 * strike, 0.22, 0.24
            elif name in ("punch", "punch_left"):
                active = right if name == "punch" else not right
                strike = combat_curve(k, [(0, 0), (0.22, -0.40), (0.48, 1), (0.58, 1), (1, 0)] if punch_extended else [(0, 0), (0.22, -0.35), (0.48, 1), (1, 0)]) if active else 0
                x = 0.18 + (0.40 if punch_extended else 0.28) * strike
                y = (-1 if right else 1) * (0.16 - 0.09 * max(0, strike))
                z = 0.31
            elif name == "melee":
                turn = combat_curve(k, [(0, 0.59), (0.22, -1.2), (0.58, 1.05), (1, 0.59)])
                radius = 0.29 + (0 if right else 0.045)
                join = combat_curve(k, [(0, 0), (0.22, 1), (0.7, 1), (1, 0)])
                ready = Vector((0.24, -0.16, 0.22) if right else (0.04, 0.22, 0.04))
                arc = Vector((radius * math.cos(turn), -radius * math.sin(turn), 0.30))
                x, y, z = ready.lerp(arc, join)
            elif name in ("grab", "held"):
                close = combat_curve(k, [(0, 0), (0.22, 1), (0.78, 1), (1, 0)])
                ready = Vector((0.03, -0.25 if right else 0.25, -0.12))
                if name == "grab":
                    # Rear hold: right forearm across the target's neck;
                    # left hand braces the wrist. Both return after release.
                    grip = Vector((0.35 if right else 0.32, 0.10 if right else -0.04, 0.46 if right else 0.45)) if hold_compact else Vector((0.57 if right else 0.43, 0.05 if right else -0.10, 0.48))
                else:
                    # The held target reaches toward the restraining forearm.
                    if held_tucked:
                        head_bone = arm.pose.bones.get("Head")
                        head_z = (arm.matrix_world @ head_bone.head).z if head_bone else hp.z + 0.42
                        # Fit the defending hands below this model's actual face,
                        # rather than a fixed hip offset that lifts short heads overhead.
                        hand_z = max(0.18, min(0.40, head_z - hp.z - 0.12))
                        grip = Vector((0.16, -0.08 if right else 0.08, hand_z))
                    else:
                        grip = Vector((0.12, -0.10 if right else 0.10, 0.30))
                x, y, z = ready.lerp(grip, close)
            elif name.startswith("reload_"):
                shell = name == "reload_shell"
                tilt = (0.55 if shell else 0.8) * math.sin(min(k / (0.12 if shell else 0.15), 1) * math.pi / 2) * (1 - max(0, min((k - (0.86 if shell else 0.82)) / (0.1 if shell else 0.14), 1)))
                x -= 0.10 * tilt
                y -= 0.075 * tilt
                if target.name.startswith("Left") and name != "reload_dual":
                    reach = max(0, min((k - 0.3) / 0.35, 1))
                    reach = 1 - (1 - reach) ** 3
                    if k < 0.7:
                        x = -0.10 + (0.46 + 0.10) * reach
                        y = 0.35 + (-0.24 - 0.35) * reach
                        z = 0.04 + 0.26 * reach
            if name in ("smoke", "drink", "eat"):
                # A gentle lift, held draw, then lower; both ends share the relaxed pose.
                lift = min(max(k / 0.22, 0), 1) * (1 - min(max((k - 0.48) / 0.25, 0), 1))
                lift = lift * lift * (3 - 2 * lift)
                x, y, z = (0.04 + 0.10 * lift, -0.22 + 0.18 * lift, 0.04 + 0.46 * lift) if right else (0.04, 0.22, 0.04)
                if smoke_fitted or name in ("drink", "eat"):
                    head = arm.pose.bones.get("Head") or bone(arm,["head"])
                    bpy.context.view_layer.update()
                    mouth_z = (arm.matrix_world @ head.head).z - hp.z - 0.035
                    low = Vector((0.04,-0.22 if right else 0.22,-0.12))
                    high = Vector((0.10,-0.025,mouth_z))
                    x,y,z = low.lerp(high,lift) if right else low
            if "melee" in name and name != "melee":
                x, y, z = (0.24, -0.16, 0.22) if right else (0.04, 0.22, 0.04)
            if "dual" in name:
                x = 0.28
                y = -0.20 if right else 0.20
            x, y = face_offset(x, y, theta)
            if name in ("chainsaw_raise", "aim", "armed_walk", "armed_run", "armed_sneak"):
                # Rear trigger grip and forward wrap handle, low at the waist.
                ready = Vector((0.08, -0.12, 0.08) if right else (0.327, -0.12, 0.2295))
                if name == "chainsaw_raise":
                    start = Vector((0.03, -0.25 if right else 0.25, -0.12))
                    t = min(1.0, k / (0.72 if right else 0.9))
                    ready = start.lerp(ready, t*t*(3-2*t))
                x, y, z = ready
            target.location = (hp.x + x, hp.y + y, hp.z + z)
            if name == "car_close" and close_path and right:
                rows = close_path["rows"]
                index = min(len(rows)-2, int(k*(len(rows)-1)))
                t = k*(len(rows)-1)-index
                point = Vector(rows[index]["point"]).lerp(Vector(rows[index+1]["point"]), t)
                root = close_path["driver_at"]
                contact = Vector((point.x-root[0], -(point.z-root[2]), point.y-root[1]))
                reach = combat_curve(k, [(0,0), (.18,1), (.32,1), (.52,0), (1,0)])
                target.location = Vector(target.location).lerp(contact,reach)
            if name == "car_exit" and car_exit_door and right:
                out_step = 0.15 + 0.85 * k * k * (3.0 - 2.0 * k)
                back_step = max(0.0, min(1.0, (out_step - 0.55) / 0.45))
                # Measured inner upper door edge with door fully open in CarModel.
                contact = Vector((1.171825 - (0.387361765 + 0.92 * out_step),
                                  -(0.234360 - 0.027599953 + 0.48 * back_step**2), 1.10))
                grip_weight = combat_curve(k, [(0, 0), (0.18, 0), (0.36, 1), (0.66, 1), (0.90, 0), (1, 0)])
                target.location = Vector(target.location).lerp(contact, grip_weight)
        for pole in [o for o in sc.objects if "side" in o]:
            px_, py_ = face_offset(0.12 if name == "held" and held_tucked else -0.12, pole["side"] * (0.34 if name == "held" and held_tucked else 0.26), theta)
            pole.location = (hp.x + px_, hp.y + py_, hp.z + 0.08)
        bpy.context.view_layer.update()
        if (i == 0 and d == 0) or (name == "held" and held_tucked) or (name in ("smoke", "drink", "eat") and (smoke_fitted or name != "smoke") and not smoke_fixed_pole):
            # Bone roll differs left/right after retargeting. Pick the pole angle
            # whose elbow is closest to a tucked, anatomically neutral position.
            for side in ("Right", "Left"):
                forearm = arm.pose.bones.get(side + "ForeArm")
                ik = next((c for c in forearm.constraints if c.type == "IK"), None) if forearm else None
                if ik and ik.pole_target:
                    goal = Vector((hp.x + 0.02, hp.y + (-0.23 if side == "Right" else 0.23), hp.z + 0.10))
                    best = (float("inf"), 0)
                    for step in range(24):
                        angle = (-math.pi if (name == "held" and held_tucked) or (name in ("smoke", "drink", "eat") and (smoke_fitted or name != "smoke")) else 0.0) + 2 * math.pi * step / 24
                        ik.pole_angle = angle
                        bpy.context.view_layer.update()
                        elbow = arm.matrix_world @ forearm.head
                        distance = (elbow - goal).length_squared
                        if "--debug-held" in argv and name == "held" and i == len(frames) // 2:
                            print("HELD_POLE", side, step, tuple(elbow), tuple(goal), distance)
                        if distance < best[0]: best = (distance, angle)
                    if name in ("smoke", "drink", "eat") and (smoke_fitted or name != "smoke"):
                        # Refine the pole continuously around the coarse optimum;
                        # coarse 15-degree choices otherwise pop the elbow.
                        for radius in (math.pi/12,math.pi/60,math.pi/300):
                            center = best[1]
                            for fine in range(-5,6):
                                angle = (center+radius*fine/5+math.pi) % (2*math.pi)-math.pi
                                ik.pole_angle = angle
                                bpy.context.view_layer.update()
                                loss = ((arm.matrix_world @ forearm.head)-goal).length_squared
                                if loss < best[0]: best = (loss,angle)
                    ik.pole_angle = best[1]
                    bpy.context.view_layer.update()
                    print("ELBOW", name, side, round(best[1], 3), tuple(arm.matrix_world @ forearm.head))
        if name == "smoke" and "--debug-smoke" in argv and i == len(frames)//3:
            head_debug = bone(arm,["head"])
            hand_debug = arm.pose.bones.get("RightHand")
            print("SMOKE_CONTACT", head_debug.name, tuple(arm.matrix_world @ head_debug.head),
                  tuple(arm.matrix_world @ hand_debug.head),
                  [(o.name,tuple(o.location)) for o in sc.objects if "grip_x" in o])
        if foot_support:
            # Preserve the authored seated start and standing handoff. During
            # the lift, solve both legs to the standing ankle/boot height.
            for foot, target, ik, floor_z in foot_support:
                ik.influence = 0.0
            bpy.context.view_layer.update()
            weight = combat_curve(k, [(0, 0), (0.18, 0), (0.38, 1), (0.85, 1), (1, 0)])
            for foot, target, ik, floor_z in foot_support:
                at = arm.matrix_world @ foot.head
                target.location = (at.x, at.y, floor_z)
                if car_exit_planted and k >= 0.42:
                    out_step = 0.15 + 0.85 * k * k * (3.0 - 2.0 * k)
                    back_step = max(0.0, min(1.0, (out_step - 0.55) / 0.45))
                    if foot.name not in foot_plants:
                        foot_plants[foot.name] = (at.copy(), out_step, back_step)
                    planted, start_out, start_back = foot_plants[foot.name]
                    # In the exported facing, Preview X maps to car X and
                    # preview Y to -car Z after the clean-rig export. Counter the controller's root path.
                    locked = Vector((planted.x - 0.92 * (out_step - start_out),
                                     planted.y - 0.48 * (back_step**2 - start_back**2), floor_z))
                    blend = combat_curve(k, [(0.42, 0), (0.48, 1), (0.68, 1), (0.88, 0), (1, 0)])
                    target.location = Vector(target.location).lerp(locked, blend)
                ik.influence = weight
                if name == "car_close":
                    target.location = close_feet[foot.name]
                    ik.influence = 1.0
                if name == "doze" and seat_world:
                    side = -1 if foot.name.startswith("Right") else 1
                    support_height = seat_reference["rows"][0]["bones"][foot.name][1] if seat_reference else 0.10
                    target.location = (hp.x+0.32,hp.y+0.13*side,support_height)
                    ik.pole_target.location = (hp.x+0.6,hp.y+0.13*side,hp.z)
                    ik.influence = 1.0
                    goal = Vector((hp.x+0.28,hp.y+0.13*side,hp.z-0.03))
                    knee = arm.pose.bones["RightLeg" if side == -1 else "LeftLeg"]
                    best = (float("inf"),0.0)
                    for angle_index in range(24):
                        angle = -math.pi+2*math.pi*angle_index/24
                        ik.pole_angle = angle
                        bpy.context.view_layer.update()
                        loss = ((arm.matrix_world @ knee.head)-goal).length_squared
                        if loss < best[0]: best = (loss,angle)
                    ik.pole_angle = best[1]
            bpy.context.view_layer.update()
            if name == "doze" and seat_world and seat_reference:
                # Keep the boots in their standing orientation after leg IK.
                for foot, target, ik, floor_z in foot_support:
                    pose = foot.matrix.copy()
                    foot.matrix = Matrix.LocRotScale(pose.translation,foot.bone.matrix_local.to_quaternion(),pose.to_scale())
                bpy.context.view_layer.update()
        if bake_out:
            # the visual pose, constraints included, as each bone's local transform
            baked.setdefault(name, []).append({pb.name: arm.convert_space(pose_bone=pb, matrix=pb.matrix, from_space="POSE", to_space="LOCAL").copy() for pb in arm.pose.bones})
            # Samples include both endpoints: N poses have N-1 time intervals.
            baked_rate[name] = (len(frames) - 1) / duration
            continue
        if anchor is None:
            anchor = hp.copy()
        if elev is not None:
            # follow the ground point under the hips, aiming a little above it
            e = math.radians(elev)
            cam.location = (hp.x, hp.y - math.cos(e) * 20, LOOK_Z + math.sin(e) * 20)
            bpy.context.view_layer.update()
            sc.render.filepath = os.path.join(out, name, "d%02d_f%02d.png" % (d, i))
        else:
            cam.location.x, cam.location.y = hp.x, hp.y
            sc.render.filepath = os.path.join(out, name, "f%02d.png" % i)
        bpy.ops.render.render(write_still=True)
        def screen(p):
            v = world_to_camera_view(sc, cam, p)
            return Vector((v.x * size, (1 - v.y) * size))
        ground = screen(Vector((hp.x, hp.y, 0))) if elev is not None else None
        if elev is not None and "origin" not in meta:
            meta["origin"] = [round(ground.x, 1), round(ground.y, 1)]
        def rel(b):
            if b is None:
                return [0, 0]
            # the wrist and 7 cm on toward the fingers: where a grip sits
            # (Meshy's hand bones end far out, so the tail itself can't be used)
            h = arm.matrix_world @ b.head
            dv = (arm.matrix_world @ b.tail) - h
            p = h + (dv.normalized() * 0.07 if dv.length > 1e-6 else Vector((0, 0, 0)))
            if elev is not None:
                # oblique: screen pixels from the ground point (the game turns them into the rig)
                s = screen(p) - ground
                return [round(s.x, 1), round(s.y, 1)]
            # image x = world x (forward); image y = -world y (screen down is her right)
            return [round((p.x - hp.x) * px, 1), round(-(p.y - hp.y) * px, 1)]
        info["hands"].append([rel(hand_r), rel(hand_l)])
        if d > 0:
            continue
        if name == "melee":
            angle = -0.9 + 2.0 * math.sin(k * math.pi / 2)
            info["angles"].append(angle)
        else:
            info["angles"].append(0.0)
        if i == 0:
            hf = bone(arm, ["headfront"]) or bone(arm, ["head"])
            hd = arm.matrix_world @ hf.head - (arm.matrix_world @ bone(arm, ["neck"]).head if bone(arm, ["neck"]) else hp)
            print("FACING", name, round(hd.x, 3), round(hd.y, 3))
        if i == 0 and "--debug" in argv:
            print("DBG", hips and hips.name, hand_r and hand_r.name, hand_l and hand_l.name, tuple(hp), tuple(arm.matrix_world @ hand_r.tail), px)
        # how far the hips travelled from the first frame (a roll moves her)
        info["hips"].append([round((hp.x - anchor.x) * px, 1), round(-(hp.y - anchor.y) * px, 1)])
    if bake_out:
        print("anim", name, len(frames), "frames (baked)")
        continue
    if elev is not None:
        # hands per facing: [direction][frame]
        n = len(frames)
        info["hands"] = [info["hands"][d * n:(d + 1) * n] for d in range(dirs)]
    meta["anims"][name] = info
    print("anim", name, len(frames), "frames")
    # saved after every clip: a crash later in a long render keeps what is done
    mp = os.path.join(out, "meta.json")
    old = json.load(open(mp)) if os.path.exists(mp) else {"anims": {}}
    old["anims"].update(meta["anims"])
    json.dump(dict(meta, anims=old["anims"]), open(mp, "w"), indent=1)

if bake_out and baked:
    # a clean rig (same repaired rest the poses were taken against), one action per clip
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # --mesh: a reworked body on the same skeleton (e.g. tools/art/swap_hair.py output)
    body = os.path.abspath(argv[argv.index("--mesh") + 1]) if "--mesh" in argv else os.path.join(src, "anim_idle.glb")
    bpy.ops.import_scene.gltf(filepath=body)
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    repair_arms(arm)
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = None
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
    scene_fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for name, poses in baked.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        step = scene_fps / baked_rate[name]
        prev = {}
        for i, pose in enumerate(poses):
            frame = i * step
            for pb in arm.pose.bones:
                loc, rot, scl = pose[pb.name].decompose()
                if pb.name in prev and prev[pb.name].dot(rot) < 0:
                    rot.negate()   # shortest way round: no spins between samples
                prev[pb.name] = rot
                pb.location, pb.rotation_quaternion, pb.scale = loc, rot, scl
                for path in ("location", "rotation_quaternion", "scale"):
                    pb.keyframe_insert(path, frame=frame)
        arm.animation_data.action = None
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, act)
        track.mute = True
    os.makedirs(os.path.dirname(bake_out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=bake_out, export_format="GLB", export_animations=True,
                              export_animation_mode="NLA_TRACKS", export_image_format="AUTO")
    print("baked", bake_out, "clips:", list(baked))
