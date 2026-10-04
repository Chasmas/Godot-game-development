"""Add a dense, deterministic layer of authored props without touching gameplay tiles."""
import json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLANS = ROOT / 'tools/layout_plans.json'
LEVEL_DIR = ROOT / 'levels'
POOLS = {
 'm01_sunset_palms': ['motel_neon_vacancy_sign','motel_towel_cart','motel_water_ring','motel_palm_planter','motel_gecko','paper','clutter_bottles','clutter_ashtray','motel_room_key_spill'],
 'm02_yermo_salvage': ['yard_desert_scrub_cluster','yard_pipe_manifold','yard_utility_control_box','yard_welded_safety_railing','yard_oil_rags','yard_copper_scraps','yard_parts_tags','yard_tail_light_debris','yard_chain_cable_spill','clutter_floor_stains'],
 'm03_khsc_studios': ['studio_overhead_light_rig','studio_acoustic_wall_panel','studio_gaffer_scraps','studio_script_trail','studio_moth','studio_fern','studio_cable_spool','studio_tape_marks','studio_makeup_spill','paper'],
 'm04_villa_estrella': ['villa_ivy_wall_cluster','villa_tea_service','villa_rose_petals','villa_wax_and_petals','villa_seating_card','villa_orchid_planter','villa_orange_peel','villa_candle_ring','villa_ivy_planter','plant'],
}

def map_rows(mid):
    d=json.loads((LEVEL_DIR/(mid+'.json')).read_text(encoding='utf-8'))
    return d.get('map', d.get('layout', []))

def main():
    data=json.loads(PLANS.read_text(encoding='utf-8'))
    before=sum(len(v.get('decor',[])) for v in data.values())
    target=300
    for mid,pool in POOLS.items():
        plan=data[mid]; rows=map_rows(mid); existing=plan.setdefault('decor',[])
        occupied=[tuple(x.get('pos',[0,0])) for x in existing]
        candidates=[]
        for y,row in enumerate(rows):
            for x,ch in enumerate(row):
                if ch in '#WDL% ' or x<2 or y<2 or x>=len(row)-2 or y>=len(rows)-2: continue
                if any(math.dist((x,y),p)<3.0 for p in occupied): continue
                candidates.append((x,y))
        step=max(1, len(candidates)//max(1, (target-before)//4))
        for i,(x,y) in enumerate(candidates[::step]):
            if sum(len(v.get('decor',[])) for v in data.values())>=target: break
            sid=pool[i%len(pool)]
            existing.append({'type':'sprite','id':sid,'pos':[x,y],'size':0.27 if 'paper' in sid or 'petal' in sid else 0.34 + (i % 3) * 0.04,'rot':[-12,0,9,-5][i % 4],'floor':False})
    PLANS.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    after=sum(len(v.get('decor',[])) for v in data.values())
    print(f'decor_entries {before} -> {after}')
    for k,v in data.items(): print(k, len(v.get('decor',[])))

if __name__=='__main__': main()
