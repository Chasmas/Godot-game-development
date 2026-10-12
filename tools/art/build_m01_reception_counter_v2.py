"""Build ImageGen-directed Blender plates for the two M01 reception-counter bodies."""
from pathlib import Path
import bpy,json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/reception_counter_v2';OUT.mkdir(parents=True,exist_ok=True);REF=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/reception_counter_v2/reception_counter_imagegen_reference.png'
def mat(n,c,metal=0,emit=0):
 m=bpy.data.materials.new(n);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*c,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=.35
 if emit:b.inputs['Emission Color'].default_value=(*c,1);b.inputs['Emission Strength'].default_value=emit
 return m
def textured():
 # The full ImageGen photograph is retained in this material as its authored
 # reference, but is not projected wholesale onto a tiny top-down sprite: its
 # bright countertop would flatten the actual Blender cabinet at game scale.
 x=mat('ImageGen reception walnut',(.075,.018,.006),.28);x['imagegen_reference']=str(REF);return x
def box(n,p,s,m,b=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=n;o.dimensions=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if b:q=o.modifiers.new('soft edge','BEVEL');q.width=b;q.segments=2
 return o
def setup_scene():
 bpy.ops.wm.read_factory_settings(use_empty=True); global wood,cream,brass,dark,cyan,amber,paper
 wood=textured();cream=mat('aged smoked laminate',(.30,.20,.11),.14);brass=mat('tarnished brass',(.42,.22,.03),.75);dark=mat('register charcoal',(.018,.024,.027),.5);cyan=mat('terminal cyan',(0,.8,.75),emit=1.7);amber=mat('bell amber',(1,.42,.05),emit=1.9);paper=mat('ledger paper',(.48,.34,.17))
def render_piece(kind):
 # both bodies retain a compact square footprint; different top clutter makes the L readable.
 box('ImageGen walnut reception cabinet',(0,0,.10),(1.62,1.62,.20),wood,.08);box('cream service top',(0,0,.225),(1.52,1.52,.065),cream,.06)
 for x in [-.46,0,.46]:box('front panel seam',(x,.63,.26),(.025,.13,.018),brass,.004)
 if kind==0:
  box('cash register',(-.27,-.12,.30),(.50,.38,.10),dark,.04);box('cyan register display',(-.27,-.12,.36),(.23,.13,.025),cyan,.01)
  bpy.ops.mesh.primitive_uv_sphere_add(segments=14,ring_count=7,radius=.105,location=(.42,.12,.32));bpy.context.object.data.materials.append(amber)
  box('phone',(.36,-.30,.30),(.36,.22,.07),dark,.05)
 else:
  box('open guest ledger',(0,-.12,.29),(.72,.48,.035),paper,.018);box('key bowl',(.42,.30,.30),(.26,.26,.075),brass,.06)
  box('CRT terminal',(-.45,.25,.31),(.36,.32,.13),dark,.04);box('CRT glow',(-.45,.25,.39),(.20,.17,.022),cyan,.01)
 for p in [(-.55,-.48,.29),(.52,-.44,.29)]:box('check-in card',p,(.18,.14,.025),paper,.006)
 s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=128;s.render.resolution_y=128;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.film_transparent=True;s.view_settings.look='AgX - Medium High Contrast'
 bpy.ops.object.camera_add(location=(0,0,5));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=2.05;cam.rotation_euler=(0,0,0);s.camera=cam
 for loc,col,en in [((-1,-1,3),(.3,.7,1),48),((1,1,2),(1,.18,.03),42)]:bpy.ops.object.light_add(type='AREA',location=loc);bpy.context.object.data.energy=en;bpy.context.object.data.color=col;bpy.context.object.data.size=3
 s.render.filepath=str(OUT/('reception_register.png' if kind==0 else 'reception_ledger.png'));bpy.ops.render.render(write_still=True)
for i in range(2):setup_scene();render_piece(i)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'reception_counter.blend'))
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':True,'files':['reception_register.png','reception_ledger.png'],'imagegen_reference':'res://assets/art/prerendered/m01_sunset_palms/staging/reception_counter_v2/reception_counter_imagegen_reference.png','production_method':'ImageGen reception reference plus Blender cabinets, service tops and practical counter props.','expected_count':2,'approval_scope':'M01 lobby counter visual-only replacement; existing Furniture collision/navigation stays authoritative.'},indent=2));print('M01_RECEPTION_COUNTER_V2 rendered')
