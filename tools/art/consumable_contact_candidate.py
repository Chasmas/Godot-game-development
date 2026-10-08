"""Review-only drink/eat reach adapted to real props; original clips untouched."""
from pathlib import Path
source=Path('tools/art/render_cast3d.py').read_text()
old='high = Vector((0.10,-0.025,mouth_z))'
new="high = Vector((0.13769,-0.01947,mouth_z - 0.00712)) if name == 'drink' else (Vector((0.11149,-0.01877,mouth_z - 0.04267)) if name == 'eat' else Vector((0.10,-0.025,mouth_z)))"
assert source.count(old)==1
exec(compile(source.replace(old,new),'tools/art/render_cast3d.py','exec'))
