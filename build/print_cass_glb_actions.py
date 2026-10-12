import bpy
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=r'C:\Users\Gil\Documents\GitHub\Hotshot-California\assets\art\cast3d_rt\cass\cass.glb')
print([(a.name, round(a.frame_range[0]), round(a.frame_range[1])) for a in bpy.data.actions])
