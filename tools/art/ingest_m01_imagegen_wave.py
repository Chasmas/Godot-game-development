"""Copy original ImageGen outputs and register their prompts/provenance."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / 'assets/art/materials/m01/batch_v1'
wave_path = Path(sys.argv[1])
wave = json.loads(wave_path.read_text(encoding='utf-8'))
prompts = {a['id']: a for a in wave['assets']}
manifest_path = BATCH / 'manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
registered = {a['id']: a for a in manifest['assets']}
for source in wave['sources']:
    original = Path(source['source'])
    target = BATCH / (source['id'] + '.png')
    original_hash = hashlib.sha256(original.read_bytes()).hexdigest()
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() != original_hash:
        raise RuntimeError(f'Refusing to overwrite different existing asset: {target}')
    if not target.exists():
        shutil.copy2(original, target)
    assert hashlib.sha256(target.read_bytes()).hexdigest() == original_hash
    registered[source['id']] = {**prompts[source['id']], **source,
        'file': target.name, 'sha256': original_hash, 'mode': 'built_in_imagegen',
        'blender_work_started': False, 'quality_review': 'pending'}
manifest['assets'] = list(registered.values())
manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'Registered {len(wave["sources"])} originals with exact-copy hashes.')
