"""Measure authored guest floor regions before relocating any gameplay entities."""
from pathlib import Path
import json, hashlib
ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'levels/m01_sunset_palms.json'
data = json.loads(source.read_text(encoding='utf-8-sig'))
grid = data['map']
# Furniture/spawns/loot are embedded in room floor; walls/doors/windows delimit it.
floor_chars = set('.,_:=\"~;+-')
visited = set()
regions = []
def char(x,y):
    return grid[y][x] if 0 <= y < len(grid) and 0 <= x < len(grid[y]) else '#'
def inherited_floor(x,y):
    c=char(x,y)
    if c in floor_chars: return c
    if c in '# DWL%': return ''
    for radius in range(1,4):
        for dx,dy in [(-radius,0),(radius,0),(0,-radius),(0,radius)]:
            neighbour=char(x+dx,y+dy)
            if neighbour in floor_chars and neighbour!='~': return neighbour
    return ','
for y,row in enumerate(grid):
    for x,c in enumerate(row):
        if c != '.' or (x,y) in visited: continue
        pending=[(x,y)]; cells=set()
        while pending:
            p=pending.pop()
            if p in cells or inherited_floor(*p)!='.': continue
            cells.add(p); visited.add(p)
            px,py=p
            pending.extend([(px-1,py),(px+1,py),(px,py-1),(px,py+1)])
        if len(cells)<15: continue
        minx,miny=min(p[0] for p in cells),min(p[1] for p in cells)
        maxx,maxy=max(p[0] for p in cells),max(p[1] for p in cells)
        boundary=set()
        for px,py in cells:
            boundary.update(p for p in [(px-1,py),(px+1,py),(px,py-1),(px,py+1)] if p not in cells)
        openings=[{'tile':[px,py],'kind':char(px,py)} for px,py in sorted(boundary) if char(px,py) in 'DW%']
        identities={(5,2):'201',(16,2):'202',(27,2):'203',(40,2):'204',
            (54,2):'manager_secret_suite',(11,27):'101',(20,27):'102',
            (33,27):'103_card_game',(42,27):'104',(11,36):'105',
            (20,36):'106',(42,36):'108'}
        regions.append({'room_id':identities.get((minx,miny),'unclassified'),
            'identity_evidence':'tools/build_m01.py authored region comments and current map bounds; 200-series inferred from room204 comment',
            'bounds_tiles':[minx,miny,maxx,maxy],
            'size_tiles':[maxx-minx+1,maxy-miny+1],
            'size_game_pixels':[(maxx-minx+1)*16,(maxy-miny+1)*16],
            'floor_cells':len(cells),'openings':openings,
            'embedded_entities':[{'tile':[px,py],'symbol':char(px,py)} for px,py in sorted(cells) if char(px,py)!='.']})
report={'runtime_approved':False,'map_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'method':'Connected carpet regions using LevelBuilder neighbour-floor inheritance; doors/windows/weak walls treated as room boundaries. Semantic room identification still required',
    'candidate_regions':regions,'reference_room_metres':[5.4,5.2],
    'constraints':['Do not scale actors or collision radius to fit art',
        'Rebuild furniture layout to room footprint, preserve all gameplay door/window openings',
        'Separate floor geometry from embedded symbols before production approval']}
out=ROOT/'build/m01_room_rebuild_fit.json'
out.write_text(json.dumps(report,indent=2),encoding='utf-8')
first=next(r for r in regions if r['room_id']=='101')
minx,miny,maxx,maxy=first['bounds_tiles']
layout={'runtime_approved':False,'room_id':'101','map_sha256':report['map_sha256'],
    'floor_size_metres':first['size_tiles'],
    'origin_game_pixels':[minx*16,miny*16],
    'coordinate_convention':'Local X right, Y toward map south;16 game pixels per metre; Blender Y is inverted',
    'preserved_openings':first['openings'],
    'preserved_entities':first['embedded_entities'],
    'art_placements':[
        {'asset':'motel_bed','centre_metres':[6.0,2.0], 'footprint_metres':[2.0,2.0],
         'rule':'Adapt authored mesh to existing bed footprint; retain body and navigation'},
        {'asset':'tv_dresser','centre_metres':[1.5,.5], 'maximum_footprint_metres':[.8,.7],
         'rule':'User requested north-wall placement facing viewer; reconcile gameplay TV entity before promotion'},
        {'asset':'nightstand_upper','centre_metres':[3.375,.5], 'footprint_metres':[.65,.5],
         'rule':'Match production cabinet centre230,440; preserve south/east passage'},
        {'asset':'nightstand_lower','centre_metres':[2.375,3.5], 'footprint_metres':[.65,.5],
         'rule':'Match production cabinet centre214,488; preserve straight south entrance'}],
    'composition_rules':['Use approved textiles/walnut/plaster and coherent practical light',
        'No new bathroom bay in this small room without a gameplay layout revision',
        'Keep south door lane x3..5 free and west/east adjoining door lanes free',
        'Do not duplicate invisible original decor under new dressing'],
    'pending':['Blender reconstruction to actual8x4m bounds','Door/window frame and sill alignment',
        'Cass/NPC clearance and gameplay objective route tests','Shared camera bridge integration']}
(ROOT/'build/m01_room_101_rebuild_layout.json').write_text(json.dumps(layout,indent=2),encoding='utf-8')
print(json.dumps({'regions':len(regions),'sizes':[r['size_tiles'] for r in regions]}))
