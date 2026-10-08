import bpy,os,json
from mathutils import Vector
out=os.path.abspath('build/consumable_head_landmarks');os.makedirs(out,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.abspath('build/consumable_contact_isolated/guard.glb'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');head=arm.pose.bones.get('Head');p=arm.matrix_world@head.head
print('HEAD_METRES',tuple(p))

mat=arm.matrix_world@head.matrix
print('HEAD_AXES',*[tuple(mat.to_3x3().col[i].normalized()) for i in range(3)])
