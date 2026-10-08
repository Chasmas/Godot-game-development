"""Record the isolated direct-GLTF texture diagnostic and corrected preview."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/idle_native_candidate_v2'
frames = []
for index in range(24):
    with Image.open(OUT / 'godot_texture_mips' / f'idle_{index:03d}.png') as image:
        frames.append(image.convert('RGB'))
frames[0].save(OUT / 'godot_idle_mipmaps_preview.gif', save_all=True,
               append_images=frames[1:], duration=100, loop=0)
report = {
    'runtime_approved': False,
    'animation_approved': False,
    'source_glb_sha256': hashlib.sha256((OUT / 'dog_doberman_idle_candidate.glb').read_bytes()).hexdigest(),
    'scope': 'Same direct-GLTF idle compared with normal map disabled, clay, and generated texture mipmaps; isolated GPU capture only',
    'observed_texture_mipmaps_before': {
        'albedo_texture': False, 'normal_texture': False,
        'roughness_texture': False, 'metallic_texture': False,
    },
    'correction': 'Generate mipmaps for each texture image; renormalize normal-map mip levels; use linear mipmap filtering',
    'visual_review': {
        'godot_no_normal/idle_012.png': 'Fine surface noise remains without normal map',
        'godot_clay/idle_000.png': 'Smooth surface without texture noise',
        'godot_clay/idle_012.png': 'Breath deformation remains smooth without texture noise',
        'godot_texture_mips/idle_012.png': 'Fine surface noise resolved with texture mipmaps',
    },
    'remaining': ['Godot endpoint and idle-walk transition checks',
                  'Shoulder anatomy refinement', 'Validate runtime texture handling before integration'],
}
(OUT / 'material_diagnostic.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'frames': len(frames), 'source_sha256': report['source_glb_sha256']}))
