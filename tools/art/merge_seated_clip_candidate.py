"""Replace only doze channels in a staging copy; preserve original geometry/clips."""
import copy,json,struct,hashlib,sys
import numpy as np
from pathlib import Path

def read(path):
    b=path.read_bytes();size,kind=struct.unpack_from('<II',b,12)
    d=json.loads(b[20:20+size]);offset=20+size;n,k=struct.unpack_from('<II',b,offset)
    return d,b[offset+8:offset+8+n]
identity=sys.argv[sys.argv.index('--identity')+1] if '--identity' in sys.argv else 'bellhop'
source=Path('assets/art/cast3d_rt')/identity/(identity+'.glb')
candidate=Path('build/seated_contacts')/(identity+'_candidate_v2')/(identity+'_doze.glb')
d,raw=read(source);c,added=read(candidate)
original=copy.deepcopy(d)
names={}
for i,node in enumerate(d['nodes']):
    name=node.get('name','')
    assert name not in names,'Ambiguous source node '+name
    names[name]=i
shift=len(raw);assert shift%4==0
views=len(d['bufferViews']);accessors=len(d['accessors'])
for v in c['bufferViews']:
    v=copy.deepcopy(v);v['byteOffset']=v.get('byteOffset',0)+shift;v['buffer']=0;d['bufferViews'].append(v)
for a in c['accessors']:
    a=copy.deepcopy(a)
    assert 'sparse' not in a
    if 'bufferView' in a:a['bufferView']+=views
    d['accessors'].append(a)
assert len(c['animations'])==1
animation=copy.deepcopy(c['animations'][0]);animation['name']='doze'
for sampler in animation['samplers']:
    sampler['input']+=accessors;sampler['output']+=accessors
for channel in animation['channels']:
    node=c['nodes'][channel['target']['node']];name=node['name'];assert name in names
    channel['target']['node']=names[name]
def bind_matrices(doc,binary):
    skin=doc['skins'][0];a=doc['accessors'][skin['inverseBindMatrices']];v=doc['bufferViews'][a['bufferView']]
    offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',64)
    return {doc['nodes'][node]['name']:struct.unpack_from('<16f',binary,offset+i*stride) for i,node in enumerate(skin['joints'])}
left=bind_matrices(original,raw);right=bind_matrices(c,added)
assert left.keys()==right.keys()
bind_errors=[]
for name in left:
    source_bind=np.array(left[name]).reshape(4,4).T
    candidate_bind=np.array(right[name]).reshape(4,4).T
    correction=np.linalg.inv(candidate_bind)@source_bind
    for point in [[0,0,0,1],[1,0,0,1],[0,1,0,1],[0,0,1,1]]:
        point=np.array(point);bind_errors.append(float(np.linalg.norm((correction@point-point)[:3])))
max_bind_error_m=max(bind_errors)
assert max_bind_error_m<.0001,('Bind pose differs by more than 0.1 mm',max_bind_error_m)
index=next(i for i,a in enumerate(d['animations']) if a['name']=='doze')
d['animations'][index]=animation
d['buffers'][0]['byteLength']=len(raw)+len(added)
for key in ['meshes','skins','nodes','materials','textures','images']:assert d.get(key)==original.get(key)
assert [a for a in d['animations'] if a['name']!='doze']==[a for a in original['animations'] if a['name']!='doze']
payload=json.dumps(d,separators=(',',':')).encode();payload+=b' '*((-len(payload))%4)
binary=raw+added;binary+=b'\0'*((-len(binary))%4)
blob=struct.pack('<III',0x46546c67,2,12+8+len(payload)+8+len(binary))+struct.pack('<II',len(payload),0x4e4f534a)+payload+struct.pack('<II',len(binary),0x004e4942)+binary
out=candidate.parent/(identity+'_full_candidate.glb');out.write_bytes(blob)
report={'runtime_approved':False,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'candidate_sha256':hashlib.sha256(blob).hexdigest(),'original_binary_prefix_preserved':binary[:len(raw)]==raw,'other_clips_unchanged':True,'geometry_materials_skins_unchanged':True,'clips':len(d['animations']),'max_bind_probe_error_m':max_bind_error_m,'bind_tolerance_m':.0001}
(out.parent/'merge_review.json').write_text(json.dumps(report,indent=2))
print(report)
