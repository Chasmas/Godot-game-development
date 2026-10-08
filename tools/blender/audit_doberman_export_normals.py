"""Compare exported GLB normals to source Blender corner normals by position."""
import bpy
import json
import struct
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/idle_candidate_v1'
bpy.ops.wm.open_mainfile(filepath=str(OUT / 'dog_doberman_idle_candidate.blend'))
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
blob = (OUT / 'dog_doberman_idle_candidate.glb').read_bytes()
length, _ = struct.unpack_from('<II', blob, 12)
document = json.loads(blob[20:20+length])
binary_start = 20 + length + 8

def vectors(index):
    accessor = document['accessors'][index]
    view = document['bufferViews'][accessor['bufferView']]
    assert accessor['componentType'] == 5126 and accessor['type'] == 'VEC3'
    offset = binary_start + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    return np.ndarray((accessor['count'], 3), dtype='<f4', buffer=blob,
        offset=offset, strides=(view.get('byteStride', 12), 4)).copy()

primitive = document['meshes'][0]['primitives'][0]
positions = vectors(primitive['attributes']['POSITION'])
normals = vectors(primitive['attributes']['NORMAL'])
# Inverse of Blender's glTF Z-up to Y-up conversion.
positions = positions[:, [0, 2, 1]] * [1, -1, 1]
normals = normals[:, [0, 2, 1]] * [1, -1, 1]
corners = {}
for loop in obj.data.loops:
    position = obj.data.vertices[loop.vertex_index].co
    key = tuple(round(float(x), 6) for x in position)
    corners.setdefault(key, set()).add(tuple(obj.data.corner_normals[loop.index].vector))
errors = []
unmatched = 0
for position, normal in zip(positions, normals):
    key = tuple(round(float(x), 6) for x in position)
    if key not in corners:
        unmatched += 1
        continue
    choices = np.array(list(corners[key]))
    dot = np.max(choices @ normal / (np.linalg.norm(choices, axis=1) * np.linalg.norm(normal)))
    errors.append(float(np.degrees(np.arccos(np.clip(dot, -1, 1)))))
assert unmatched == 0, 'Exported geometry no longer matches source reference positions'
report = {'runtime_approved': False, 'scope': 'Base normal preservation only, not animated normal deformation or visual approval',
    'matched_export_vertices': len(errors), 'unmatched_export_vertices': unmatched,
    'source_custom_normals': obj.data.has_custom_normals,
    'source_smooth_faces': sum(p.use_smooth for p in obj.data.polygons),
    'source_faces': len(obj.data.polygons),
    'maximum_normal_angle_difference_degrees': max(errors),
    'p99_normal_angle_difference_degrees': float(np.quantile(errors, .99)),
    'normal_errors_over_one_degree': sum(angle > 1 for angle in errors)}
(OUT / 'export_normal_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
