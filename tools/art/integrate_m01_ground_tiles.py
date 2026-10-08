"""Build sparse shared-texture regions; read raster pixels without editing art."""
import hashlib
import json
from pathlib import Path
from PIL import Image
from m01_layout_data import floor_grid

root = Path(__file__).resolve().parents[2]
directory = root/'assets/art/prerendered/m01_sunset_palms/runtime/ground_v1'
path = directory/'runtime_contract.json'
contract = json.loads(path.read_text())
review = json.loads((root/'build/m01_ground_runtime_review_compressed.json').read_text())
assert contract['runtime_approved'] and review['compressed']
assert review['with_tiled_ground']['median_ms'] <= review['with_ground']['median_ms']*1.10
assert contract['texture_sha256'] == hashlib.sha256((directory/contract['image']).read_bytes()).hexdigest()
source = root/'assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1/ground_layer_candidate_v3.png'
assert contract['source_image_sha256'] == hashlib.sha256(source.read_bytes()).hexdigest()
image = Image.open(source).convert('RGBA')
alpha = image.getchannel('A')
regions = []
for y in range(0,image.height,256):
    for x in range(0,image.width,256):
        width, height = min(256,image.width-x), min(256,image.height-y)
        if alpha.crop((x,y,x+width,y+height)).getbbox() is not None:
            regions.append([x,y,width,height])
assert len(regions) == review['with_tiled_ground']['tiles'] == 253
contract['tile_regions_px'] = regions
contract['tile_world_size_px'] = 64
contract['tile_texture_shared'] = True
decoded_path = root/'build/m01_ground_s3tc_decoded.png'
decoded_audit = json.loads((root/'build/m01_ground_compressed_projection_audit.json').read_text())
assert decoded_audit['passed'] and decoded_audit['image_sha256']==hashlib.sha256(decoded_path.read_bytes()).hexdigest()
assert contract['source_level_sha256']==hashlib.sha256((root/'levels/m01_sunset_palms.json').read_bytes()).hexdigest()
decoded = Image.open(decoded_path).getchannel('A')
grid = floor_grid(json.loads((root/'levels/m01_sunset_palms.json').read_text())['map'])
fully_covered = set()
for y,row in enumerate(grid):
    for x,kind in enumerate(row):
        if kind not in ('','~') and decoded.crop((x*64,y*64,(x+1)*64,(y+1)*64)).getextrema()[0]==255:
            fully_covered.add((x,y))
redundant=[]
for y in range(0,len(grid),4):
    for x in range(0,len(grid[0]),4):
        cells=[(xx,yy) for yy in range(y,min(y+4,len(grid))) for xx in range(x,min(x+4,len(grid[0]))) if grid[yy][xx]!='']
        if cells and all(cell in fully_covered for cell in cells):
            redundant.append([x,y,min(4,len(grid[0])-x),min(4,len(grid)-y)])
contract['fully_covered_legacy_chunks'] = redundant
path.write_text(json.dumps(contract,indent=2))
print(f'M01 GROUND TILE MANIFEST: {len(regions)} regions, {len(redundant)} fully opaque legacy chunks redundant')
