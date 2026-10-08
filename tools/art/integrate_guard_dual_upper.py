"""Promote the reviewed Blender-derived guard dual clip without other asset changes."""
import hashlib,json,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[2]
stage=root/'build/guard_dual_upper_v2'
target=root/'assets/art/cast3d_rt/guard/guard.glb'
candidate=stage/'guard.glb'
audit=json.loads((stage/'audit.json').read_text())
directions=json.loads((stage/'directions_audit.json').read_text())
assert audit['rig_geometry_bind_preserved'] and audit['changed_clips']==['aim_dual']
assert len(audit['unchanged_clips'])==26 and not audit['added_clips']
assert directions['passed'] and len(directions['rows'])==8
assert (stage/'directions.png').is_file()
assert all(r['minimum_hand_forward_m']>.10 and r['minimum_below_head_m']>.10 and r['minimum_hand_separation_m']>.12 for r in directions['rows'])
assert hashlib.sha256(target.read_bytes()).hexdigest()==audit['base_sha256']
assert hashlib.sha256(candidate.read_bytes()).hexdigest()==audit['candidate_sha256']
backup=root/'build/integration_backups'/audit['base_sha256']/'guard.glb'
backup.parent.mkdir(parents=True,exist_ok=True)
if not backup.exists(): shutil.copy2(target,backup)
temporary=target.with_suffix('.reviewed.tmp')
shutil.copy2(candidate,temporary)
temporary.replace(target)
audit['approved']=True
audit['approval_scope']='Guard aim_dual upper body only; native lower tracks, idle breathing, eight GPU facings, 264 posture samples and three-loop playback reviewed.'
(stage/'integration.json').write_text(json.dumps(audit,indent=2))
print('GUARD DUAL INTEGRATION: one clip replaced, 26 clips and rig geometry preserved')
