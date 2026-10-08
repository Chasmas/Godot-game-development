"""Stage a Blender-authored LOD from the high-resolution Cass source, with UV transfer."""
import bpy
import json
import sys
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHARACTER = sys.argv[sys.argv.index('--character') + 1] if '--character' in sys.argv else 'cass'
if not re.fullmatch(r'[a-z][a-z0-9_]*', CHARACTER):
    raise RuntimeError('Invalid character identifier')
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1' / CHARACTER
OUT = BASE / 'repaired_v1'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BASE / 'raw/model.glb'))
source = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(BASE / 'raw/pre_remeshed.glb'))
imported = [obj for obj in bpy.data.objects if obj not in before]
target = next(obj for obj in imported if obj.type == 'MESH')
target.name = CHARACTER + '_BlendAuthored_LOD_Candidate'
bpy.ops.object.select_all(action='DESELECT')
target.select_set(True)
bpy.context.view_layer.objects.active = target
original_faces = len(target.data.polygons)
if CHARACTER == 'cass_head_detail':
    modifier = target.modifiers.new('Blender continuous head surface reconstruction', 'REMESH')
    modifier.mode = 'VOXEL'
    modifier.voxel_size = 0.008
    modifier.use_smooth_shade = True
else:
    modifier = target.modifiers.new('Blender controlled geometry reduction', 'DECIMATE')
    modifier.ratio = 0.095
    modifier.use_collapse_triangulate = True
print(json.dumps({'stage': 'geometry_reconstruction', 'character': CHARACTER,
                  'source_polygons': original_faces, 'method': modifier.type}), flush=True)
bpy.ops.object.modifier_apply(modifier=modifier.name)
print(json.dumps({'stage': 'uv_transfer', 'polygons': len(target.data.polygons)}), flush=True)
if not source.data.uv_layers.active:
    raise RuntimeError('Textured source has no UV layer to transfer')
target.data.uv_layers.new(name=source.data.uv_layers.active.name)
transfer = target.modifiers.new('Transfer reviewed source texture coordinates', 'DATA_TRANSFER')
transfer.object = source
transfer.use_loop_data = True
transfer.data_types_loops = {'UV'}
transfer.loop_mapping = 'POLYINTERP_NEAREST'
bpy.ops.object.modifier_apply(modifier=transfer.name)
target.data.materials.clear()
for material in source.data.materials:
    target.data.materials.append(material)
for polygon in target.data.polygons:
    polygon.use_smooth = True
source.hide_render = True
source.hide_set(True)
bpy.ops.object.select_all(action='DESELECT')
target.select_set(True)
bpy.context.view_layer.objects.active = target
bpy.ops.export_scene.gltf(filepath=str(OUT / (CHARACTER + '_surface_candidate.glb')), export_format='GLB',
                          use_selection=True, export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (CHARACTER + '_surface_work.blend')))
(OUT / 'repair_audit.json').write_text(json.dumps({'operation': 'Blender voxel surface reconstruction' if CHARACTER == 'cass_head_detail' else 'Blender decimation of pre-remeshed source and nearest-surface UV/material transfer',
    'high_source_polygons': original_faces, 'candidate_polygons': len(target.data.polygons),
    'candidate_vertices': len(target.data.vertices), 'uv_layers': len(target.data.uv_layers),
    'runtime_approved': False, 'visual_validation': 'pending rendered comparison',
    'source_models_unchanged': True}, indent=2), encoding='utf-8')
print(json.dumps({'candidate': str(OUT / (CHARACTER + '_surface_candidate.glb')), 'polygons': len(target.data.polygons), 'runtime_approved': False}))
