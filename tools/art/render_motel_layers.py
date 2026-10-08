"""Export aligned preview layers from the Sunset Palms Blender scene.

The layers are deliberately preview-only. They share the scene camera and render
settings, so they can be composited over the unchanged Godot gameplay once the
visual and occlusion checks pass.

Run from the repository root:
  blender -b assets/art/prerendered/m01_sunset_palms/sunset_palms_courtyard.blend \
    --python tools/art/render_motel_layers.py
"""

from pathlib import Path
import os
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/prerendered/m01_sunset_palms/layers"
OUT.mkdir(parents=True, exist_ok=True)
EXPORT_4K = os.environ.get("M01_RENDER_4K", "0") == "1"

GROUND = {"Asphalt lot", "Courtyard slab", "Courtyard kerb", "Pool tile basin",
          "Pool water", "Pool coping", "Lot markings"}
GROUND_NO_POOL = GROUND - {"Pool tile basin", "Pool water", "Pool coping"}
ARCH_WORDS = ("wing", "roof", "facade", "railings", "stair", "rooftop", "wall")
FOREGROUND_WORDS = ("Neon sign", "Palms", "Palm well", "Bougainvillea", "Planter",
                     "Courtyard furniture", "Litter", "Body", "Door", "Mesh_0")
OCCLUSION_WORDS = ("Palms", "Palm well", "Neon sign", "Bougainvillea", "Planter 0",
                   "Planter 1", "Planter 2", "Planter 3", "Planter 4", "Planter 5",
                   "Planter 6", "Planter 7")


def bucket(obj):
    name = obj.name
    if name in GROUND:
        return "ground"
    if any(word.lower() in name.lower() for word in ARCH_WORDS):
        return "architecture"
    if any(word.lower() in name.lower() for word in FOREGROUND_WORDS):
        return "props_vegetation"
    return "props_vegetation"


def is_occlusion(obj):
    return any(word.lower() in obj.name.lower() for word in OCCLUSION_WORDS)


def main():
    scene = bpy.context.scene
    if scene is None or scene.camera is None or scene.camera.name != "Courtyard master camera":
        raise RuntimeError(
            "The Sunset Palms Blender scene/camera is not loaded. Open "
            "sunset_palms_courtyard.blend before running this exporter."
        )
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    # The source .blend may have been saved after a --pixel render. Layers are
    # integration previews and must retain the master 16:9 canvas dimensions.
    # Keep the reviewed runtime-sized export as the default. A separate 4K
    # pass is opt-in so it cannot silently replace the validated layers.
    width, height = (3840, 2160) if EXPORT_4K else (1920, 1080)
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    objects = [obj for obj in scene.objects if obj.type == "MESH"]
    if not objects:
        raise RuntimeError(
            "The active Blender scene contains no mesh objects; refusing to "
            "overwrite preview layers with transparent PNGs."
        )
    original = {obj.name: obj.hide_render for obj in objects}
    for name in ("ground", "architecture", "props_vegetation", "foreground_occlusion"):
        for obj in objects:
            obj.hide_render = (not is_occlusion(obj)) if name == "foreground_occlusion" else bucket(obj) != name
        target_dir = OUT / "4k" if EXPORT_4K else OUT
        target_dir.mkdir(parents=True, exist_ok=True)
        scene.render.filepath = str(target_dir / (name + ".png"))
        bpy.ops.render.render(write_still=True)
    # Staging-only variant for the Godot composition gate. The live level owns
    # the pool water/coping, so this variant tests whether the plate can supply
    # pavement without creating a duplicate pool landmark. It is never wired
    # into runtime by this exporter.
    for obj in objects:
        obj.hide_render = obj.name not in GROUND_NO_POOL
    target_dir = OUT / "4k" if EXPORT_4K else OUT
    target_dir.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(target_dir / "ground_no_pool_review.png")
    bpy.ops.render.render(write_still=True)
    # A second staging pass with Blender lights disabled gives the Godot
    # lighting system a neutral pavement plate, instead of baking the scene's
    # magenta pools into the review texture. Never used by runtime directly.
    lights = [obj for obj in scene.objects if obj.type == "LIGHT"]
    light_hidden = {obj.name: obj.hide_render for obj in lights}
    for obj in lights:
        obj.hide_render = True
    scene.render.filepath = str(target_dir / "ground_no_pool_neutral_review.png")
    bpy.ops.render.render(write_still=True)
    for obj in lights:
        obj.hide_render = light_hidden[obj.name]
    for obj in objects:
        obj.hide_render = original[obj.name]
    scene.render.film_transparent = False
    scene.render.filepath = str(OUT.parent / "courtyard_master.png")
    print("M01 layers exported:", ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
