import json,hashlib,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'migration/file-manifest.json').read_text(encoding='utf-8'))
replacement_file=root/'migration/reference-images/replacement_manifest.json'
replacements=set(json.loads(replacement_file.read_text(encoding='utf-8')).get('files',{})) if replacement_file.is_file() else set()
fail=[]
line_endings=[]
pointers=[]
missing=[]
for item in manifest['files']:
    p=root/item['path']
    if not p.is_file():
        missing.append(item['path']);fail.append(item['path']);continue
    if p.stat().st_size==item['size']:continue
    if item['path'].replace('\\','/').removeprefix('migration/reference-images/') in replacements:
        continue
    content=p.read_bytes()
    if content.startswith(b'version https://git-lfs.github.com/spec/v1'):
        pointers.append(item['path'])
    elif len(content.replace(b'\r\n',b'\n'))==item['size'] and b'\x00' not in content:
        line_endings.append(item['path']);continue
    fail.append(item['path'])
report={'inventory_files':len(manifest['files']),'missing':missing,'lfs_pointers':pointers,'size_mismatches': [p for p in fail if p not in missing and p not in pointers], 'windows_line_ending_differences':len(line_endings),'passed':not fail}
output=root/'.toolchain/migration-verification.json'
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f"Migration inventory: {len(manifest['files'])} files; {len(fail)} missing or size mismatches")
print(f"Windows line-ending differences: {len(line_endings)}; unresolved LFS pointers: {len(pointers)}")
if fail:print('\n'.join(fail[:30]));sys.exit(1)
print('API keys remain local; setup does not generate music, models, trailers or game installers.')
