"""One resumable, original-rig running study with explicit arm clearance."""
import dataclasses
import json
from pathlib import Path
from uthana_client import client

root = Path('build/uthana/cass')
manifest = root / 'run_arm_clearance_v2.json'
character = json.loads((root / 'character_upload.json').read_text())['result']['character_id']
api = client()
if manifest.exists():
    record = json.loads(manifest.read_text())
    if not record.get('motion_id'):
        raise SystemExit('Prior submission unresolved; do not duplicate generation.')
else:
    prompt = ('A woman runs straight forward at a steady athletic pace. '
              'Natural alternating strides and a slight forward torso lean. '
              'Both elbows are bent about ninety degrees, upper arms slightly '
              'away from the ribs, forearms swing forward and backward beside '
              'the torso, hands remain outside the chest and hips. '
              'Relaxed shoulders, upright head, continuous balanced running.')
    record = {'state': 'submitted', 'character_id': character, 'prompt': prompt}
    manifest.write_text(json.dumps(record, indent=2))
    try:
        result = api.ttm.create_sync(prompt, character_id=character, foot_ik=True)
        record.update(dataclasses.asdict(result) if dataclasses.is_dataclass(result) else vars(result))
        record['state'] = 'generated'
        manifest.write_text(json.dumps(record, indent=2, default=str))
    except Exception as error:
        record.update(state='request_error', error_type=type(error).__name__)
        manifest.write_text(json.dumps(record, indent=2))
        raise SystemExit('Generation failed: ' + type(error).__name__)
target = root / 'run_arm_clearance_v2.glb'
if not target.exists():
    target.write_bytes(api.motions.download_sync(character, record['motion_id'], output_format='glb', fps=30, in_place=True))
print('Run arm-clearance revision downloaded for review; not integrated.', flush=True)
