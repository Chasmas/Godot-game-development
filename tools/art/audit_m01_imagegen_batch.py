"""Inspect ImageGen deliverables without altering pixels."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / 'assets/art/materials/m01/batch_v1'
rows = []
for path in sorted(BATCH.glob('*.png')):
    with Image.open(path) as image:
        row = {'file': path.name, 'size': list(image.size), 'mode': image.mode}
        if 'A' in image.getbands():
            alpha = image.getchannel('A')
            hist = alpha.histogram()
            row['transparent_pixel_fraction'] = hist[0] / (image.width * image.height)
            row['alpha_range'] = list(alpha.getextrema())
        else:
            row['transparent_pixel_fraction'] = 0
        row['role'] = 'material_albedo' if 'albedo' in path.stem else 'Blender_visual_reference'
        row['runtime_integration'] = False
        row['visual_quality_approval'] = 'pending'
        rows.append(row)
(BATCH / 'inspection.json').write_text(json.dumps(rows, indent=2), encoding='utf-8')
print(f'Inspected {len(rows)} unmodified images; visual review and Blender production pending.')
