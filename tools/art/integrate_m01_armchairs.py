"""Copy reviewed ImageGen/Blender chairs and placements into runtime assets."""
import json,shutil,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[2]
source=root/'assets/art/prerendered/m01_sunset_palms/staging/armchair_runtime_v3'
destination=root/'assets/art/prerendered/m01_sunset_palms/runtime/armchair_v1'
contract=json.loads((source/'runtime_contract.json').read_text())
placements=json.loads((root/'build/m01_armchair_placement_review.json').read_text())
projection=json.loads((root/'build/m01_armchair_projection_audit.json').read_text())
assert projection['passed'] and len(placements)==len(projection['placements'])==11
assert [p['position'] for p in placements]==[p['position'] for p in projection['placements']], 'Projection audit belongs to different placements'
assert all(p['clear_player_approaches']>0 and p['reachable_door_arc_overlaps']==0 and p['projected_wall_samples']==0 for p in placements)
assert len(contract['collision_footprint_metres'])==2
destination.mkdir(parents=True,exist_ok=True)
hashes={}
for frame in contract['frames']:
    name=frame['file']
    assert Path(name).name==name
    shutil.copy2(source/name,destination/name)
    hashes[name]=hashlib.sha256((destination/name).read_bytes()).hexdigest()
contract.update(runtime_approved=True,placements=placements,source_sha256=hashes)
(destination/'runtime_contract.json').write_text(json.dumps(contract,indent=2))
print('M01 native chairs: four rendered directions, eleven reviewed placements copied')
