"""Compare transferred normal detail on the staged Cass face; never edit runtime assets."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass/repaired_v1'
OUT = BASE / 'shading_review'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'review/cass_candidate_review.blend'))
scene = bpy.context.scene
# The review saves its final camera as the face close-up.
normal_nodes = [node for material in bpy.data.materials if material.use_nodes
                for node in material.node_tree.nodes if node.type == 'NORMAL_MAP']
if not normal_nodes:
    raise RuntimeError('No normal-map node to compare')
original = [node.inputs['Strength'].default_value for node in normal_nodes]
report = {'runtime_approved': False, 'source_models_unchanged': True,
          'purpose': 'Separate geometry/albedo defects from transferred normal shading defects',
          'original_normal_strengths': original, 'renders': []}
for strength in (0.0, 0.25):
    for node in normal_nodes:
        node.inputs['Strength'].default_value = strength
    name = 'face_normal_' + str(strength).replace('.', '_') + '.png'
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    report['renders'].append({'file': name, 'normal_strength': strength})
for node, strength in zip(normal_nodes, original):
    node.inputs['Strength'].default_value = strength
(OUT / 'comparison_audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report))
