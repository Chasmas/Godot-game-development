"""Measure separate paw regions on the cleaned GLB before authoring a rig."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/dog_doberman/surface_cleanup_v2'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(BASE / 'dog_doberman_surface_candidate.glb'))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
lower = Vector(tuple(min(p[a] for p in points) for a in range(3)))
upper = Vector(tuple(max(p[a] for p in points) for a in range(3)))
scale = .88 / (upper.z - lower.z)
origin = Vector(((lower.x + upper.x) / 2, (lower.y + upper.y) / 2, lower.z))
points = [(p - origin) * scale for p in points]
regions = {}
for side, sx in [('negative_x', -1), ('positive_x', 1)]:
    for pair, sy in [('front', -1), ('rear', 1)]:
        samples = [p for p in points if p.z < .035 and p.x * sx > .025 and p.y * sy > .10]
        if not samples:
            raise RuntimeError('Missing independent paw region: ' + pair + '_' + side)
        lo = [min(p[a] for p in samples) for a in range(3)]
        hi = [max(p[a] for p in samples) for a in range(3)]
        regions[pair + '_' + side] = {'samples': len(samples), 'bounds_m': {'lower': lo, 'upper': hi},
            'contact_target_m': [(lo[0]+hi[0])/2, (lo[1]+hi[1])/2, 0.0],
            'surface_min_z_m': lo[2]}
report = {'source': str((BASE / 'dog_doberman_surface_candidate.glb').relative_to(ROOT)),
          'normalized_height_m': .88, 'orientation': 'Front negative Y; side labels are explicit world-X signs, not anatomical names',
          'paw_regions': regions, 'runtime_approved': False, 'rig_approved': False,
          'scope': 'Geometric contact-region measurement, not a rig or animated ground-contact validation'}
(BASE / 'review/paw_contact_measurements.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report), flush=True)
