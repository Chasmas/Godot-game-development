"""Technical animation-hook check, not a production cinematic or art approval."""
from pathlib import Path
import bpy,runpy,json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
for name in ['Character','Hair','Hands']:
 ob=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(ob)
bpy.ops.object.camera_add(location=(2,-8,4),rotation=(1.1,.05,.1))
cam=bpy.context.object;cam.data.lens=45;bpy.context.scene.camera=cam
initial=cam.location.copy();rotation=cam.rotation_euler.copy()
preset=runpy.run_path(str(ROOT/'tools/blender/animate_cutscene_preset.py'))
preset['key'](cam.data,'lens',1,45.0)
preset['main']()
sc=bpy.context.scene;sc.frame_set(1)
assert (cam.location-initial).length < 1e-5 and (Vector(cam.rotation_euler)-Vector(rotation)).length < 1e-5
assert cam.data.lens == 45
sc.frame_set(24)
assert bpy.data.objects['Character'].location.z > .03
assert bpy.data.objects['Hands'].location.z > .015
sc.frame_set(48)
assert bpy.data.objects['Character'].location.length < 1e-5
assert bpy.data.objects['Hands'].location.length < 1e-5
assert (Vector(cam.rotation_euler)-Vector(rotation)).length < 1e-5
out=ROOT/'build/cutscene_preset_review';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'technical_hooks.blend'))
(out/'audit.json').write_text(json.dumps({'passed':True,'engine':sc.render.engine,'camera_initial_preserved':True,'camera_lens_preserved':True,'body_and_hands_return_to_rest':True,'scope':'Technical named-object hook test only; no rendered character acting or finished cinematic'},indent=2))
print('CUTSCENE PRESET REVIEW: passed')
