"""Review wrist orientation on the upright guard dual hold."""
from pathlib import Path
source=Path('tools/art/render_cast3d.py').read_text()
source=source.replace('CALM = ("idle",','CALM = ("aim_dual", "idle",',1)
needle='            x, y = face_offset(x, y, theta)'
source=source.replace(needle,"""            if name == 'aim_dual':
                x,y,z = .32,(-.16 if right else .16),.22
"""+needle)
needle='        if bake_out:\n            # the visual pose'
assert source.count(needle)==1
source=source.replace(needle,"""        if name == 'aim_dual':
            # Bone Y runs along the fingers. Point it down the firing line,
            # keeping the hand plane level instead of inheriting IK wrist roll.
            world_basis = Matrix(((0,1,0),(-1,0,0),(0,0,1)))
            local_basis = arm.matrix_world.to_3x3().inverted() @ world_basis
            for side in ('Right','Left'):
                wrist = arm.pose.bones[side+'Hand']
                pose = wrist.matrix.copy()
                wrist.matrix = Matrix.LocRotScale(pose.translation,local_basis.to_quaternion(),pose.to_scale())
            bpy.context.view_layer.update()
"""+needle)
exec(compile(source,'tools/art/render_cast3d.py','exec'))
