"""Integrate reviewed stationary-aim candidates only while source hashes match."""
import hashlib, json, shutil, argparse
from pathlib import Path
root = Path(__file__).resolve().parents[2]
stage = root / 'build/stationary_aim_candidates'
parser = argparse.ArgumentParser()
parser.add_argument('looks', nargs='+')
parser.add_argument('--reviewed', action='store_true')
args = parser.parse_args()
assert args.reviewed and (stage/'visual_review.png').is_file()
rows = json.loads((root/'build/stationary_aim_anatomy_review.json').read_text())
visuals = json.loads((stage/'visual_manifest.json').read_text())
prepared = []
for look in args.looks:
    assert any(row['look'] == look and (stage/f"visual_review_{row['page']:02d}.png").is_file() for row in visuals)
    report_path = stage/f'{look}_audit.json'
    report = json.loads(report_path.read_text())
    runtime = root/f'assets/art/cast3d_rt/{look}/{look}.glb'
    candidate = stage/f'{look}.glb'
    assert hashlib.sha256(runtime.read_bytes()).hexdigest() == report['base_sha256']
    assert hashlib.sha256(candidate.read_bytes()).hexdigest() == report['candidate_sha256']
    samples = [r for r in rows if r['look'] == look and r['requested'].startswith('aim')]
    assert len(samples) == 2
    assert all(max(r['bone_motion_metres'][f] for f in ('LeftFoot','RightFoot')) < .0001 for r in samples)
    prepared.append((report_path,report,runtime,candidate))
for report_path,report,runtime,candidate in prepared:
    backup = stage/f"{report['look']}_before_{report['base_sha256'][:12]}.glb"
    if not backup.exists(): shutil.copy2(runtime,backup)
    pending = runtime.with_suffix('.glb.tmp')
    shutil.copy2(candidate,pending)
    pending.replace(runtime)
    report.update(approved=True, integrated=True, backup=str(backup))
    report_path.write_text(json.dumps(report,indent=2))
    print('Integrated planted aim:',report['look'])
