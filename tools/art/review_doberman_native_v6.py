"""Package the captured Godot walk with explicit, limited review evidence."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/walk_candidate_v4/native_skin_candidate_v6'
source_sha = hashlib.sha256((OUT / 'dog_doberman_native_skin.glb').read_bytes()).hexdigest()
frames = []
for index in range(30):
    canvas = Image.new('RGB', (1280, 480))
    for side, folder in enumerate(('godot_frames', 'godot_frames_opposite')):
        path = OUT / folder / f'walk_{index:03d}.png'
        with Image.open(path) as image:
            canvas.paste(image.convert('RGB'), (side * 640, 0))
    frames.append(canvas)
frames[0].save(OUT / 'godot_walk_two_sides.gif', save_all=True,
               append_images=frames[1:], duration=[33, 33, 34] * 10, loop=0)
audits = {}
for name in ('godot_contact_audit', 'godot_direct_contact_audit', 'godot_loop_audit'):
    audits[name] = json.loads((OUT / f'{name}.json').read_text())
    if audits[name]['source_glb_sha256'] != source_sha:
        raise ValueError(f'Source mismatch in {name}')
for folder in ('godot_frames', 'godot_frames_opposite'):
    audit = json.loads((OUT / folder / 'render_audit.json').read_text())
    # Render capture audit uses its own source-hash field naming.
    if source_sha not in audit.values():
        raise ValueError(f'Capture source mismatch in {folder}')
report = {
    'source_glb_sha256': source_sha,
    'runtime_approved': False,
    'animation_approved': False,
    'captured_frames_per_side': 30,
    'reviewed_full_size_frames': ['godot_frames/walk_008.png', 'godot_frames_opposite/walk_020.png'],
    'visual_findings': ['Recognizable silhouette on both sides',
                        'Residual shoulder folds require further anatomy review'],
    'import_profile': {'AnimationPlayer.optimizer/enabled': False,
                       'meshes/force_disable_compression': False},
    'scope': 'Isolated Godot walk candidate; CPU skin contacts, skeleton endpoints and GPU captures. No gameplay validation.',
    'next_work': ['Unify idle and walk on this refined skin',
                  'Review shoulder deformation through the full cycle',
                  'Author and validate remaining canine actions before runtime replacement'],
    'audits': audits,
}
(OUT / 'godot_review.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'source_sha256': source_sha, 'preview_frames': len(frames), 'runtime_approved': False}))
