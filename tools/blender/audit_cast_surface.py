"""Inspect welded surface boundaries on the Cass pilot, without changing source."""
import bpy
import bmesh
import json
import sys
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHARACTER = sys.argv[sys.argv.index('--character') + 1] if '--character' in sys.argv else 'cass'
if not re.fullmatch(r'[a-z][a-z0-9_]*', CHARACTER):
    raise RuntimeError('Invalid character identifier')
if CHARACTER != 'cass' and '--face-polish' in sys.argv:
    raise RuntimeError('Cass-specific candidate selectors cannot target another asset')
OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1' / CHARACTER / 'blender_review'
SOURCE = OUT.parent / 'raw/model.glb'
if '--repaired' in sys.argv:
    SOURCE = OUT.parent / 'repaired_v1' / (CHARACTER + '_surface_candidate.glb')
    OUT = OUT.parent / 'repaired_v1/review'
if '--face-polish' in sys.argv:
    SOURCE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass/face_polish_v1/cass_face_candidate.glb'
    OUT = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass/face_polish_v1/review'
if '--dog-surface-cleanup' in sys.argv:
    if CHARACTER != 'dog_doberman':
        raise RuntimeError('Dog surface selector requires dog_doberman')
    SOURCE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/surface_cleanup_v2/dog_doberman_surface_candidate.glb'
    OUT = SOURCE.parent / 'review'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
reports = []
for obj in [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
    edges = {edge for edge in bm.edges if edge.is_boundary}
    components = []
    while edges:
        pending = [edges.pop()]
        group = set(pending)
        while pending:
            current = pending.pop()
            for vertex in current.verts:
                for edge in vertex.link_edges:
                    if edge in edges:
                        edges.remove(edge)
                        group.add(edge)
                        pending.append(edge)
        verts = {vertex for edge in group for vertex in edge.verts}
        degree = {vertex: sum(edge in group for edge in vertex.link_edges) for vertex in verts}
        points = [obj.matrix_world @ vertex.co for vertex in verts]
        center = sum(points, points[0]*0)/len(points)
        components.append({'edges': len(group), 'closed_loop': all(value == 2 for value in degree.values()),
                           'perimeter_source_units': sum(edge.calc_length() for edge in group),
                           'center_blender': list(center),
                           'bounds': {'lower': [min(p[axis] for p in points) for axis in range(3)],
                                      'upper': [max(p[axis] for p in points) for axis in range(3)]}})
    reports.append({'mesh': obj.name, 'vertices_before': before, 'vertices_welded_for_analysis': len(bm.verts),
                    'boundary_components': sorted(components,key=lambda row: row['perimeter_source_units']),
                    'nonmanifold_edges_after_weld': sum(not edge.is_manifold for edge in bm.edges)})
    bm.free()
report = {'scope': 'Surface topology diagnostic on an analysis copy; no original GLB or character model modified.',
          'interpretation': 'Boundary loops may be intentional, including the base of an isolated bust. Topology counts do not approve anatomy, UV quality, animation or runtime integration.',
          'source': str(SOURCE.relative_to(ROOT)),
          'runtime_approved': False, 'meshes': reports}
(OUT / 'surface_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'boundary_components': sum(len(row['boundary_components']) for row in reports),
                  'report': str(OUT / 'surface_audit.json')}))
