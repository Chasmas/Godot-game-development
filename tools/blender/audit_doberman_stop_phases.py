"""Author independent interruption candidates and compare their contact reports."""
import json
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
surface = '--surface' in sys.argv
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman' / ('blocked_stop_phase_candidates_v3' if surface else 'blocked_stop_phase_candidates_v2')
samples = []
for frame in (1, 4, 7, 10, 13, 16, 19):
    sys.argv = ['author_doberman_start_contact.py', '--blocked-stop', '--late-body', f'--stop-frame={frame}']
    if surface:
        sys.argv.append('--surface')
    runpy.run_path(str(ROOT / 'tools/blender/author_doberman_start_contact.py'), run_name='__main__')
    report = json.loads((OUT / f'frame_{frame:02d}/contact_audit.json').read_text())
    samples.append({key: report[key] for key in (
        'blocked_source_frame', 'blocked_source_pose_difference_m',
        'idle_handoff_mesh_difference_m', 'maximum_support_slip_per_frame_m',
        'minimum_sole_height_m')})
passed = all(sample['blocked_source_pose_difference_m'] < .0001
             and sample['idle_handoff_mesh_difference_m'] < .0001
             and sample['maximum_support_slip_per_frame_m'] < .0001
             and sample['minimum_sole_height_m'] > -.0001 for sample in samples)
report = {'runtime_approved': False, 'animation_approved': False,
          'sampled_source_frames': 7, 'stop_frames_per_candidate': 19,
          'contact_and_endpoint_checks_passed': passed, 'samples': samples,
          'scope': 'Seven Blender interruption sources; no proof for every source time, Godot export, visual quality, or gameplay'}
(OUT / 'phase_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('STOP_PHASE_AUDIT ' + json.dumps(report), flush=True)
