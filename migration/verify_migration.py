import json,hashlib,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'migration/file-manifest.json').read_text(encoding='utf-8'))
fail=[]
for item in manifest['files']:
    p=root/item['path']
    if not p.is_file() or p.stat().st_size!=item['size']:fail.append(item['path'])
print(f"Migration inventory: {len(manifest['files'])} files; {len(fail)} missing or size mismatches")
if fail:print('\n'.join(fail[:30]));sys.exit(1)
print('API keys remain local; setup does not generate music, models, trailers or game installers.')
