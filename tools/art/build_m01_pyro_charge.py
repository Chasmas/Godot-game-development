"""Rebuild the M01 pyro-charge pickup/plant prop as a small Blender asset."""
from pathlib import Path
import bpy, json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/staging/pyro_charge_v1'; OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(n,c,metal=0,emit=0.0):
 m=bpy.data.materials.new(n); m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF')
 bs.inputs['Base Color'].default_value=(*c,1)
 bs.inputs['Metallic'].default_value=metal
 bs.inputs['Roughness'].default_value=.46
 if emit > 0.0:
  bs.inputs['Emission Color'].default_value=(*c,1); bs.inputs['Emission Strength'].default_value=emit
 m.diffuse_color=(*c,1); return m
canvas=mat('canvas',(.035,.028,.027)); red=mat('wrapped charges',(.55,.035,.02)); tape=mat('tape',(.35,.34,.3),.5); dark=mat('timer',(.015,.018,.022),.3); wire=mat('yellow wire',(.75,.42,.015),.25); led=mat('armed LED',(1,.02,.01),emit=3.0)
def box(n,p,s,m):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p); o=bpy.context.object;o.name=n;o.dimensions=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m);be=o.modifiers.new('soft edge','BEVEL');be.width=.025;be.segments=2;return o
box('canvas satchel',(0,0,.10),(1.0,.64,.20),canvas)
for x in (-.29,-.095,.095,.29): box('charge stick',(x,0,.25),(.15,.48,.16),red)
for x in (-.42,.0,.42): box('tape band',(x,0,.35),(.06,.56,.055),tape)
box('timer',(0,-.02,.40),(.26,.22,.13),dark); bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=.045, location=(.075,-.08,.475));bpy.context.object.data.materials.append(led)
for x in (-.18,.18): box('strap',(x,0,.43),(.07,.66,.045),canvas)
bpy.ops.curve.primitive_bezier_curve_add(); w=bpy.context.object;w.name='timer wire';w.data.bevel_depth=.018;w.data.materials.append(wire);w.data.splines[0].bezier_points[0].co=(-.02,-.08,.46);w.data.splines[0].bezier_points[1].co=(.22,.12,.45)
s=bpy.context.scene;s['imagegen_reference']='assets/art/reference/m01_pyro_charge_v1/concept.png';s['runtime_approved']=False
bpy.ops.object.camera_add(location=(0,0,5));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=1.25;cam.rotation_euler=(0,0,0);s.camera=cam
s.render.engine='BLENDER_EEVEE';s.render.resolution_x=256;s.render.resolution_y=256;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.film_transparent=True;s.world=bpy.data.worlds.new('world');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.003,.004,.008,1);s.view_settings.look='AgX - Medium High Contrast'
bpy.ops.object.light_add(type='AREA',location=(-1,-1,3));bpy.context.object.data.energy=140;bpy.context.object.data.color=(.2,.8,1);bpy.context.object.data.size=3
bpy.ops.object.light_add(type='AREA',location=(1,1,2));bpy.context.object.data.energy=95;bpy.context.object.data.color=(1,.05,.3);bpy.context.object.data.size=2
s.render.filepath=str(OUT/'pyro_charge_topdown.png');bpy.ops.render.render(write_still=True);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'pyro_charge.blend'))
(OUT/'contract.json').write_text(json.dumps({'reference':'assets/art/reference/m01_pyro_charge_v1/concept.png','image':'pyro_charge_topdown.png','runtime_approved':False,'states':['pickup','planted']},indent=2))
print('M01_PYRO_CHARGE: topdown prop rendered')

