"""Correct measured Uthana support trajectories, retaining generated swing arcs.

Staged targets only. Godot must solve/bake them and prove contact and anatomy.
"""
import json
import sys
from pathlib import Path
import numpy as np

identity = sys.argv[1] if len(sys.argv) > 1 else 'guard'
root = Path('build/uthana/cast_roster/motions') / identity / 'merged'
source = json.loads((root / 'stride_measurement.json').read_text())
records = []
for clip in source['clips']:
    duration = clip['duration_seconds']
    speed = -sum(foot['median_signed_m_s'] for foot in clip['feet']) / 2
    feet = []
    for foot in clip['feet']:
        original = np.asarray(foot['trajectory'], dtype=float)[:-1]
        count = len(original)
        low = original[:, 1].min()
        mask = original[:, 1] <= low + np.ptp(original[:, 1]) * .25
        # Find the longest connected circular support interval, including a
        # stance that crosses the loop boundary. Other low samples remain swing.
        starts = [i for i in range(count) if mask[i] and not mask[(i-1) % count]]
        if not starts:
            raise RuntimeError('No distinct support window: ' + clip['gait'])
        spans = []
        for start in starts:
            length = 0
            while length < count and mask[(start + length) % count]:
                length += 1
            spans.append((length, start))
        length, start = max(spans)
        assert length >= 12, (clip['gait'], length)
        indices = [(start + i) % count for i in range(length)]
        mid = np.mean(original[indices], axis=0)
        target = original.copy()
        for step, index in enumerate(indices):
            elapsed = (step - (length-1)/2) * duration / count
            target[index] = [mid[0], low, mid[2] - speed * elapsed]
        # Retain the original Uthana air trajectory. Smoothly carry the two
        # support-edge offsets through swing, instead of inventing a new gait.
        first_offset = target[indices[0]] - original[indices[0]]
        last_offset = target[indices[-1]] - original[indices[-1]]
        swing = count - length
        for step in range(1, swing+1):
            index = (start + length - 1 + step) % count
            fraction = step / (swing+1)
            weight = fraction * fraction * (3-2*fraction)
            target[index] += last_offset * (1-weight) + first_offset * weight
        target = np.vstack([target, target[0]])
        feet.append({'side':foot['side'], 'support_start_sample':start,
                     'support_sample_count':length, 'sample_count':count,
                     'maximum_adjustment_m':float(np.linalg.norm(target[:-1]-original,axis=1).max()),
                     'targets':target.tolist()})
    records.append({'gait':clip['gait'], 'duration_seconds':duration,
                    'native_speed_m_s':speed, 'feet':feet})
(root / 'contact_targets.json').write_text(json.dumps({'runtime_approved':False,
    'cast':identity, 'scope':'Measured support correction with source swing arcs retained',
    'clips':records}, indent=2))
print(json.dumps([{'gait':c['gait'], 'native_speed_m_s':c['native_speed_m_s'],
    'maximum_adjustment_m':[f['maximum_adjustment_m'] for f in c['feet']]} for c in records], indent=2))
