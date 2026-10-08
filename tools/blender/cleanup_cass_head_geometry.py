"""Localized facial cleanup experiment; preserve preceding geometry candidate."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass_head_detail'
OUT = BASE / 'geometry_cleanup_v4'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BASE / 'geometry_lod_v2/cass_head_geometry_candidate.glb'))
mesh = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
bpy.context.view_layer.objects.active = mesh
mesh.select_set(True)
corners = [mesh.matrix_world @ Vector(corner) for corner in mesh.bound_box]
lower = Vector(tuple(min(point[a] for point in corners) for a in range(3)))
upper = Vector(tuple(max(point[a] for point in corners) for a in range(3)))
scale = .48 / (upper.z - lower.z)
center_x = (lower.x + upper.x) / 2
center_y = (lower.y + upper.y) / 2
group = mesh.vertex_groups.new(name='Localized eyelid and brow cleanup')
affected = 0
for vertex in mesh.data.vertices:
    world = mesh.matrix_world @ vertex.co
    x = (world.x - center_x) * scale
    y = (world.y - center_y) * scale
    z = (world.z - lower.z) * scale
    # Match the normalized orthographic review; restrict to anterior face.
    if y > -.04:
        continue
    distance = min(((x-side*.043)/.022)**2 + ((z-.326)/.017)**2 for side in (-1, 1))
    weight = max(0., 1. - distance)
    if weight > 0:
        group.add([vertex.index], weight, 'REPLACE')
        affected += 1
modifier = mesh.modifiers.new('Localized facial smoothing experiment', 'SMOOTH')
modifier.vertex_group = group.name
modifier.factor = .3
modifier.iterations = 6
bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'cass_head_cleanup_candidate.glb'), export_format='GLB',
                          use_selection=True, export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'cass_head_cleanup_work.blend'))
report = {'operation': 'Weighted local eyelid/brow smoothing on geometry LOD v2',
          'affected_vertices': affected, 'factor': .3, 'iterations': 6,
          'runtime_approved': False, 'visual_validation': 'pending independent neutral clay comparison',
          'limitations': 'Smoothing alone does not create eyelid loops or an animation-ready facial rig',
          'selection_space': 'World coordinates including GLB import rotation, normalized to review height',
          'previous_candidates_unchanged': True}
(OUT / 'cleanup_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
