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
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = map(os.path.abspath, argv[:2])
size = int(argv[argv.index("--size") + 1]) if "--size" in argv else 256
meters = float(argv[argv.index("--meters") + 1]) if "--meters" in argv else 2.4
fps = float(argv[argv.index("--fps") + 1]) if "--fps" in argv else 24.0
only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None
os.makedirs(out, exist_ok=True)

meta = {"size": size, "meters": meters, "fps": fps, "anims": {}}

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
        # Meshy exports arm tails 100x too long despite correct joint heads.
        # Repair lengths without changing the joint positions or rest rotations.
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
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = meters
    cam = bpy.data.objects.new("cam", cam_data)
    sc.collection.objects.link(cam)
    cam.location = (0, 0, 20)
    sc.camera = cam
    for name, e, col, rot in (("key", 3.2, (1.0, 0.9, 0.8), (35, 0, 135)), ("rim", 1.6, (0.35, 0.8, 1.0), (60, 0, -45)), ("fill", 0.6, (1.0, 0.4, 0.7), (50, 0, 45))):
        ld = bpy.data.lights.new(name, "SUN"); ld.energy = e; ld.color = col
        lo = bpy.data.objects.new(name, ld); lo.rotation_euler = [math.radians(a) for a in rot]
        sc.collection.objects.link(lo)
    w = bpy.data.worlds.new("w"); w.color = (0.03, 0.02, 0.05); sc.world = w
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

clips = [(os.path.basename(p)[5:-4], p) for p in sorted(glob.glob(os.path.join(src, "anim_*.glb")))]
clips += [("armed_" + n, os.path.join(src, "anim_" + n + ".glb")) for n in ("walk", "run", "sneak")]
clips += [("reload_" + n, os.path.join(src, "anim_aim.glb")) for n in ("mag", "shell", "dual")]
clips += [("punch_left", os.path.join(src, "anim_idle.glb"))]
clips += [("aim_dual", os.path.join(src, "anim_aim.glb"))]
clips += [("armed_dual_" + n, os.path.join(src, "anim_" + n + ".glb")) for n in ("walk", "run", "sneak")]
clips += [("aim_melee", os.path.join(src, "anim_idle.glb"))]
clips += [("armed_melee_" + n, os.path.join(src, "anim_" + n + ".glb")) for n in ("walk", "run", "sneak")]
clips += [("smoke", os.path.join(src, "anim_idle.glb"))]
for name, path in clips:
    if name in ("punch", "punch_left", "melee"):
        path = os.path.join(src, "anim_idle.glb")
    if only and name not in only:
        continue
    sc, arm, cam = setup_scene(path)
    if name in ("aim", "aim_dual", "aim_melee", "smoke", "idle", "walk", "run", "sneak", "punch", "punch_left", "melee") or name.startswith(("armed_", "reload_")):
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
    act = arm.animation_data.action if arm and arm.animation_data and arm.animation_data.action else None
    f0, f1 = tuple(act.frame_range) if act else (1.0, 1.0)
    authored = name in ("punch", "punch_left", "melee", "smoke")
    if authored:
        f1 = f0
    src_fps = sc.render.fps / sc.render.fps_base
    step = max(1, int(round(src_fps / fps)))
    hips = bone(arm, ["hip"]) or bone(arm, ["pelvis"])
    hand_r = bone(arm, ["right", "hand"]) or bone(arm, ["hand", "r"])
    hand_l = bone(arm, ["left", "hand"]) or bone(arm, ["hand", "l"])
    duration = max((f1 - f0) / src_fps, 1.0 / fps)
    if authored:
        duration = 4.0 if name == "smoke" else 0.4
    count = min(512, max(2, math.ceil(duration * fps)))
    frames = [f0 + (f1 - f0) * i / (count - 1) for i in range(count)]
    if "--preview" in argv:
        frames = [f0]
    os.makedirs(os.path.join(out, name), exist_ok=True)
    info = {"frames": len(frames), "duration": duration, "fps": len(frames) / duration, "hands": [], "hips": [], "angles": []}
    px = size / meters
    anchor = None
    for i, f in enumerate(frames):
        sc.frame_set(math.floor(f), subframe=f % 1.0)
        hp = arm.matrix_world @ hips.head if hips else Vector((0, 0, 0))
        k = i / max(len(frames) - 1, 1)
        for target in [o for o in sc.objects if "grip_x" in o]:
            x, y, z = target["grip_x"], target["grip_y"], 0.30
            right = target.name.startswith("Right")
            if name in ("idle", "walk", "run", "sneak"):
                swing = math.sin(k * math.pi * 2) * (0.10 if name != "idle" else 0.005)
                x, y, z = 0.04 + swing * (1 if right else -1), (-0.22 if right else 0.22), 0.04
            elif name in ("punch", "punch_left"):
                strike = math.sin(min(k / 0.4, 1) * math.pi / 2) if k < 0.4 else (1 - (k - 0.4) / 0.6)
                active = right if name == "punch" else not right
                x = 0.18 + (0.24 * strike if active else 0)
                y = (-1 if right else 1) * (0.16 - (0.09 * strike if active else 0))
                z = 0.31
            elif name == "melee":
                turn = (-0.9 + 2.0 * math.sin(k * math.pi / 2))
                radius = 0.29 + (0 if right else 0.045)
                x, y, z = radius * math.cos(turn), -radius * math.sin(turn), 0.30
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
            if name == "smoke":
                # A gentle lift, held draw, then lower; both ends share the relaxed pose.
                lift = min(max(k / 0.22, 0), 1) * (1 - min(max((k - 0.48) / 0.25, 0), 1))
                lift = lift * lift * (3 - 2 * lift)
                x, y, z = (0.04 + 0.10 * lift, -0.22 + 0.18 * lift, 0.04 + 0.46 * lift) if right else (0.04, 0.22, 0.04)
            if "melee" in name and name != "melee":
                x, y, z = (0.24, -0.16, 0.22) if right else (0.04, 0.22, 0.04)
            if "dual" in name:
                x = 0.28
                y = -0.20 if right else 0.20
            target.location = (hp.x + x, hp.y + y, hp.z + z)
        for pole in [o for o in sc.objects if "side" in o]:
            pole.location = (hp.x - 0.12, hp.y + pole["side"] * 0.26, hp.z + 0.08)
        bpy.context.view_layer.update()
        if i == 0:
            # Bone roll differs left/right after retargeting. Pick the pole angle
            # whose elbow is closest to a tucked, anatomically neutral position.
            for side in ("Right", "Left"):
                forearm = arm.pose.bones.get(side + "ForeArm")
                ik = next((c for c in forearm.constraints if c.type == "IK"), None) if forearm else None
                if ik and ik.pole_target:
                    goal = Vector((hp.x + 0.02, hp.y + (-0.23 if side == "Right" else 0.23), hp.z + 0.10))
                    best = (float("inf"), 0)
                    for step in range(24):
                        angle = 2 * math.pi * step / 24
                        ik.pole_angle = angle
                        bpy.context.view_layer.update()
                        elbow = arm.matrix_world @ forearm.head
                        distance = (elbow - goal).length_squared
                        if distance < best[0]: best = (distance, angle)
                    ik.pole_angle = best[1]
                    bpy.context.view_layer.update()
                    print("ELBOW", name, side, round(best[1], 3), tuple(arm.matrix_world @ forearm.head))
        if anchor is None:
            anchor = hp.copy()
        cam.location.x, cam.location.y = hp.x, hp.y
        sc.render.filepath = os.path.join(out, name, "f%02d.png" % i)
        bpy.ops.render.render(write_still=True)
        def rel(b):
            if b is None:
                return [0, 0]
            # the wrist and 7 cm on toward the fingers: where a grip sits
            # (Meshy's hand bones end far out, so the tail itself can't be used)
            h = arm.matrix_world @ b.head
            d = (arm.matrix_world @ b.tail) - h
            p = h + (d.normalized() * 0.07 if d.length > 1e-6 else Vector((0, 0, 0)))
            # image x = world x (forward); image y = -world y (screen down is her right)
            return [round((p.x - hp.x) * px, 1), round(-(p.y - hp.y) * px, 1)]
        info["hands"].append([rel(hand_r), rel(hand_l)])
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
    meta["anims"][name] = info
    print("anim", name, len(frames), "frames")
mp = os.path.join(out, "meta.json")
old = json.load(open(mp)) if os.path.exists(mp) else {"anims": {}}
old["anims"].update(meta["anims"])
meta["anims"] = old["anims"]
json.dump(meta, open(mp, "w"), indent=1)
