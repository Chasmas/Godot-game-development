"""Read-only audit of every opaque source pixel at actual Godot placements."""
from pathlib import Path
import json
import math
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
directory = ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/armchair_runtime_v3'
contract = json.loads((directory / 'runtime_contract.json').read_text())
placements = json.loads((ROOT / 'build/m01_armchair_placement_review.json').read_text())
grid = json.loads((ROOT / 'levels/m01_sunset_palms.json').read_text())['map']
results = []
for placement in placements:
    frame = contract['frames'][placement['facing_index']]
    image = Image.open(directory / frame['file']).convert('RGBA')
    anchor = frame['floor_anchor_px']
    scale = contract['sprite_scale']
    position = placement['position']
    opaque = overlapping = 0
    for y in range(image.height):
        for x in range(image.width):
            if image.getpixel((x, y))[3] < 128:
                continue
            opaque += 1
            gx = math.floor((position[0] + (x-anchor[0])*scale)/16)
            gy = math.floor((position[1] + (y-anchor[1])*scale)/16)
            if not (0 <= gy < len(grid) and 0 <= gx < len(grid[gy])) or grid[gy][gx] == '#':
                overlapping += 1
    results.append({'position': position, 'opaque_pixels': opaque, 'wall_or_outside_pixels': overlapping})
report = {'scope': 'All source pixels with alpha >= 128; projection only, not traversal',
          'passed': all(r['wall_or_outside_pixels'] == 0 for r in results), 'placements': results}
(ROOT / 'build/m01_armchair_projection_audit.json').write_text(json.dumps(report, indent=2))
print('M01_ARMCHAIR_PROJECTION: %d placements; %d opaque pixels overlap walls/outside' %
      (len(results), sum(r['wall_or_outside_pixels'] for r in results)))
raise SystemExit(0 if report['passed'] else 1)
