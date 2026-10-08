"""Derive an activity-only morph from the verified static grip sculpt."""
from pathlib import Path
source = Path('tools/blender/sculpt_consumable_grip.py').read_text()
source = source.replace("build/consumable_grip_sculpt_v5", "build/consumable_grip_morph")
source = source.replace("    original_uvs =", "    body.shape_key_add(name='Basis')\n    grip_key = body.shape_key_add(name='CanGrip')\n    original_uvs =",1)
source = source.replace('        vertex.co = forward @ curled','        grip_key.data[vertex.index].co = forward @ curled')
source = source.replace("'scope':'Static review candidate; hand-only subdivision interpolates source UVs and weights. Finger/prop fit and action-specific playback remain unvalidated.'", "'scope':'CanGrip morph defaults to zero; closed shape only for drink activity. Runtime clip and morph lifecycle validation pending.'")
assert 'grip_key.data[vertex.index].co' in source
exec(compile(source, 'tools/blender/sculpt_consumable_grip.py', 'exec'))
