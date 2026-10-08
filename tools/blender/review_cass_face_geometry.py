"""Render clay close-ups to isolate model geometry from generated texture artifacts."""
import bpy
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/art/Artwork/3d/cast_redesign_v1/cass/face_polish_v1'
OUT = BASE / 'geometry_review'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE / 'review/cass_candidate_review.blend'))
scene = bpy.context.scene
material = bpy.data.materials.new('Neutral clay diagnostic')
material.use_nodes = True
shader = material.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value = (0.3, 0.3, 0.3, 1)
shader.inputs['Roughness'].default_value = 0.8
scene.view_layers[0].material_override = material
camera = scene.camera
focus = Vector((0, 0, 1.56))
for name, position in [('front', (0, -3, 1.56)), ('three_quarter', (1.5, -3, 1.56))]:
    camera.location = position
    camera.rotation_euler = (focus-camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(OUT / ('face_clay_' + name + '.png'))
    bpy.ops.render.render(write_still=True)
(OUT / 'geometry_review_audit.json').write_text(json.dumps({
    'scope': 'Clay material override, no texture or normal maps; static face geometry only',
    'source_models_unchanged': True, 'runtime_approved': False,
    'renders': ['face_clay_front.png', 'face_clay_three_quarter.png']
}, indent=2), encoding='utf-8')
