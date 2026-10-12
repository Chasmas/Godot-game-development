"""Assemble rendered QA frames without changing the source render images."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

root = Path('build/uthana/cast_roster/motions/guard/merged')
clips = [('walk', 1.86666679382324), ('run', 1.33333337306976), ('stealth', 2.16666674613953)]
images = {}
for name, _ in clips:
    paths = sorted((root / (name + '_weapon_frames')).glob('*.png'))
    assert len(paths) == 48, (name, len(paths))
    images[name] = [Image.open(path).convert('RGB') for path in paths]
frames = []
fps = 24
for frame in range(fps * 6):
    canvas = Image.new('RGB', (960, 350), '#20222b')
    draw = ImageDraw.Draw(canvas)
    for column, (name, duration) in enumerate(clips):
        sample = int(((frame / fps) % duration) / duration * 48) % 48
        canvas.paste(images[name][sample], (column * 320, 30))
        draw.text((column * 320 + 12, 9), name.upper() + ' / STAGED STUDY', fill='white')
    frames.append(canvas)
destination = root / 'guard_armed_uthana_study.gif'
frames[0].save(destination, save_all=True, append_images=frames[1:], duration=round(1000 / fps), loop=0)
(root / 'gif_review.json').write_text(json.dumps({'runtime_approved':False, 'duration_seconds':6, 'fps':fps, 'scope':'Three separately timed merged loops with staged Blender pistol; source renders preserved', 'pending':['planted foot correction','hand grasp','aim direction changes','gameplay cadence']}, indent=2))
print(destination.resolve())
