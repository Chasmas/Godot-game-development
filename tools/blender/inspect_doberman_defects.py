"""Inspect face incidence at welded Doberman defects without editing the source."""
import bpy
import bmesh
import json
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BASE / 'raw/model.glb'))
rows = []
for obj in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
    bm.verts.index_update()
    bm.faces.index_update()
    face_keys = Counter(tuple(sorted(v.index for v in f.verts)) for f in bm.faces)
    defects = []
    for edge in bm.edges:
        if edge.is_manifold:
            continue
        defects.append({'vertices_world': [list(obj.matrix_world @ v.co) for v in edge.verts],
                        'face_count': len(edge.link_faces),
                        'faces': [{'index': f.index, 'area': f.calc_area(),
                                   'normal': list(f.normal),
                                   'duplicate_count': face_keys[tuple(sorted(v.index for v in f.verts))]}
                                  for f in edge.link_faces]})
    flap_faces = [f for f in bm.faces if any(e.is_boundary for e in f.edges)
                  and any(len(e.link_faces) > 2 for e in f.edges)]
    flap_indices = [f.index for f in flap_faces]
    original_incidence = dict(Counter(r['face_count'] for r in defects))
    bmesh.ops.delete(bm, geom=flap_faces, context='FACES')
    rows.append({'mesh': obj.name, 'defects': defects,
                 'dry_run_flap_face_indices': flap_indices,
                 'dry_run_remaining_nonmanifold_edges': sum(not e.is_manifold for e in bm.edges),
                 'dry_run_remaining_edges': [{'face_count': len(e.link_faces),
                     'vertices_world': [list(obj.matrix_world @ v.co) for v in e.verts],
                     'face_indices': [f.index for f in e.link_faces]}
                     for e in bm.edges if not e.is_manifold],
                 'incidence_counts': original_incidence,
                 'duplicate_face_groups': sum(c > 1 for c in face_keys.values())})
    bm.free()
report = {'source_unchanged': True, 'runtime_approved': False, 'meshes': rows}
(BASE / 'blender_review/defect_incidence_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps([{'mesh': r['mesh'], 'incidence_counts': r['incidence_counts'],
                   'dry_run_flap_faces': len(r['dry_run_flap_face_indices']),
                   'dry_run_remaining_nonmanifold_edges': r['dry_run_remaining_nonmanifold_edges'],
                   'duplicate_face_groups': r['duplicate_face_groups']} for r in rows]))
