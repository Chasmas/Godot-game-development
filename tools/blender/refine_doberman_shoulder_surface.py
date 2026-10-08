"""Locally relax shoulder grooves on welded-position adjacency, preserving UVs."""
import bpy
import json
import numpy as np
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/walk_candidate_v4'
strong = '--strong' in sys.argv
welded_normals = '--welded-normals' in sys.argv
strong = strong or welded_normals
OUT = BASE / ('shoulder_surface_candidate_v3' if welded_normals else ('shoulder_surface_candidate_v2' if strong else 'shoulder_surface_candidate_v1'))
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'lateral_shoulder_candidate_v1/dog_doberman_native_skin.blend'))
obj = next(item for item in bpy.context.scene.objects if item.type == 'MESH')
mesh = obj.data
original = np.array([vertex.co[:] for vertex in mesh.vertices], dtype=np.float64)
source_normals = np.array([tuple(normal.vector) for normal in mesh.corner_normals])
rounded = np.round(original, 6)
unique, inverse = np.unique(rounded, axis=0, return_inverse=True)
neighbors = [set() for _ in unique]
for edge in mesh.edges:
    a, b = (int(inverse[index]) for index in edge.vertices)
    if a != b:
        neighbors[a].add(b)
        neighbors[b].add(a)

def smooth(value):
    value = np.clip(value, 0., 1.)
    return value * value * (3. - 2. * value)

x, y, z = unique.T
mask = smooth((-y-.08)/.06) * smooth((y+.42)/.06)
mask *= smooth((z-.34)/.09) * smooth((.65-z)/.06)
mask *= smooth((np.abs(x)-.025)/.05)
positions = unique.copy()
selected = np.flatnonzero(mask > .00001)
for iteration in range(64 if strong else 16):
    updated = positions.copy()
    for index in selected:
        if not neighbors[index]:
            continue
        average = positions[list(neighbors[index])].mean(axis=0)
        candidate = positions[index] + (average - positions[index]) * .3 * mask[index]
        delta = candidate - unique[index]
        length = np.linalg.norm(delta)
        limit = .008 if strong else .003
        if length > limit:
            delta *= limit / length
        updated[index] = unique[index] + delta
    positions = updated
displacements = positions[inverse] - unique[inverse]
corrected = original + displacements
assert np.max(np.linalg.norm(displacements[original[:,2] < .06], axis=1)) == 0
for vertex, position in zip(mesh.vertices, corrected):
    vertex.co = position
# Recompute normals only in the edited patch; retain imported normals elsewhere.
mesh.update()
normals = source_normals.copy()
if welded_normals:
    mesh.calc_loop_triangles()
    triangles = np.array([triangle.vertices[:] for triangle in mesh.loop_triangles])
    face_normals = np.cross(corrected[triangles[:,1]] - corrected[triangles[:,0]],
                            corrected[triangles[:,2]] - corrected[triangles[:,0]])
    accumulated = np.zeros_like(unique)
    for corner in range(3):
        np.add.at(accumulated, inverse[triangles[:,corner]], face_normals)
    lengths = np.linalg.norm(accumulated, axis=1)
    valid = lengths > 1e-14
    accumulated[valid] /= lengths[valid,None]
    for loop in mesh.loops:
        vertex = int(inverse[loop.vertex_index])
        amount = mask[vertex]
        if amount > .00001 and valid[vertex]:
            normal = source_normals[loop.index] * (1-amount) + accumulated[vertex] * amount
            length = np.linalg.norm(normal)
            if length > 1e-12:
                normals[loop.index] = normal / length
else:
    for loop in mesh.loops:
        if mask[inverse[loop.vertex_index]] > .00001:
            normals[loop.index] = (0., 0., 0.)
mesh.normals_split_custom_set(normals)
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'dog_doberman_native_skin.blend'))
bpy.ops.object.select_all(action='DESELECT')
for item in bpy.context.scene.objects:
    if item.type in {'MESH', 'ARMATURE'}:
        item.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT / 'dog_doberman_native_skin.glb'), export_format='GLB',
    use_selection=True, export_animation_mode='ACTIVE_ACTIONS', export_anim_slide_to_zero=True,
    export_optimize_animation_size=False, export_force_sampling=True, export_apply=False)
report = {'runtime_approved': False, 'animation_approved': False,
          'changed_vertices': int(np.count_nonzero(np.linalg.norm(displacements, axis=1) > 1e-8)),
          'maximum_displacement_m': float(np.linalg.norm(displacements, axis=1).max()),
          'relaxation_iterations':64 if strong else 16,
          'welded_area_weighted_normals':welded_normals,
          'sole_geometry_unchanged': True, 'topology_and_uvs_unchanged': True,
          'scope': 'Local shoulder surface candidate; silhouette, normals, export and animated contacts require review'}
(OUT / 'surface_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
