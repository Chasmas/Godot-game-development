"""Prepare a Meshy FBX animation as an isolated Cass staging asset.

Run with Blender:
  blender -b --python tools/art/prepare_meshy_cass_weapon_combo.py -- INPUT.fbx OUT_DIR
"""
from pathlib import Path
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
if len(argv) != 2:
    raise SystemExit("expected INPUT.fbx OUT_DIR")
source = Path(argv[0]).resolve()
out_dir = Path(argv[1]).resolve()
out_dir.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source))
# Meshy includes an unskinned low-poly Icosphere helper in this export.  It is
# not part of Cass or the animation and becomes a huge textured ball in game
# previews, so strip only that named helper from the isolated staging copy.
for obj in list(bpy.context.scene.objects):
    if obj.type == "MESH" and obj.name.startswith("Icosphere"):
        bpy.data.objects.remove(obj, do_unlink=True)
armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
if len(armatures) != 1:
    raise RuntimeError(f"expected one armature, found {len(armatures)}")
armature = armatures[0]
actions = list(bpy.data.actions)
if len(actions) != 1:
    raise RuntimeError(f"expected one animation action, found {len(actions)}")
action = actions[0]
action.name = "cass_meshy_weapon_combo_2"
armature.name = "CassMeshyStagingRig"
armature["source"] = "user Meshy export"
armature["clip"] = "Weapon Combo 2"
armature["fps"] = 60
scene = bpy.context.scene
scene.frame_start = int(action.frame_range[0])
scene.frame_end = int(action.frame_range[1])
scene.frame_set(scene.frame_start)

# Preserve material maps beside the FBX so the staging blend/glTF is portable.
for map_name in ("texture_0.png", "texture_0_metallic.png", "texture_0_normal.png", "texture_0_roughness.png"):
    source_map = next(source.parent.glob(f"*_{map_name}"), None)
    if source_map is None:
        continue
    image = bpy.data.images.load(str(source_map), check_existing=True)
    image.pack()

blend_path = out_dir / "cass_meshy_weapon_combo_2_staging.blend"
glb_path = out_dir / "cass_meshy_weapon_combo_2_staging.glb"
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
bpy.ops.export_scene.gltf(
    filepath=str(glb_path),
    export_format="GLB",
    export_animations=True,
    export_force_sampling=True,
    export_frame_range=True,
)
print("MESHY_CASS_STAGED", armature.name, "bones", len(armature.pose.bones), "frames", tuple(action.frame_range), "blend", blend_path, "glb", glb_path)
