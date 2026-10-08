"""Repair tiny coincident-seam defects on a preserved Doberman candidate."""
import bpy
import bmesh
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman'
OUT = BASE / 'surface_cleanup_v2'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BASE / 'raw/model.glb'))
reports = []
for obj in [o for o in bpy.context.scene.objects if o.type == 'MESH']:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    before = len(bm.verts)
    # UVs are per-face-corner; preserve those while joining coincident geometry.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=0.000001)
    flap_faces = [f for f in bm.faces if any(e.is_boundary for e in f.edges)
                  and any(len(e.link_faces) > 2 for e in f.edges)]
    flap_count = len(flap_faces)
    bmesh.ops.delete(bm, geom=flap_faces, context='FACES')
    isolated_faces = [f for f in bm.faces if all(e.is_boundary for e in f.edges)]
    isolated_count = len(isolated_faces)
    # The incidence audit identifies a single detached triangular fragment at
    # paw level, not a closed anatomical component or a deliberate accessory.
    if isolated_count != 1 or flap_count != 8:
        raise RuntimeError('Source no longer matches the reviewed defect pattern')
    bmesh.ops.delete(bm, geom=isolated_faces, context='FACES')
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    reports.append({'mesh': obj.name, 'vertices_before': before,
                    'vertices_after': len(bm.verts),
                    'removed_flap_faces': flap_count,
                    'removed_isolated_faces': isolated_count,
                    'boundary_edges': sum(e.is_boundary for e in bm.edges),
                    'nonmanifold_edges': sum(not e.is_manifold for e in bm.edges)})
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'dog_doberman_cleanup_work.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT / 'dog_doberman_surface_candidate.glb'),
                          export_format='GLB', export_animations=False)
report = {'runtime_approved': False, 'source_unchanged': True, 'meshes': reports,
          'operation': 'Coincident seam weld, eight audited flap faces and one isolated paw fragment removed; no global smoothing',
          'visual_review': 'Pending independent textured and clay renders',
          'limitations': 'Remaining nonmanifold edges require inspection; topology counts do not approve anatomy or animation'}
(OUT / 'cleanup_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
