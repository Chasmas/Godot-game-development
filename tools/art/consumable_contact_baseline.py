"""Review-only drink/eat reach adapted to real props; original clips untouched."""
from pathlib import Path
source=Path('tools/art/render_cast3d.py').read_text()
old='high = Vector((0.10,-0.025,mouth_z))'
new="high = Vector((0.17,-0.025,mouth_z - 0.07)) if name == 'drink' else (Vector((0.15,-0.025,mouth_z - 0.02)) if name == 'eat' else Vector((0.10,-0.025,mouth_z)))"
assert source.count(old)==1
exec(compile(source.replace(old,new),'tools/art/render_cast3d.py','exec'))
