import json,struct,numpy as np
rows=[]
for path in ['build/guard_dual_wrist_bake/guard.glb','build/guard_dual_palmar_bake/guard.glb']:
    raw=open(path,'rb').read();n=struct.unpack_from('<I',raw,12)[0]
    d=json.loads(raw[20:20+n]);blob=raw[28+n:];a=d['animations'][0]
    row={'path':path,'hands':{}}
    for channel in a['channels']:
        target=channel['target'];name=d['nodes'][target['node']].get('name','')
        if name in ('RightHand','LeftHand') and target['path']=='rotation':
            accessor=d['accessors'][a['samplers'][channel['sampler']]['output']]
            view=d['bufferViews'][accessor['bufferView']]
            offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
            row['hands'][name]=np.frombuffer(blob,dtype='<f4',count=4,offset=offset).tolist()
    rows.append(row)
print(json.dumps(rows,indent=2))
assert rows[0]['hands'] != rows[1]['hands'], 'Wrist authoring changed no exported rotations'
