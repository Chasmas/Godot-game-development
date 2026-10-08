"""Headless Blender renderer for reviewed 16:9 cutscene frame sequences.

Usage:
  blender -b scene.blend --python render_cutscene_sequence.py -- --out ... --seconds 4 --fps 12

The script deliberately renders PNG frames only; Godot owns dialogue, audio,
input and transitions. Existing stills remain the fallback until the sequence
folder contains at least one frame.
"""
import bpy, os, sys, argparse

def args_after_double_dash():
    raw = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--out", required=True)
    p.add_argument("--seconds", type=float, default=4.0)
    p.add_argument("--fps", type=int, default=12)
    p.add_argument("--width", type=int, default=1920)
    p.add_argument("--height", type=int, default=1080)
    p.add_argument("--start", type=int, default=1)
    return p.parse_args(raw)

def main():
    a = args_after_double_dash()
    os.makedirs(a.out, exist_ok=True)
    scene = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items}
    scene.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in engines else 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x = a.width
    scene.render.resolution_y = a.height
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    total = max(1, int(round(a.seconds * a.fps)))
    scene.render.fps = a.fps
    for i in range(total):
        scene.frame_set(a.start + i)
        scene.render.filepath = os.path.join(a.out, f"frame_{i+1:04d}.png")
        bpy.ops.render.render(write_still=True)
    print(f"Rendered {total} frames at {a.fps} fps to {a.out}")

if __name__ == '__main__':
    main()
