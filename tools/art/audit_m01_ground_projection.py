"""Read-only alpha/anchor audit against every current map cell."""
import json,hashlib,os
from pathlib import Path
from PIL import Image
from m01_layout_data import floor_grid
root=Path(__file__).resolve().parents[2]
stage=root/'assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1'
contract=json.loads((stage/os.environ.get('M01_GROUND_CONTRACT','ground_layer_contract_v2.json')).read_text())
level=root/'levels/m01_sunset_palms.json'
assert hashlib.sha256(level.read_bytes()).hexdigest()==contract['source_level_sha256']
grid=floor_grid(json.loads(level.read_text())['map'])
source=Path(os.environ['M01_GROUND_IMAGE']) if 'M01_GROUND_IMAGE' in os.environ else stage/contract['image']
image=Image.open(source).convert('RGBA')
assert image.size==tuple(contract['size_px'])==(len(grid[0])*64,len(grid)*64)
pixels=image.load()
spill=missing=excluded=covered=0
for y,row in enumerate(grid):
    for x,kind in enumerate(row):
        expected=kind not in ('','~')
        center=pixels[x*64+32,y*64+32][3]
        if expected:
            covered+=1
            missing+=center<128
        else:
            excluded+=1
            for yy in range(y*64,(y+1)*64):
                for xx in range(x*64,(x+1)*64):
                    spill+=pixels[xx,yy][3]>=128
report={'passed':spill==missing==0,'image_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'level_sha256':contract['source_level_sha256'],'covered_cells':covered,'excluded_cells':excluded,'missing_floor_centres':missing,'opaque_pixels_over_water_walls_or_void':spill,'scope':'every alpha>=128 pixel in excluded cells; centre coverage in ground cells'}
(root/'build'/os.environ.get('M01_GROUND_REPORT','m01_ground_projection_audit.json')).write_text(json.dumps(report,indent=2))
print('M01 GROUND PROJECTION',report)
raise SystemExit(0 if report['passed'] else 1)
