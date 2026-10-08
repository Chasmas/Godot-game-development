"""Read-only check of saved Blender camera projection against runtime contracts."""
from pathlib import Path
import bpy,json,math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
STAGING=ROOT/'assets/art/prerendered/m01_sunset_palms/staging'
reviews=[]
for directory,blend in [('bed_family_v1','motel_bed.blend'),('nightstand_family_v1','nightstand.blend'),('tv_dresser_family_v1','tv_dresser.blend'),('rug_family_v1','motel_rug.blend')]:
 path=STAGING/directory
 bpy.ops.wm.open_mainfile(filepath=str(path/blend))
 bpy.context.view_layer.update()
 scene=bpy.context.scene
 point=world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
 resolution=[scene.render.resolution_x*scene.render.resolution_percentage/100,scene.render.resolution_y*scene.render.resolution_percentage/100]
 actual=[point.x*resolution[0],(1-point.y)*resolution[1]]
 contract=json.loads((path/'contract.json').read_text())
 frames=[]
 for frame in contract['frames']:
  recorded=frame['floor_anchor_px']
  error=math.dist(recorded,actual)
  frames.append({'file':frame['file'],'recorded_anchor':recorded,'saved_camera_anchor':actual,'error_pixels':error,'passed':error<.1})
 reviews.append({'family':directory,'resolution':resolution,'frames':frames,'passed':all(f['passed'] for f in frames)})
report={'read_only':True,'families':reviews,'passed':all(r['passed'] for r in reviews)}
(ROOT/'build/m01_family_anchor_audit.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
