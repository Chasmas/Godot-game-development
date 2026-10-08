"""Blender (run inside it): one rigged Meshy character + all its anim_<name>.glb
clips -> a single game GLB (one mesh, one skeleton, one action per clip) that
Godot imports and draws in real time (scripts/player/cast_model.gd).

  blender -b --python tools/art/build_cast_glb.py -- <char_dir> <out.glb> [--decimate 0.5]

<char_dir> is assets/art/Artwork/3d/<id>/ (Meshy downloads, ignored by Godot).
Every clip's mesh is a copy of the same character: only its armature action is
kept and retargeted by bone name onto the first armature.
"""
import bpy, sys, os, glob

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = os.path.abspath(argv[0]), os.path.abspath(argv[1])
decimate = float(argv[argv.index("--decimate") + 1]) if "--decimate" in argv else 1.0

bpy.ops.wm.read_factory_settings(use_empty=True)

def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]

clips = sorted(glob.glob(os.path.join(src, "anim_*.glb")))
if not clips:
    sys.exit("no anim_*.glb in " + src)
base = import_glb(clips[0])
arm = next(o for o in base if o.type == "ARMATURE")
arm.name = "Armature"

# No bone-tail repair here (render_cast3d.py does one for its IK): moving tails in
# edit mode changes the rest orientation the clips' rotations are keyed against,
# and the raw clips then throw the arms over the head.

actions = []
for path in clips:
    name = os.path.basename(path)[5:-4]
    if path == clips[0]:
        act = arm.animation_data.action
    else:
        objs = import_glb(path)
        other = next(o for o in objs if o.type == "ARMATURE")
        act = other.animation_data.action
        act.use_fake_user = True
        for o in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    act.name = name
    act.use_fake_user = True
    actions.append(act)

# one NLA track per clip: the glTF exporter writes each as its own animation
arm.animation_data.action = None
for act in actions:
    track = arm.animation_data.nla_tracks.new()
    track.name = act.name
    track.strips.new(act.name, int(act.frame_range[0]), act)
    track.mute = True

if decimate < 1.0:
    for o in [o for o in base if o.type == "MESH"]:
        m = o.modifiers.new("decimate", "DECIMATE")
        m.ratio = decimate
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=m.name)

os.makedirs(os.path.dirname(out), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_apply=False,
                          export_image_format="AUTO")
print("built", out, "clips:", [a.name for a in actions])
