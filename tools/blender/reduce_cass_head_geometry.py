"""Preserve the original head surface with a separate geometry-only LOD candidate."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass_head_detail'
OUT = BASE / 'geometry_lod_v2'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BASE / 'raw/pre_remeshed.glb'))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
original_faces = len(mesh.data.polygons)
modifier = mesh.modifiers.new('Preserve authored head surface with controlled reduction', 'DECIMATE')
modifier.ratio = 0.04
modifier.use_collapse_triangulate = True
print(json.dumps({'stage': 'geometry_reduction', 'source_polygons': original_faces,
                  'ratio': modifier.ratio, 'uv_transfer': False}), flush=True)
bpy.ops.object.modifier_apply(modifier=modifier.name)
for polygon in mesh.data.polygons:
    polygon.use_smooth = True
bpy.ops.export_scene.gltf(filepath=str(OUT / 'cass_head_geometry_candidate.glb'),
                          export_format='GLB', use_selection=True, export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'cass_head_geometry_work.blend'))
report = {'operation': 'Blender decimation of preserved high source; no voxel reconstruction or UV transfer',
          'source_polygons': original_faces, 'candidate_polygons': len(mesh.data.polygons),
          'candidate_vertices': len(mesh.data.vertices), 'runtime_approved': False,
          'visual_validation': 'Neutral clay required before texture transfer', 'source_models_unchanged': True}
(OUT / 'geometry_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
