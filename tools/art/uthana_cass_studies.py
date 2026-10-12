"""Generate resumable Cass motion studies, never replace production assets."""
import dataclasses, json
from pathlib import Path
from uthana_client import client
root=Path('build/uthana/cass')
character=json.loads((root/'character_upload.json').read_text())['result']['character_id']
api=client()
for name,style,speed in [('walk','neutral_female_a',1.8),('run','rushed',3.6),('pistol_walk','pistol_female',1.8),('stealth','crouching',0.75)]:
    path=root/(name+'.json')
    if path.exists():
        data=json.loads(path.read_text())
        if not data.get('motion_id'):
            print(name+': unresolved prior submission; skipping duplicate',flush=True)
            continue
    else:
        data={'state':'submitted','character_id':character,'style_id':style,'speed_m_s':speed,'strides':2}
        path.write_text(json.dumps(data,indent=2))
        try:
            result=api.motions.create_locomotion_sync(character,strides=2,move_speed=speed,style_id=style,travel_angle=0)
            data.update(dataclasses.asdict(result) if dataclasses.is_dataclass(result) else vars(result))
            data['state']='generated'
            path.write_text(json.dumps(data,indent=2,default=str))
        except Exception as error:
            data['state']='request_error';data['error_type']=type(error).__name__
            path.write_text(json.dumps(data,indent=2))
            print(name+': '+type(error).__name__,flush=True)
            continue
    target=root/(name+'.glb')
    if not target.exists():
        target.write_bytes(api.motions.download_sync(character,data['motion_id'],output_format='glb',fps=30,in_place=True))
    print(name+': downloaded '+data['motion_id'],flush=True)
