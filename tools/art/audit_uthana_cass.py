import hashlib,json
from pathlib import Path
import numpy as np
from pygltflib import GLTF2
root=Path('build/uthana/cass')
source=GLTF2().load('assets/art/cast3d_rt/cass/cass.glb')
def array(g,index):
    a=g.accessors[index];view=g.bufferViews[a.bufferView]
    types={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}
    width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a.type]
    dtype=np.dtype(types[a.componentType]);stride=view.byteStride or dtype.itemsize*width
    return np.ndarray((a.count,width),dtype=dtype,buffer=g.binary_blob(),offset=(view.byteOffset or 0)+(a.byteOffset or 0),strides=(stride,dtype.itemsize)).copy()
def joints(g):return [g.nodes[i].name for i in g.skins[0].joints]
records=[]
for path in root.glob('*.glb'):
    g=GLTF2().load(str(path));a=g.animations[0]
    position_delta=float(np.max(np.abs(array(source,source.meshes[0].primitives[0].attributes.POSITION)-array(g,g.meshes[0].primitives[0].attributes.POSITION))))
    rotations=[];translations=[];duration=0
    for channel in a.channels:
        sampler=a.samplers[channel.sampler];values=array(g,sampler.output);times=array(g,sampler.input)
        duration=max(duration,float(times[-1,0]))
        if channel.target.path=='rotation':
            dot=min(1,float(abs(np.dot(values[0],values[-1]))));rotations.append(float(np.degrees(2*np.arccos(dot))))
        if channel.target.path=='translation':translations.append(float(np.linalg.norm(values[0]-values[-1])))
    records.append({'clip':path.stem,'same_joint_names_and_order':joints(source)==joints(g),'max_mesh_vertex_delta':position_delta,'duration_s':duration,'max_loop_rotation_degrees':max(rotations,default=0),'max_loop_translation_native_units':max(translations,default=0),'runtime_approved':False})
(root/'source_integrity_and_loop_review.json').write_text(json.dumps(records,indent=2))
print(json.dumps(records,indent=2))
