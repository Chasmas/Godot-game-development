"""Revalidate a wall plate against the current playable grid, without rendering."""
import hashlib
import json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'levels/m01_sunset_palms.json'
rows=json.loads(source.read_text(encoding='utf-8'))['map']
directory=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/layout_reconstruction_v1'
contract_path=directory/'wall_layer_contract_v6.json'
contract=json.loads(contract_path.read_text(encoding='utf-8'))
image=Image.open(directory/contract['image']).convert('RGBA')
assert image.size==tuple(contract['size_px'])
cell=int(contract['pixels_per_cell'])
alpha_plane=image.getchannel('A')
def glyph(x,y):
    return rows[y][x] if 0<=y<len(rows) and 0<=x<len(rows[y]) else '#'
mismatches=[]
outside=0
visible=0
for y,row in enumerate(rows):
    for x,g in enumerate(row):
        expected=g=='#' and any(glyph(x+dx,y+dy)!='#' for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)])
        alpha=image.getpixel((x*cell+cell//2,y*cell+cell//2))[3]
        if bool(alpha>0)!=expected:mismatches.append([x,y,expected,alpha])
        if expected:visible+=1
        if g!='#':
            histogram=alpha_plane.crop((x*cell,y*cell,(x+1)*cell,(y+1)*cell)).histogram()
            outside+=sum(histogram[1:])
report={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'checked_cells':sum(map(len,rows)),'visible_wall_cells':visible,'centre_alpha_mismatches':mismatches,'opaque_pixels_outside_wall_cells':outside,'passed':not mismatches and outside==0,'runtime_approved':False,'scope':'Current map cell centres and every alpha pixel in non-wall cells; no physics or visual quality approval'}
(directory/'wall_projection_audit_v6_current.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
assert report['passed'],report
contract['previous_source_level_sha256']=contract['source_level_sha256']
contract['source_level_sha256']=report['source_sha256']
contract['layout_revalidation']='Current-grid alpha audit passed; this verifies wall footprint coverage, not exact historical map equality.'
contract_path.write_text(json.dumps(contract,indent=2)+'\n',encoding='utf-8')
(directory/'wall_projection_audit_v6.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f"Wall plate verified: {visible} visible wall cells, zero non-wall alpha pixels.")
