"""Apply reviewed spatial edits without changing mission logic or keyed entities.
Run `python tools/polish_layouts.py --check` to audit, or omit --check to apply.
The declarative plan uses 16-world-unit cells, two-cell doors, solid jambs,
and sightline windows that never substitute for required walking routes.
"""
import copy,json,sys
from pathlib import Path
from collections import deque
ROOT=Path(__file__).resolve().parents[1]
PLANS=json.loads((ROOT/'tools/layout_plans.json').read_text(encoding='utf-8'))
BLOCK='#~WL%TCblwkcnKZjVtQIYFoE '
PROTECTED=set('gmhHsrBdyzuMqv1234567890!?G()PAFS^*U$&OXR@L')
def apply_layout(data):
    plan=PLANS.get(data['id'])
    if not plan:return data
    result=copy.deepcopy(data)
    if data.get('layout_revision') != 1:
        grid=[list(row) for row in data['map']]
        for edit in plan['edits']:
            x,y=edit['at']
            for i in range(edit['length']):
                u=x+(i if edit['axis']=='h' else 0);v=y+(i if edit['axis']=='v' else 0)
                old=grid[v][u]
                assert old in edit['from'],f"{data['id']} unexpected {old!r} at {u},{v} (expected {edit['from']!r})"
                assert old not in PROTECTED,f'Would replace gameplay entity {u},{v}'
                grid[v][u]=edit['tile']
        result['map']=[''.join(row) for row in grid]
        result['layout_revision']=1
        result['layout_design']={k:v for k,v in plan.items() if k!='edits'}
    # No entity, objective, checkpoint, trigger or power-zone dictionary is rewritten.
    result['decor'] = result.get('decor', []) + [item for item in plan.get('decor', []) if item not in result.get('decor', [])]
    return result

def audit(data):
    rows=data['map']; H=len(rows)
    def valid(p):return 0<=p[1]<H and 0<=p[0]<len(rows[p[1]])
    def neighbors(p):return [(p[0]+1,p[1]),(p[0]-1,p[1]),(p[0],p[1]+1),(p[0],p[1]-1)]
    def at(p):return rows[p[1]][p[0]]
    spawn=next((x,y) for y,row in enumerate(rows) for x,c in enumerate(row) if c=='P')
    reached={spawn};queue=deque([spawn])
    while queue:
        for p in neighbors(queue.popleft()):
            if valid(p) and p not in reached and at(p) not in BLOCK:reached.add(p);queue.append(p)
    inaccessible=[(x,y,c) for y,row in enumerate(rows) for x,c in enumerate(row) if c in 'gmhHsrBdyzuMqvPU$&OXR@' and (x,y) not in reached]
    # Floor decals are set dressing, never a substitute for a wall fixture.
    # Keep them off structural cells and clear of doors and glass.
    bad_floor_decor=[]
    for item in data.get('decor', []):
        if item.get('type') != 'sprite' or not item.get('floor', False):
            continue
        x,y=item.get('pos', [-1,-1])
        allowed = '.,:_=\\+-;'
        # The motel float is deliberately set on pool water; it is a visual
        # layer only and must still stay clear of portals.
        if item.get('id') == 'motel_pool_float':
            allowed += '~'
        if not valid((x,y)) or at((x,y)) not in allowed:
            bad_floor_decor.append(item)
            continue
        if any(valid(p) and at(p) in 'DLW' for p in neighbors((x,y))):
            bad_floor_decor.append(item)
    # Room interiors stop at portals. Glass is NOT counted as an ordinary exit.
    seen=set(); rooms=[]
    for y,row in enumerate(rows):
        for x,c in enumerate(row):
            if (x,y) in seen or c in '#DWL%~ ':continue
            cells={(x,y)};seen.add((x,y));queue=deque(cells);ports=set()
            while queue:
                for p in neighbors(queue.popleft()):
                    if not valid(p):continue
                    if at(p) in 'DL':ports.add(p)
                    if at(p) not in '#DWL%~ ' and p not in seen:seen.add(p);cells.add(p);queue.append(p)
            count=0
            while ports:
                queue=deque([ports.pop()]);count+=1
                while queue:
                    for p in neighbors(queue.popleft()):
                        if p in ports:ports.remove(p);queue.append(p)
            if len(cells)>3:
                bounds=[min(p[0] for p in cells),min(p[1] for p in cells),max(p[0] for p in cells),max(p[1] for p in cells)]
                rooms.append({'bounds':bounds,'cells':len(cells),'exits':count})
    return {'id':data['id'],'reachable_cells':len(reached),'inaccessible_entities':inaccessible,'bad_floor_decor':bad_floor_decor,'rooms':rooms}

def main():
    reports=[]
    for path in sorted((ROOT/'levels').glob('*.json')):
        old=json.loads(path.read_text(encoding='utf-8'));new=apply_layout(old)
        report=audit(new);reports.append(report)
        assert not report['inaccessible_entities'], report
        assert not report['bad_floor_decor'], report
        assert all(r['exits']>=2 for r in report['rooms']),report
        # Courtyards and long shared corridors serve several rooms. Enclosed
        # combat rooms should expose two or three distinct escape routes.
        enclosed=[r for r in report['rooms'] if r['cells']<1000 and
                  (r['bounds'][2]-r['bounds'][0]+1)/(r['bounds'][3]-r['bounds'][1]+1)<=4]
        assert all(r['exits']<=3 for r in enclosed),report
        if '--check' not in sys.argv:path.write_text(json.dumps(new,ensure_ascii=False,indent=1)+'\n',encoding='utf-8')
        print(path.stem, len(report['rooms']), 'regions; all entities reachable; no single-exit rooms')
    if '--json' in sys.argv:print(json.dumps(reports,indent=2))
if __name__=='__main__':main()
