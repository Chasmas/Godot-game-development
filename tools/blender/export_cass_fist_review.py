"""Create a review-only fist LOD and measure its surface deviation."""
import bpy
import json
from pathlib import Path
from mathutils.bvhtree import BVHTree

root = Path('build/cass_fist_review/volume_candidate_v4').resolve()
bpy.ops.wm.open_mainfile(filepath=str(root / 'fist.blend'))
fist = bpy.data.objects['Cass_Fist_Volume_Study']
original_points = [v.co.copy() for v in fist.data.vertices]
original_faces = [tuple(p.vertices) for p in fist.data.polygons]
source_tree = BVHTree.FromPolygons(original_points, original_faces, all_triangles=False)
original_count = len(fist.data.polygons)
bpy.ops.object.select_all(action='DESELECT')
fist.select_set(True)
bpy.context.view_layer.objects.active = fist
modifier = fist.modifiers.new('Review_LOD', 'DECIMATE')
modifier.ratio = 0.25
bpy.ops.object.modifier_apply(modifier=modifier.name)
candidate_tree = BVHTree.FromPolygons([v.co for v in fist.data.vertices], [tuple(p.vertices) for p in fist.data.polygons], all_triangles=False)
source_to_candidate = max(candidate_tree.find_nearest(point)[3] for point in original_points)
candidate_to_source = max(source_tree.find_nearest(v.co)[3] for v in fist.data.vertices)
error = max(source_to_candidate, candidate_to_source)
report = {'runtime_promoted': False, 'visual_approved': False,
          'source_faces': original_count, 'candidate_faces': len(fist.data.polygons),
          'sampled_bidirectional_surface_deviation_m': error,
          'surface_deviation_under_2mm': error < 0.002,
          'scope': 'Mesh LOD surface samples; does not prove silhouette, rig, texture or anatomical quality'}
(root / 'lod_review.json').write_text(json.dumps(report, indent=2))
if not report['surface_deviation_under_2mm']:
    raise RuntimeError('Review LOD exceeds surface deviation limit')
bpy.ops.export_scene.gltf(filepath=str(root / 'fist_review.glb'), export_format='GLB', use_selection=True, export_animations=False)
print(json.dumps(report))
