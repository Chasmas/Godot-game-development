"""Audit staging renders for the M01 Blender environment."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
base=ROOT/'assets/art/prerendered/m01_sunset_palms'
files=[base/'sunset_palms_courtyard.blend',base/'layers'/'ground.png',base/'staging'/'m01_interiors_transitions_staging.blend',base/'staging'/'m01_interiors_transitions_staging.png',base/'staging'/'m01_reception_detail_staging.png',base/'staging'/'m01_service_transition_detail_staging.png',base/'staging'/'m01_interiors_transitions_pixel_preview.png',base/'staging'/'m01_reception_detail_pixel_preview.png',base/'staging'/'m01_service_transition_detail_pixel_preview.png',base/'entrance_approach_detail_staging_4k.png']
missing=[str(p) for p in files if not p.exists()]
if missing: raise SystemExit('M01 staging missing: '+', '.join(missing))
for p in files:
 if p.suffix.lower() in ('.png','.jpg'):
  im=Image.open(p)
  if im.width < 960 or im.height < 540: raise SystemExit(f'low resolution: {p} {im.size}')
  if p.name.endswith('_4k.png') and im.size != (3840, 2160): raise SystemExit(f'4K staging render has wrong size: {p} {im.size}')
print('M01 Blender staging audit: PASS')
for p in files: print(' ',p.relative_to(ROOT))



