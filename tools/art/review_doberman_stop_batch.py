"""Assemble exact-source GPU contact sheets and a batch animation preview."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/blocked_stop_phase_candidates_v2'
phases = (1, 4, 7, 10, 13, 16, 19)
for phase in phases:
    folder = OUT / f'frame_{phase:02d}'
    digest = hashlib.sha256((folder / 'baked_candidate_v1/dog_doberman_walk_baked.glb').read_bytes()).hexdigest()
    for side in ('godot_frames', 'godot_frames_opposite'):
        audit = json.loads((folder / side / 'render_audit.json').read_text())
        assert audit['source_sha256'] == digest and audit['captured_frames'] == 19
sheet = Image.new('RGB', (1280, 260 * len(phases)), '#161b21')
draw = ImageDraw.Draw(sheet)
for row, phase in enumerate(phases):
    draw.text((8, row * 260 + 4), f'SOURCE FRAME {phase:02d}: START / MID / END / OPPOSITE MID', fill='white')
    for col, (side, index) in enumerate((('godot_frames', 0), ('godot_frames', 9), ('godot_frames', 18), ('godot_frames_opposite', 9))):
        with Image.open(OUT / f'frame_{phase:02d}' / side / f'idle_{index:03d}.png') as source:
            sheet.paste(source.convert('RGB').resize((320, 240)), (col * 320, row * 260 + 20))
sheet.save(OUT / 'godot_stop_contact_sheet.png')
frames = []
for index in range(19):
    frame = Image.new('RGB', (640, 260 * len(phases)), '#161b21')
    draw = ImageDraw.Draw(frame)
    for row, phase in enumerate(phases):
        draw.text((8, row * 260 + 4), f'SOURCE FRAME {phase:02d}', fill='white')
        for col, side in enumerate(('godot_frames', 'godot_frames_opposite')):
            with Image.open(OUT / f'frame_{phase:02d}' / side / f'idle_{index:03d}.png') as source:
                frame.paste(source.convert('RGB').resize((320, 240)), (col * 320, row * 260 + 20))
    frames.append(frame)
frames[0].save(OUT / 'godot_stop_batch_preview.gif', save_all=True, append_images=frames[1:],
               duration=[33, 33, 34] * 6 + [400], loop=0)
print(json.dumps({'candidates': len(phases), 'gpu_frames': len(phases) * 2 * 19,
                  'source_hashes_verified': True, 'runtime_approved': False}))
