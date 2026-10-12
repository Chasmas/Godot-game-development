"""Copy the reviewed M01 window-strip family into a runtime contract."""
from pathlib import Path
import json, shutil

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/window_strip_family_v1'
DEST=ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/window_strip_family_v1'
contract=json.loads((SOURCE/'contract.json').read_text(encoding='utf-8'))
if contract.get('runtime_approved'):
    raise SystemExit('Staging contract must not self-approve')
DEST.mkdir(parents=True,exist_ok=True)
for frame in contract['frames']:
    shutil.copy2(SOURCE/frame['file'],DEST/frame['file'])
runtime={**contract,'runtime_approved':True,'pending':[],'approval_scope':'M01 twenty existing GlassWindow bodies only; preserve collision, hit point, shatter and damaged-frame behavior.','expected_placements':20}
(DEST/'runtime_contract.json').write_text(json.dumps(runtime,indent=2)+'\n',encoding='utf-8')
print('M01 window family promoted: 5 reviewed span frames')
