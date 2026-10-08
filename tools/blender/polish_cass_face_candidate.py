"""Local Blender facial smoothing experiment; original GLBs remain unchanged."""
import bpy
import bmesh
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass'
OUT = BASE / 'face_polish_v1'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BASE / 'repaired_v1/cass_surface_candidate.glb'))
obj = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
bpy.context.view_layer.objects.active = obj
# glTF splits vertices at UV seams. Weld coincident geometry before smoothing
# so independent copies cannot drift apart; loop UV coordinates are retained.
bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.000001)
bm.to_mesh(obj.data)
bm.free()
obj.data.update()
group = obj.vertex_groups.new(name='Localized facial surface polish')
affected = 0
for vertex in obj.data.vertices:
    x, y, z = vertex.co
    ellipse = (x / 0.115) ** 2 + ((z - 0.715) / 0.12) ** 2
    if ellipse < 1.0 and y < -0.065:
        weight = (1.0 - ellipse) * min(1.0, (-y - 0.065) / 0.035)
        group.add([vertex.index], weight, 'REPLACE')
        affected += 1
if affected < 100:
    raise RuntimeError('Facial region selection invalid; inspect coordinates')
modifier = obj.modifiers.new('Restrained facial surface smoothing', 'SMOOTH')
modifier.vertex_group = group.name
modifier.factor = 0.35
modifier.iterations = 3
bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'cass_face_candidate.glb'), export_format='GLB',
                          use_selection=True, export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'cass_face_work.blend'))
(OUT / 'polish_audit.json').write_text(json.dumps({'affected_vertices': affected,
    'operation': 'Three iterations of weighted localized facial smoothing, factor 0.35',
    'runtime_approved': False, 'source_models_unchanged': True,
    'visual_validation': 'pending'}, indent=2), encoding='utf-8')
print(json.dumps({'affected_vertices': affected, 'output': str(OUT)}))
