"""Non-destructive Blender material pass on existing authored M01 interiors."""
from pathlib import Path
import json
import os
import sys
import bpy

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from m01_imagegen_materials import apply_reviewed_source

SOURCE = Path(os.environ.get('M01_REVIEW_SOURCE', str(ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/m01_interiors_transitions_staging.blend')))
OUT = Path(os.environ.get('M01_REVIEW_OUT', str(ROOT / 'assets/art/prerendered/m01_sunset_palms/staging/imagegen_batch_v1')))
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bindings = {
    'wallpaper stripes': 'wallpaper',
    'wallpaper warm': 'wallpaper',
    'motel carpet': 'carpet',
    'teal guest carpet': 'carpet',
    'lobby terrazzo check': 'reception_floor',
    'floral bedspread': 'bedspread',
    'floral bedspread 2': 'bedspread',
    'veneer grain': 'walnut',
    'white towel': 'towel',
    'service wall tiles': 'bathroom_tiles',
}
applied = []
for name, key in bindings.items():
    material = bpy.data.materials.get(name)
    if material is None:
        raise RuntimeError(f'Missing authored material: {name}')
    apply_reviewed_source(material, key)
    applied.append({'material': name, 'source': material['imagegen_source'],
                    'repeat_metres': material['repeat_metres']})
scene = bpy.context.scene
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.filepath = str(OUT / 'interiors_material_review.png')
scene['imagegen_batch_stage'] = 'material_reconstruction_review'
scene['runtime_approved'] = False
# Pack reviewed source pixels into this staging copy, preserving old .blend.
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'interiors_material_review.blend'))
bpy.ops.render.render(write_still=True)
(OUT / 'material_bindings.json').write_text(json.dumps({
    'source_blend': str(SOURCE.relative_to(ROOT)),
    'blender_materials_applied': applied,
    'runtime_approved': False,
    'collision_layout_changed': False,
    'review_pending': ['rendered scale', 'material seams', 'projection', 'gameplay integration'],
}, indent=2), encoding='utf-8')
print(f'M01_IMAGEGEN_MATERIALS_APPLIED={len(applied)}')
