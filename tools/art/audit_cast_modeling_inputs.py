"""Audit every configured cast input locally; never submit or poll paid jobs."""
import json
from pathlib import Path

import meshy_cast_candidate as candidate

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1'


def main():
    config = json.loads((ROOT / 'tools/art/cast_reference_crops.json').read_text(encoding='utf-8'))
    entries = []
    for character in sorted(config):
        folder = BASE / character
        audit_path = folder / 'references/reference_audit.json'
        entry = {'character': character, 'runtime_approval_verified': False}
        if not audit_path.exists():
            entry.update(reference_integrity='not_prepared', reason='No saved Blender reference audit')
        else:
            audit = json.loads(audit_path.read_text(encoding='utf-8'))
            candidate.OUT, candidate.CHARACTER = folder, character
            try:
                _, hashes = candidate.preflight()
                entry.update(reference_integrity='passed', validated_views=len(hashes))
            except (OSError, ValueError, KeyError, RuntimeError) as error:
                disposition = audit.get('disposition', '')
                entry.update(reference_integrity='superseded' if disposition.startswith('Superseded') else 'requires_review',
                             reason=disposition or str(error))
        state_path = folder / 'meshy_task.json'
        if state_path.exists():
            state = json.loads(state_path.read_text(encoding='utf-8'))
            entry.update(task_id=state.get('task_id'),
                         last_recorded_service_status=state.get('last_task_response', {}).get('status'))
        entries.append(entry)
    manifest = json.loads((ROOT / 'assets/art/reference/cast_redesign_v1/batch_manifest.json').read_text(encoding='utf-8'))
    unconfigured = []
    for concept in manifest['entries']:
        character = concept['id']
        if character in config:
            continue
        item = {'concept': character, 'reference_file': concept.get('reference_file'),
                'status': 'no_configured_modeling_views'}
        review_path = BASE / character / 'reference_source_review.json'
        if review_path.exists():
            review = json.loads(review_path.read_text(encoding='utf-8'))
            item.update(source_review_status=review.get('status'), finding=review.get('finding'))
        unconfigured.append(item)
    report = {'scope': 'Reviewed source and crop integrity only; not geometry, anatomy, rig, animation or runtime approval',
              'service_contacted': False, 'entries': entries,
              'unconfigured_concepts_including_supplemental_references': unconfigured}
    output = BASE / 'reference_integrity_batch_audit.json'
    temporary = output.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(report, indent=2), encoding='utf-8')
    temporary.replace(output)
    counts = {status: sum(e['reference_integrity'] == status for e in entries)
              for status in ('passed', 'superseded', 'requires_review', 'not_prepared')}
    print(json.dumps({'reference_sets': len(entries), 'counts': counts,
                      'unconfigured_concepts_including_supplemental_references': len(unconfigured), 'api_calls': 0}))


if __name__ == '__main__':
    main()
