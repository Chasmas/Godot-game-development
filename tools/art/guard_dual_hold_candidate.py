"""Guard dual-pistol hold: upright rest body, matched chest-level wrists."""
from pathlib import Path
source=Path('tools/art/render_cast3d.py').read_text()
source=source.replace('CALM = ("idle",','CALM = ("aim_dual", "idle",',1)
needle='            x, y = face_offset(x, y, theta)'
assert source.count(needle)==1
source=source.replace(needle,"""            if name == 'aim_dual':
                x,y,z = .32,(-.16 if right else .16),.22
"""+needle)
exec(compile(source,'tools/art/render_cast3d.py','exec'))
