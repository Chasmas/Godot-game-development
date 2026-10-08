"""Reuse the detailed handheld can as a grounded horizontal prop."""
import bpy,math
from pathlib import Path
from mathutils import Matrix,Vector
bpy.ops.wm.open_mainfile(filepath=str(Path('build/idle_consumables_candidate/can.blend').resolve()))
transform=Matrix.Rotation(math.pi/2,4,'Y')
transform.translation=Vector((-.0575,0,.0325))
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.context.scene.objects:
 if obj.type not in {'MESH','CURVE','FONT'}:continue
 obj.matrix_world=transform@obj.matrix_world
 obj.select_set(True)
out=Path('build/idle_consumables_candidate/idle_can_floor.glb').resolve()
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_animations=False,use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out.with_suffix('.blend')))
