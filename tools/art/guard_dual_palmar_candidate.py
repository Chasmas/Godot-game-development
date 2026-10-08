"""Stage wrist palms inward/downward for distinct authored pistol fingers."""
from pathlib import Path
source=Path('tools/art/guard_dual_wrist_candidate.py').read_text()
old='Matrix(((0,1,0),(-1,0,0),(0,0,1)))'
assert source.count(old)==1
source=source.replace(old,'Matrix(((0,1,0),(0,0,1),(1,0,0)))')
needle="for side in ('Right','Left'):\n                wrist"
assert source.count(needle)==1
source=source.replace(needle,"""for side in ('Right','Left'):
                # Native X spans the fingers; put it along the vertical
                # pistol handle, mirrored so BOTH thumbs remain above it.
                world_basis = Matrix(((0,1,0),(0,0,1),(1,0,0))) if side == 'Right' else Matrix(((0,1,0),(0,0,-1),(-1,0,0)))
                local_basis = arm.matrix_world.to_3x3().inverted() @ world_basis
                wrist""")
exec(compile(source,'tools/art/guard_dual_wrist_candidate.py','exec'))
