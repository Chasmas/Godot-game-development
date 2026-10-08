"""Promote reviewed movement clips, retaining current rig, mesh and other clips."""
import hashlib,json,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[2]
stage=root/'build/guard_dual_movement_isolated_v1'
target=root/'assets/art/cast3d_rt/guard/guard.glb'
candidate=stage/'guard.glb'
audit=json.loads((stage/'audit.json').read_text())
assert audit['rig_geometry_bind_preserved']
assert set(audit['changed_clips'])=={'armed_dual_walk','armed_dual_run'}
assert len(audit['unchanged_clips'])==25 and not audit['added_clips']
for folder,clip in [('walk','armed_dual_walk'),('run','armed_dual_run')]:
 report=json.loads((stage/folder/'directions_audit.json').read_text())
 assert report['passed'] and report['clip']==clip and len(report['rows'])==8
 assert (stage/folder/'directions.png').is_file()
 assert all(r['minimum_hand_forward_m']>.10 and r['minimum_below_head_m']>.10 and r['minimum_hand_separation_m']>.12 for r in report['rows'])
assert hashlib.sha256(target.read_bytes()).hexdigest()==audit['base_sha256']
assert hashlib.sha256(candidate.read_bytes()).hexdigest()==audit['candidate_sha256']
backup=root/'build/integration_backups'/audit['base_sha256']/'guard.glb'
backup.parent.mkdir(parents=True,exist_ok=True)
if not backup.exists():shutil.copy2(target,backup)
temporary=target.with_suffix('.reviewed.tmp');shutil.copy2(candidate,temporary);temporary.replace(target)
audit['approved']=True
audit['approval_scope']='Guard dual walking/running arm channels; current mesh/weapons unchanged. Eight directions each, 264 posture phases each, three-loop playback reviewed.'
(stage/'integration.json').write_text(json.dumps(audit,indent=2))
print('GUARD MOVEMENT INTEGRATION: two clips replaced; rig, mesh and 25 clips preserved')
