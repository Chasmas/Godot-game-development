"""Resumable armed locomotion and short dodge studies on Cass's original rig."""
import dataclasses
import json
from pathlib import Path
from uthana_client import client

root = Path('build/uthana/cass')
character = json.loads((root / 'character_upload.json').read_text())['result']['character_id']
api = client()
armed = ('Both hands hold a small pistol aimed straight forward at chest height. '
         'The right hand grips the pistol and the left hand wraps the right hand '
         'as support, hands stay together in front of the chest throughout. '
         'Elbows bend naturally outside the ribs, shoulders relaxed, torso stable. ')
studies = {
    'armed_idle_v2': ('A woman stands still in a stable two-handed pistol aiming stance. ' + armed +
                       'Only subtle natural breathing and weight balance. Her feet remain planted and there is no stepping or drifting.'),
    'armed_walk_v2': 'A woman walks steadily forward with smooth alternating steps. ' + armed,
    'armed_run_v2': 'A woman runs forward with athletic alternating strides and a slight forward lean. ' + armed,
    'armed_stealth_v2': 'A woman moves slowly forward in a low crouch, knees naturally bent, careful short alternating steps, balanced hips. ' + armed,
    'dodge_forward_v2': ('A woman performs one quick compact forward shoulder roll from a standing pose, '
                         'tucking her chin and knees, rolling over one shoulder onto her back, '
                         'then planting both feet and returning to a balanced standing pose. '
                         'One smooth continuous controlled roll, no jump or somersault.'),
    'dodge_left_v2': ('A woman performs one quick low evasive side roll to her left from standing, '
                      'tucking her chin and knees, rolling over her shoulder, then returning to a balanced standing pose. '
                      'One smooth compact controlled roll, no jump or somersault.'),
    'dodge_right_v2': ('A woman performs one quick low evasive side roll to her right from standing, '
                       'tucking her chin and knees, rolling over her shoulder, then returning to a balanced standing pose. '
                       'One smooth compact controlled roll, no jump or somersault.'),
    'turn_left_v2': ('A woman makes one quick natural ninety degree turn to her left in place, '
                     'with two small foot pivots, upright balanced posture and no sliding.'),
    'turn_right_v2': ('A woman makes one quick natural ninety degree turn to her right in place, '
                      'with two small foot pivots, upright balanced posture and no sliding.'),
    'melee_punch_right_v1': ('A woman throws one compact right cross from a balanced fighting stance. '
                              'She coils her hips and torso slightly, keeps her left hand guarding her face, '
                              'drives the right fist forward at chest height with a bent elbow at impact, then '
                              'returns to the same balanced stance. No exaggerated wind-up, no arm through torso, '
                              'feet stay grounded with a small natural pivot.'),
    'melee_punch_left_v1': ('A woman throws one compact left jab from a balanced fighting stance. '
                             'Her right hand protects her face, the left fist travels forward at chest height, '
                             'shoulder and hips rotate naturally, then she returns to a balanced stance. '
                             'No exaggerated wind-up, no arm through torso, feet stay grounded with a small pivot.'),
    'melee_bat_swing_v1': ('A woman performs one controlled two-handed baseball-bat swing from a neutral stance. '
                            'Both hands stay on the handle, the swing begins with a short torso coil, '
                            'passes across the body at waist-to-chest height, follows through naturally, '
                            'then returns to a ready stance. Keep elbows outside the ribs and feet planted with a small pivot.'),
    'melee_knife_stab_v1': ('A woman performs one short close-range knife thrust from a guarded stance. '
                             'Her right hand holds the knife in a firm forward grip, her left hand guards, '
                             'the torso advances a little with a grounded step, the elbow stays bent at the end of the thrust, '
                             'then she withdraws into a balanced ready stance. No arm through torso or exaggerated lunge.'),
}
for name, prompt in studies.items():
    manifest = root / (name + '.json')
    if manifest.exists():
        record = json.loads(manifest.read_text())
        if not record.get('motion_id'):
            print(name + ': unresolved submission, skipping duplicate', flush=True)
            continue
    else:
        record = {'state': 'submitted', 'character_id': character, 'prompt': prompt}
        manifest.write_text(json.dumps(record, indent=2))
        try:
            result = api.ttm.create_sync(prompt, character_id=character, foot_ik=True)
            record.update(dataclasses.asdict(result) if dataclasses.is_dataclass(result) else vars(result))
            record['state'] = 'generated'
        except Exception as error:
            record.update(state='request_error', error_type=type(error).__name__)
        manifest.write_text(json.dumps(record, indent=2, default=str))
    if not record.get('motion_id'):
        print(name + ': generation failed', flush=True)
        continue
    target = root / (name + '.glb')
    if not target.exists():
        target.write_bytes(api.motions.download_sync(character, record['motion_id'], output_format='glb', fps=30, in_place=True))
    print(name + ': downloaded for review', flush=True)
