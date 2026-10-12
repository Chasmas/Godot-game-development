"""Build a narrow high wall shelf with books and a flowering pot for M01 guest rooms."""
from pathlib import Path
import bpy, json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/guest_wall_shelf_v1'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,c,metal=0.0,emit=0.0):
    m=bpy.data.materials.new(name);m.use_nodes=True;b=m.node_tree.nodes.get('Principled BSDF')
    b.inputs['Base Color'].default_value=(*c,1);b.inputs['Metallic'].default_value=metal;b.inputs['Roughness'].default_value=.5
    if emit:b.inputs['Emission Color'].default_value=(*c,1);b.inputs['Emission Strength'].default_value=emit
    return m
walnut=mat('weathered walnut',(.13,.035,.018)); edge=mat('brass edge',(.52,.19,.04),.6); bookcols=[mat('book coral',(.48,.025,.04)),mat('book teal',(.015,.22,.25)),mat('book gold',(.48,.22,.025)),mat('book cream',(.65,.48,.22))]; leaf=mat('flower leaves',(.025,.25,.10)); flower=mat('coral flowers',(1,.04,.18),emit=.15); pot=mat('ceramic pot',(.05,.32,.33),.25)
def cube(n,p,s,m,bevel=.0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=n;o.dimensions=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
    if bevel:mo=o.modifiers.new('edge softness','BEVEL');mo.width=bevel;mo.segments=2
    return o
# A shallow shelf on a wall plane, rendered from above.
cube('shelf board',(0,0,.08),(1.35,.18,.12),walnut,.025);cube('brass front',(0,-.105,.13),(1.38,.025,.055),edge,.008)
for i,x in enumerate([-.49,-.33,-.17,.0,.17]): cube('book %d'%i,(x,.0,.24),(.11,.12,.28+(i%2)*.06),bookcols[i%len(bookcols)],.012)
cube('plant pot',(.43,.0,.22),(.25,.19,.20),pot,.03)
for x,y in [(0.38,0),(0.46,.03),(.52,-.02),(.43,.08)]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.12, location=(x,y,.39));bpy.context.object.name='leaf';bpy.context.object.scale=(1,.65,.35);bpy.context.object.data.materials.append(leaf)
for x,y in [(.39,-.06),(.48,.06),(.54,-.04)]:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.04, location=(x,y,.48));bpy.context.object.name='flower';bpy.context.object.data.materials.append(flower)
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.render.resolution_x=192;s.render.resolution_y=96;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.film_transparent=True;s.view_settings.look='AgX - Medium High Contrast'
bpy.ops.object.camera_add(location=(0,0,5));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=1.7;cam.rotation_euler=(0,0,0);s.camera=cam
bpy.ops.object.light_add(type='AREA',location=(-1,-1,3));bpy.context.object.data.energy=120;bpy.context.object.data.color=(.25,.75,1);bpy.context.object.data.size=3
bpy.ops.object.light_add(type='AREA',location=(1,1,2));bpy.context.object.data.energy=80;bpy.context.object.data.color=(1,.15,.35);bpy.context.object.data.size=2
s.render.filepath=str(OUT/'guest_wall_shelf.png');bpy.ops.render.render(write_still=True);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'guest_wall_shelf.blend'))
(OUT/'contract.json').write_text(json.dumps({'runtime_approved':True,'file':'guest_wall_shelf.png','world_width_px':20.0,'max_placements':8,'approval_scope':'M01 guest-room visual-only high wall shelf; no collision, navigation, interaction or geometry changes.'},indent=2))
print('M01_GUEST_WALL_SHELF: rendered')
