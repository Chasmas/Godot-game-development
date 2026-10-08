"""Package both GPU views of the exported moving-start contact pilot."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/start_contact_candidate_v3'
source = OUT / 'baked_candidate_v1/dog_doberman_walk_baked.glb'
digest = hashlib.sha256(source.read_bytes()).hexdigest()
for folder in ('godot_frames', 'godot_frames_opposite'):
    audit = json.loads((OUT / folder / 'render_audit.json').read_text())
    assert audit['source_sha256'] == digest
    assert audit['captured_frames'] == 19
frames = []
for index in range(19):
    frame = Image.new('RGB', (1280, 480))
    for side, folder in enumerate(('godot_frames', 'godot_frames_opposite')):
        with Image.open(OUT / folder / f'idle_{index:03d}.png') as image:
            frame.paste(image.convert('RGB'), (side * 640, 0))
    frames.append(frame)
frames[0].save(OUT / 'godot_moving_start_preview.gif', save_all=True,
               append_images=frames[1:], duration=[33, 33, 34] * 6 + [400], loop=0)
report = {'runtime_approved': False, 'animation_approved': False,
          'source_glb_sha256': digest, 'captured_frames_per_side': 19,
          'reviewed_frames': ['godot_frames/idle_010.png', 'godot_frames_opposite/idle_018.png'],
          'findings': ['Object translation now survives the pose bake',
                       'Shoulder folds still require refinement'],
          'remaining': ['Independent Godot world-space contact reconstruction',
                        'Visual review of continuous start-to-walk playback',
                        'Runtime movement extraction and collision validation'],
          'scope': 'Isolated exported contact pilot; no production integration'}
(OUT / 'visual_review.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'source_sha256': digest, 'frames': len(frames)}))
