"""Audit evidence for direct M01 legacy-decor runtime replacements.

This deliberately marks only exact category-to-anchor coverage. Similar-looking
or gameplay-equivalent BreakableProps stay outside this audit until their own
legacy family is proven to be replaced.
"""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INVENTORY = ROOT / 'build/m01_asset_replacement_inventory.json'
OUT = ROOT / 'build/m01_runtime_replacement_coverage_audit.json'
DIRECT = {
    'motel_ice_bucket': ('m01_guest_ice_bucket_empty', 1),
    'motel_ice_bucket_full': ('m01_guest_ice_bucket_full', 2),
    'hq_pool_cooler': ('m01_pool_cooler', 2),
    'motel_bougainvillea': ('m01_bougainvillea', 3),
    'motel_bedside_lamp': ('m01_bedside_lamp', 8),
    'motel_neon_vacancy_sign': ('m01_neon_vacancy_sign', 3),
    'motel_housekeeping_cart': ('m01_housekeeping_cart', 1),
    'motel_palm_planter': ('m01_palm_planter', 4),
    'motel_pool_lounger': ('m01_pool_lounger', 2),
    'motel_pool_float': ('m01_pool_ring', 1),
    'motel_pool_float_flamingo': ('m01_pool_flamingo', 1),
    'motel_pool_party_ruin': ('m01_pool_party_ruin', 1),
    'motel_pool_umbrella': ('m01_pool_umbrella', 1),
    'motel_room_key_spill': ('m01_room_key_spill', 7),
    'motel_suitcase_open': ('m01_open_suitcase', 3),
    'motel_telephone': ('m01_motel_telephone', 2),
    'motel_tv_crt': ('m01_crt_tv', 3),
    'motel_towel_cart': ('m01_towel_cart', 8),
}

def path_ok(value: str) -> bool:
    return bool(value) and (ROOT / value).exists()

def main() -> None:
    doc = json.loads(INVENTORY.read_text(encoding='utf-8'))
    evidence = {row['id']: row for row in doc.get('runtime_replacement_evidence', [])}
    categories = {row['id']: row for row in doc.get('legacy_decor_categories', [])}
    failures: list[str] = []
    verified: list[dict] = []
    for category, (evidence_id, expected) in DIRECT.items():
        row = categories.get(category)
        proof = evidence.get(evidence_id)
        if row is None or proof is None:
            failures.append(f'{category}: missing category or evidence {evidence_id}')
            continue
        if int(row.get('placements', -1)) != expected or int(proof.get('placements', -1)) != expected:
            failures.append(f'{category}: expected {expected} placements')
        if not all(path_ok(str(proof.get(key, ''))) for key in ('asset', 'runtime_builder', 'verification')):
            failures.append(f'{category}: source, builder, or review evidence missing')
        contract = str(proof.get('contract', ''))
        if contract and not path_ok(contract): failures.append(f'{category}: contract evidence missing')
        if 'Runtime verified by ' + evidence_id not in str(row.get('replacement_coverage', '')):
            failures.append(f'{category}: category coverage status not synchronized')
        verified.append({'category': category, 'evidence': evidence_id, 'placements': expected})
    remaining = [row['id'] for row in doc.get('legacy_decor_categories', []) if row['id'] not in DIRECT]
    report = {'passed': not failures, 'verified_exact_categories': verified, 'remaining_unverified_categories': remaining, 'failures': failures,
              'scope': 'Exact M01 legacy Decor category mappings only. BreakableProp overlays and room dressing are evidenced separately and are not claimed as decor-category coverage.'}
    OUT.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f'M01 runtime replacement coverage: {len(verified)} exact categories, {len(remaining)} remaining, {len(failures)} failures')
    if failures: raise SystemExit(1)

if __name__ == '__main__': main()
