"""Inspect the shipped Cass finger rig without modifying her source GLB."""
import bpy
import hashlib
import json
from pathlib import Path

source = Path('assets/art/cast3d_rt/cass/cass.glb').resolve()
before = hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
hands = [b.name for b in rig.data.bones if any(s in b.name.lower() for s in ['hand', 'finger', 'thumb', 'index', 'middle', 'ring', 'pinky'])]
meshes = []
hand_bounds = []
for mesh in [o for o in bpy.data.objects if o.type == 'MESH']:
    groups = {g.index: g.name for g in mesh.vertex_groups if g.name in hands}
    counts = {name: 0 for name in groups.values()}
    for vertex in mesh.data.vertices:
        for group in vertex.groups:
            if group.group in groups and group.weight > 0.001:
                counts[groups[group.group]] += 1
    meshes.append({'mesh': mesh.name, 'weighted_vertices_per_hand_bone': counts})
    for name in hands:
        group = mesh.vertex_groups.get(name)
        if group is None:
            continue
        to_hand = (rig.matrix_world @ rig.data.bones[name].matrix_local).inverted() @ mesh.matrix_world
        points = [to_hand @ v.co for v in mesh.data.vertices if any(g.group == group.index and g.weight > 0.5 for g in v.groups)]
        if points:
            wrist = [p for p in points if -0.5 <= p.y <= 2.0]
            hand_bounds.append({'mesh': mesh.name, 'hand': name,
                                'bone_length_native': rig.data.bones[name].length,
                                'weighted_region_min_native': [min(p[a] for p in points) for a in range(3)],
                                'weighted_region_max_native': [max(p[a] for p in points) for a in range(3)],
                                'wrist_band_bounds_native': {'min': [min(p[a] for p in wrist) for a in range(3)], 'max': [max(p[a] for p in wrist) for a in range(3)]} if wrist else None,
                                'bone_tail_length_is_fit_reference': False,
                                'fit_reference': 'Use mesh wrist cross-section and hand width; imported bone tails are much longer than the actual hand',
                                'scope': 'Weighted region includes blended wrist; not an anatomical finger segmentation'})
report = {'source': str(source), 'sha256': before, 'hand_and_finger_bones': hands,
          'meshes': meshes, 'hand_bounds': hand_bounds, 'actions': [a.name for a in bpy.data.actions],
          'source_unchanged': hashlib.sha256(source.read_bytes()).hexdigest() == before,
          'runtime_promoted': False,
          'scope': 'Rig and skin-weight inventory; does not approve fist shape or animation.'}
out = Path('build/cass_fist_review')
out.mkdir(parents=True, exist_ok=True)
(out / 'rig_inventory.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps({'hand_bones': hands, 'source_unchanged': report['source_unchanged']}))
