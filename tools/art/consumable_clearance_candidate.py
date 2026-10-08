"""Carry the can outside the thigh and torso during raise and recovery."""
from pathlib import Path
source=Path('tools/art/render_cast3d.py').read_text()
source=source.replace('high = Vector((0.10,-0.025,mouth_z))','high = Vector((0.153843,0.013195,mouth_z-0.036045))')
old='x,y,z = low.lerp(high,lift) if right else low'
new="""if name == 'drink' and right:
                        low = Vector((0.16,-0.28,-0.10))
                        arc = low.lerp(high,lift) + Vector((0.10,-0.08,0))*math.sin(math.pi*lift)
                        x,y,z = arc
                    else:
                        x,y,z = low.lerp(high,lift) if right else low"""
assert source.count(old)==1
exec(compile(source.replace(old,new),'tools/art/render_cast3d.py','exec'))
