"""Recompose guest101 at actual map dimensions; staging only."""
from pathlib import Path
import bpy,json,math,sys
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).parent))
from m01_imagegen_materials import apply_reviewed_source
BASE=ROOT/'assets/art/prerendered/m01_sunset_palms/staging'
OUT=BASE/'room_101_v19';OUT.mkdir(parents=True,exist_ok=True)
layout=json.loads((ROOT/'build/m01_room_101_rebuild_layout.json').read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
def mat(name,key):
    m=bpy.data.materials.new(name);m.use_nodes=True;apply_reviewed_source(m,key);return m
carpet=mat('101 reviewed carpet','carpet');plaster=mat('101 ivory plaster','ivory_plaster');wood=mat('101 walnut','walnut')
def box(name,pos,size,material):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    bevel=o.modifiers.new('Soft physical edges','BEVEL');bevel.width=.015;bevel.segments=2
    return o
def asset(path,centre,angle=0,fit=None,select_root=None):
    with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=src.objects
    imported=[o for o in dst.objects if o and o.type not in {'CAMERA','LIGHT'}]
    if select_root:
        selected=next(o for o in imported if o.name.startswith(select_root) and not o.hide_render and abs(o.rotation_euler.z)<.001)
        imported=[selected]+list(selected.children_recursive)
        for o in imported:
            o.hide_render=False
            if o.type not in {'MESH','CURVE'}:continue
            for material in o.data.materials:
                if not material or not material.use_nodes:continue
                image=next((n for n in material.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'armchair_sage_fabric' in n.image.name),None)
                if image:
                    image['m01_reviewed_source']=True
                    material['imagegen_source']='assets/art/materials/m01/batch_v1/armchair_sage_fabric_albedo_v1.png'
                    material['repeat_metres']=.5
    root=bpy.data.objects.new(path.stem+'101 placement',None);bpy.context.collection.objects.link(root)
    for o in imported:
        bpy.context.collection.objects.link(o)
        if o.parent not in imported:o.parent=root
    bpy.context.view_layer.update()
    if path.stem=='tv_dresser':
        glass=next(o for o in imported if o.name.startswith('Convex dark CRT'))
        screen=bpy.data.materials.new('101 quiet analog CRT screen');screen.use_nodes=True
        nodes=screen.node_tree.nodes;principled=nodes['Principled BSDF']
        texture=nodes.new('ShaderNodeTexImage')
        texture.image=bpy.data.images.load(str(ROOT/'assets/art/shots/tv_news/bg.png'))
        screen.node_tree.links.new(texture.outputs['Color'],principled.inputs['Base Color'])
        screen.node_tree.links.new(texture.outputs['Color'],principled.inputs['Emission Color'])
        principled.inputs['Emission Strength'].default_value=.8
        principled.inputs['Roughness'].default_value=.18
        glass.data=glass.data.copy();slot=len(glass.data.materials);glass.data.materials.append(screen)
        uv=glass.data.uv_layers.active
        for face in glass.data.polygons:
            if face.normal.y>-.5:continue
            face.material_index=slot
            for loop in face.loop_indices:
                p=glass.data.vertices[glass.data.loops[loop].vertex_index].co
                uv.data[loop].uv=(p.x/.48+.5,p.z/.295+.5)
        # Turn only the television toward the bed/east side. The cabinet and
        # drawer fronts retain their authored orientation and floor footprint.
        pivot=Vector((-.15,.035,0))
        turn=Matrix.Identity(4)
        for o in imported:
            if o.type=='MESH' and o.name.startswith(('CRT ','Rounded CRT','Recessed black bezel','Convex dark CRT','Speaker grille','Small channel','Back ventilation')):
                o.matrix_world=turn@o.matrix_world
        bpy.context.view_layer.update()
    root.rotation_euler.z=angle;bpy.context.view_layer.update()
    def bounds():
        if select_root:
            points=[];deps=bpy.context.evaluated_depsgraph_get()
            for o in imported:
                if o.type!='MESH':continue
                evaluated=o.evaluated_get(deps);mesh=evaluated.to_mesh()
                points.extend(evaluated.matrix_world@v.co for v in mesh.vertices)
                evaluated.to_mesh_clear()
        else:
            points=[o.matrix_world@Vector(c) for o in imported if o.type=='MESH' for c in o.bound_box]
        return Vector([min(p[i] for p in points) for i in range(3)]),Vector([max(p[i] for p in points) for i in range(3)])
    low,high=bounds()
    if fit:
        scale=min(fit[0]/(high.x-low.x),fit[1]/(high.y-low.y))
        root.scale*=scale;bpy.context.view_layer.update();low,high=bounds()
    root.location=Vector(centre)-Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    return root
# Local map X/Y becomes Blender X/-Y. Openings remain actual authored cells.
box('101 floor',(4,-2,-.06),(8,4,.12),carpet)
box('101 north wall',(4,.08,1.2),(8.16,.16,2.4),plaster)
box('101 west wall',(-.08,-2,1.2),(.16,4,2.4),plaster)
# East connecting door spans local map y1..3.
for y in [.5,3.5]:box('101 east wall',(8.08,-y,1.2),(.16,1,2.4),plaster)
# South wall: windows x0..2, main door x3..5.
for x,width in [(2.5,1),(6.5,3)]:box('101 south wall',(x,-4.08,1.2),(width,.16,2.4),plaster)
box('101 window sill',(1,-4.08,.42),(2,.20,.12),wood)
box('101 wall below window',(1,-4.08,.18),(2,.16,.36),plaster)
box('101 wall above window',(1,-4.08,2.15),(2,.16,.5),plaster)
for x in [0,2]:box('101 window vertical frame',(x,-4.08,1.2),(.06,.12,1.5),wood)
for z in [.48,1.92]:box('101 window horizontal frame',(1,-4.08,z),(2,.12,.06),wood)
curtain_material=mat('101 curtain woven cloth','towel')
curtain_material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.16,.25,.19,1)
def curtain(name,x0,x1,tied=False):
    vertices=[];faces=[];columns=48;rows=10
    for row in range(rows+1):
        v=row/rows
        for column in range(columns+1):
            u=column/columns
            gather=math.exp(-((v-.40)/.20)**2) if tied else 0
            left=x0+.055*gather
            vertices.append((left+(x1-left)*u,-3.965+.035*math.sin(u*math.pi*12)*(0.7+v*.3),.52+v*1.42+.012*math.cos(u*math.pi*12)*(1-v)))
    for row in range(rows):
        for column in range(columns):
            i=row*(columns+1)+column;faces.append((i,i+1,i+columns+2,i+columns+1))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(curtain_material)
    for face in mesh.polygons:face.use_smooth=True
    o.modifiers.new('Curtain fabric thickness','SOLIDIFY').thickness=.008
curtain('101 left gathered curtain',.02,.38)
curtain('101 right gathered curtain',1.86,1.98,True)
box('101 curtain fabric tieback',(1.94,-3.91,1.08),(.10,.025,.04),curtain_material)
box('101 curtain rail',(1,-3.94,2.02),(2.08,.035,.035),wood)
for x in [.06,.18,.30,1.88,1.92,1.96]:
    bpy.ops.mesh.primitive_torus_add(major_radius=.032,minor_radius=.006,major_segments=12,minor_segments=6,location=(x,-3.94,2.0),rotation=(0,math.pi/2,0))
    bpy.context.object.name='101 curtain brass ring';bpy.context.object.data.materials.append(wood)
appliance=bpy.data.materials.new('101 aged PTAC enamel');appliance.diffuse_color=(.50,.51,.44,1)
box('101 low PTAC casing',(.70,-3.94,.25),(1.1,.22,.30),appliance)
for x in [.25,.35,.45,.55,.65,.75,.85,.95,1.05,1.15]:box('101 PTAC vent',(x,-3.81,.27),(.045,.015,.14),wood)
box('101 window meeting stile',(1,-4.075,1.2),(.045,.13,1.44),wood)
for x in [3,5]:box('101 entrance jamb',(x,-4.08,1.1),(.08,.20,2.2),wood)
box('101 entrance lintel',(4,-4.08,2.2),(2.08,.20,.10),wood)
asset(BASE/'bed_family_v1/motel_bed.blend',(6,-2,0),fit=(2,2))
chair_contract=json.loads((ROOT/'assets/art/prerendered/m01_sunset_palms/runtime/armchair_v1/runtime_contract.json').read_text())
chair_offset=chair_contract['collision_center_metres'][1]
asset(BASE/'armchair_runtime_v3/armchair_runtime_review.blend',(1.5,-2.5,0),math.pi,fit=(.73,.68),select_root='M01 upholstered armchair')
tv=asset(BASE/'tv_dresser_family_v1/tv_dresser.blend',(1.5,-.5,.28),0,fit=(.8,.7))
# Restore useful cabinet height after footprint fitting; all pieces stay inside
# the already reviewed TV floor silhouette. Keep them in the placement audit.
extensions=[box('101 TV lower walnut cabinet',(1.5,-.5,.18),(.78,.245,.20),wood)]
for x in [1.15,1.85]:
    for y in [-.60,-.40]:extensions.append(box('101 TV cabinet foot',(x,y,.04),(.045,.045,.08),wood))
extensions.append(box('101 TV lower drawer face',(1.5,-.623,.18),(.70,.01,.14),wood))
extensions.append(box('101 TV drawer pull',(1.5,-.627,.20),(.18,.01,.015),appliance))
bpy.context.view_layer.update()
for piece in extensions:
    transform=piece.matrix_world.copy();piece.parent=tv;piece.matrix_world=transform
asset(BASE/'nightstand_family_v1/nightstand.blend',(3.375,-.5,0),fit=(.65,.5))
asset(BASE/'nightstand_family_v1/nightstand.blend',(2.375,-3.5,0),fit=(.65,.5))
# Finish wall surfaces without placing new blockers in adjoining-door lanes.
for name,pos,size in [('north skirting',(4,-.02,.10),(8,.055,.20)),('west skirting',(.02,-2,.10),(.055,4,.20)),('north picture rail left',(2.655,-.02,1.72),(5.31,.04,.055)),('north picture rail right',(7.345,-.02,1.72),(1.31,.04,.055))]:box('101 '+name,pos,size,wood)
paper=bpy.data.materials.new('101 cream paper');paper.diffuse_color=(.73,.67,.52,1)
art=box('101 botanical lithograph',(6,-.025,1.65),(1.25,.02,.56),paper)
art_material=bpy.data.materials.new('101 botanical image');art_material.use_nodes=True
image=art_material.node_tree.nodes.new('ShaderNodeTexImage')
image.image=bpy.data.images.load(str(ROOT/'assets/art/materials/m01/batch_v1/guest_room_botanical_lithograph_v1.png'))
art_material.node_tree.links.new(image.outputs['Color'],art_material.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
art.data.materials.clear();art.data.materials.append(art_material)
# Project the image onto the front face, rather than default cube unwrap.
uv=art.data.uv_layers.active
for face in art.data.polygons:
    for loop in face.loop_indices:
        p=art.data.vertices[art.data.loops[loop].vertex_index].co
        uv.data[loop].uv=(p.x/1.25+.5,p.z/.56+.5)
for x in [5.34,6.66]:box('101 art frame',(x,-.045,1.65),(.06,.045,.65),wood)
for z in [1.34,1.96]:box('101 art frame',(6,-.045,z),(1.38,.045,.06),wood)
box('101 folded guest towel',(6.25,-2.65,.65),(.48,.30,.055),mat('101 towel','towel'))
box('101 room service tray',(2.5,-.35,.12),(.48,.32,.10),wood)
box('101 folded room service receipt',(2.48,-.35,.18),(.17,.13,.01),paper)
light=bpy.data.lights.new('101 bedside bulb','POINT');light.energy=25;light.color=(1,.65,.32);light.shadow_soft_size=.09
bulb=bpy.data.objects.new(light.name,light);bpy.context.collection.objects.link(bulb);bulb.location=(3.375,-.5,1.05)
second=bpy.data.objects.new('101 lower cabinet bulb',light.copy());bpy.context.collection.objects.link(second);second.location=(2.375,-3.5,1.05)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('101 night');scene.world.color=(.04,.04,.07)
for name,pos,power,color,size in [('warm practical',(5,-.5,3),180,(1,.68,.40),3),('window fill',(1,-5,2),110,(.2,.5,1),2),('soft room fill',(3,-2,5),130,(.75,.82,1),5)]:
    light=bpy.data.lights.new(name,'AREA');light.energy=power;light.color=color;light.size=size
    o=bpy.data.objects.new(name,light);bpy.context.collection.objects.link(o);o.location=pos
    o.rotation_euler=(Vector((4,-2,0))-o.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.objects.new('101 review camera',bpy.data.cameras.new('101 review camera'))
bpy.context.collection.objects.link(camera);camera.location=(8,-10,11)
camera.rotation_euler=(Vector((4,-2,.4))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=11;scene.camera=camera
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'room_101.blend'))
scene.render.filepath=str(OUT/'room_101.png');bpy.ops.render.render(write_still=True)
# Review cutaway only: source blend and future collisions retain full walls.
for o in scene.objects:
    if o.name.startswith(('101 south wall','101 wall above window','101 entrance lintel')):o.hide_render=True
scene.render.filepath=str(OUT/'room_101_cutaway.png');bpy.ops.render.render(write_still=True)
(OUT/'review.json').write_text(json.dumps({'runtime_approved':False,'map_sha256':layout['map_sha256'],'floor_metres':[8,4],'pending':['Final reference-quality dressing','Door/window actors and sightline validation','Production camera and layout integration']},indent=2))
print('M01 ROOM101 BUILT')
