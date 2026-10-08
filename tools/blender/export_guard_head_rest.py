import bpy,json,os
bpy.ops.wm.open_mainfile(filepath=os.path.abspath('build/consumable_head_landmarks/landmark_review.blend'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
m=arm.matrix_world@arm.data.bones['Head'].matrix_local
json.dump([list(row) for row in m],open('build/consumable_head_landmarks/head_rest_blender.json','w'))
