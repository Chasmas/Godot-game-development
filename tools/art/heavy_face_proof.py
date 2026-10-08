from pathlib import Path
from pixellab_character_proof import generate

OUT = Path('C:/tmp_shots/character_oblique_proof')
OUT.mkdir(parents=True, exist_ok=True)
identity = ('massive adult male enforcer, bald scarred head with a clearly readable side face, thick dark beard, '
            'broad shoulders, sleeveless distressed dark leather vest, metal buckles and chain, dark work trousers, boots')
prompt = (f'{identity}, complete full body lying motionless on his right side, face visible in three-quarter profile with '
          'brow, eye, nose, mouth and beard readable, both arms and legs fully visible, strict three-quarter top-down '
          'oblique camera about 55 degrees above horizon, premium highly detailed pixel art, 1980s California neon noir, '
          'transparent background, crisp intentional pixels, clean silhouette, restrained dark blood stain')
img = generate(prompt, 256, 192)
img.save(OUT / 'heavy_face_oblique_proof.png')
print(OUT / 'heavy_face_oblique_proof.png')
