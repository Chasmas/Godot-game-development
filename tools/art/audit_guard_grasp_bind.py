"""Verify the source mesh's coordinate frame against the retained candidate skin."""
import json, struct, os
from pathlib import Path
import numpy as np

def read(path):
    raw=Path(path).read_bytes()
    size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size])
    offset=20+size
    length=struct.unpack_from('<I',raw,offset)[0]
    return doc,raw[offset+8:offset+8+length]

def matrices(doc, blob, index):
    a=doc['accessors'][index]
    assert a['type']=='MAT4' and a['componentType']==5126 and 'sparse' not in a
    v=doc['bufferViews'][a['bufferView']]
    start=v.get('byteOffset',0)+a.get('byteOffset',0)
    return np.frombuffer(blob,dtype='<f4',count=a['count']*16,offset=start).reshape(-1,4,4).transpose(0,2,1)

def local(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
    x,y,z,w=node.get('rotation',[0,0,0,1])
    rotation=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                       [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                       [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    result=np.eye(4)
    result[:3,:3]=rotation@np.diag(node.get('scale',[1,1,1]))
    result[:3,3]=node.get('translation',[0,0,0])
    return result

def globals_for(doc):
    parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
    cache={}
    def world(i):
        if i not in cache:
            cache[i]=(world(parents[i]) if i in parents else np.eye(4))@local(doc['nodes'][i])
        return cache[i]
    return [world(i) for i in range(len(doc['nodes']))]

base,bb=read('build/guard_dual_wrist_isolated/guard.glb')
source_path=os.environ.get('GUARD_BIND_SOURCE','build/guard_pistol_grasp/guard_grasp.glb')
source,sb=read(source_path)
bi=next(i for i,n in enumerate(base['nodes']) if 'skin' in n and 'mesh' in n)
si=next(i for i,n in enumerate(source['nodes']) if 'skin' in n and 'mesh' in n)
bs=base['skins'][base['nodes'][bi]['skin']]
ss=source['skins'][source['nodes'][si]['skin']]
assert [base['nodes'][i]['name'] for i in bs['joints']]==[source['nodes'][i]['name'] for i in ss['joints']]
bm=matrices(base,bb,bs['inverseBindMatrices'])
sm=matrices(source,sb,ss['inverseBindMatrices'])
bg=globals_for(base);sg=globals_for(source)
mesh_error=float(np.max(np.abs(bg[bi]-sg[si])))
bind_error=float(np.max(np.abs(bm-sm)))
joint_errors=[float(np.max(np.abs(bg[b]-sg[s]))) for b,s in zip(bs['joints'],ss['joints'])]
report={'approved':False,'mesh_world_matrix_error':mesh_error,'inverse_bind_matrix_error':bind_error,
        'max_joint_rest_world_matrix_error':max(joint_errors),'joint_order_preserved':True,
        'scope':'Rest-space matrix parity only; does not validate finger contact or animated surface intersections.'}
report['source']=source_path
out=Path(os.environ.get('GUARD_BIND_REPORT','build/guard_pistol_grasp/bind_report.json'))
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(report,indent=2))
print(json.dumps(report))
assert mesh_error<.002 and bind_error<.002 and max(joint_errors)<.002
