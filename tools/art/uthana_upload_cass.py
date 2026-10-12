import dataclasses, json
from pathlib import Path
from uthana_client import client
output = Path('build/uthana/cass')
output.mkdir(parents=True,exist_ok=True)
manifest = output / 'character_upload.json'
if manifest.exists():
    print('Existing Cass upload record preserved; inspect before making another upload.')
    raise SystemExit(0)
source = Path('assets/art/cast3d_rt/cass/cass.glb')
manifest.write_text(json.dumps({'state':'submitted','source':str(source),'auto_rig':False}),encoding='utf-8')
try:
    result = client().characters.create_from_file_sync(str(source),auto_rig=False,name='Hotshot Cass existing model')
    data = dataclasses.asdict(result) if dataclasses.is_dataclass(result) else vars(result)
    manifest.write_text(json.dumps({'state':'response_received','source':str(source),'result':data},indent=2,default=str),encoding='utf-8')
    print(json.dumps(data,default=str))
except Exception as error:
    print('Cass upload did not return a confirmed result:',type(error).__name__)
    raise SystemExit(1)
