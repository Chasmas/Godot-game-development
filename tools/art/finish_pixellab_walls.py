"""Add sparse PixelLab-generated wear to PixelLab-converted wall materials.
Only PixelLab outputs are composited; original texture files stay untouched.
"""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'assets/art/pixellab_world'
MARKER=ART/'walls_finished.json'
if MARKER.exists():
    print('PixelLab walls already finished')
    raise SystemExit(0)
MOTIFS={'wall_motel':'wall_motel_cracks','wall_salvage':'wall_salvage_rust','wall_studio':'wall_studio_scuffs','wall_villa':'wall_villa_veins'}
POSITIONS=[(67,91,0),(315,63,1),(141,342,2),(410,280,3)]
for name,motif in MOTIFS.items():
 target=ART/'floors'/f'{name}.png'
 source=ART/'sprites'/f'{motif}.png'
 if not target.exists() or not source.exists():raise FileNotFoundError((target,source))
 bg=Image.open(target).convert('RGBA')
 stamp=Image.open(source).convert('RGBA')
 for x,y,rot in POSITIONS:
  dec=stamp.rotate(rot*90,expand=False)
  dec=dec.resize((48 if name!='wall_salvage' else 58,48 if name!='wall_salvage' else 58),Image.Resampling.NEAREST)
  alpha=dec.getchannel('A').point(lambda a:round(a*(0.20 if name=='wall_motel' else 0.27)))
  dec.putalpha(alpha)
  bg.alpha_composite(dec,(x,y))
 bg.save(target)
 print('finished',target.name)

MARKER.write_text('{"finished": true}\n', encoding="utf-8")
