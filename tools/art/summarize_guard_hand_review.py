"""Consolidate staged guard evidence without treating sampled checks as approval."""
import json, os
from pathlib import Path

root = Path(os.environ.get('GUARD_HAND_REVIEW_ROOT', 'build/guard_thumb_restored_v22'))
preservation = json.loads((root/'preservation_report.json').read_text())
wrist = json.loads((root/'wrist_deformation_report.json').read_text())
contacts = [json.loads(p.read_text()) for p in sorted(root.glob('contact_*.json'))]
expected = {'aim_dual': {0.0}, 'armed_dual_walk': {0.0, .5, 1.0},
            'armed_dual_run': {0.0, .5, 1.0}, 'reload_dual': {0.0, .5, 1.0}}
observed = {clip: {r['phase'] for r in contacts if r['clip']==clip} for clip in expected}
assert observed == expected, (observed, expected)
assert {r['clip'] for r in wrist['rows']} == set(expected)
assert not preservation['missing_untouched_vertices']
assert not preservation['added_untouched_vertices']
assert all(not side['pierced_hand_triangles'] and not side['body_crossing_pairs_by_part']
           for row in contacts for side in row['rows'])
report = {
    'approved': False,
    'candidate_sha256': preservation['candidate_sha256'],
    'production_sha256': preservation['base_sha256'],
    'contact_phases': {k: sorted(v) for k,v in observed.items()},
    'wrist_samples_per_clip': 65,
    'wrist_area_ratios': {r['clip']: {
        'min': min(s['min_area_ratio'] for s in r['samples']),
        'max': max(s['max_area_ratio'] for s in r['samples']),
        'extreme_samples': r['extreme_samples']} for r in wrist['rows']},
    'unchanged_clips': preservation['unchanged_clips'],
    'remaining': ['Polish thumb/palm attachment and anatomical silhouette.',
                  'Review both hands and full reload performance in Godot.',
                  'Check additional contact phases before integration.'],
    'limitations': ['Contact sampling does not exclude containment or coplanar overlap.',
                    'Area ratios are diagnostic, not anatomical approval.',
                    'No production mesh or weapon renderer is changed.']}
(root/'review_summary.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
