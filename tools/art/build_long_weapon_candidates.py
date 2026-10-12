"""Blender fit studies with independent trigger, support, shoulder and muzzle anchors.
These are staged geometry for animation fitting, never automatic runtime replacements.
"""
import bpy, math, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def mat(name,color,metal=0,rough=.5):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
for identity,length,stock_length,support in [('shotgun',.97,.29,.27),('rifle',.83,.25,.23),('smg',.53,.18,.14)]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    out=ROOT/'assets/art/weapons3d/staging'/f'{identity}_fit_v1';out.mkdir(parents=True,exist_ok=True)
    steel=mat('Blued steel',(.14,.17,.20),.55,.4)
    polymer=mat('Grip polymer',(.045,.052,.057),0,.75)
    wood=mat('Oiled walnut',(.15,.065,.03),0,.56)
    root=bpy.data.objects.new(identity,None);bpy.context.collection.objects.link(root)
    def box(name,pos,size,material):
        bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
        o=bpy.context.object;o.name=name;o.dimensions=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        o.parent=root;o.data.materials.append(material)
        b=o.modifiers.new('Rounded machined edges','BEVEL');b.width=.003;b.segments=3
        return o
    muzzle=-(length-stock_length)
    box('Receiver',(0,-.06,.055),(.042,.17,.065),steel)
    box('Trigger grip',(0,.015,-.012),(.031,.042,.10),wood if identity=='shotgun' else polymer).rotation_euler.x=math.radians(-15)
    box('Stock',(0,stock_length*.5,.04),(.045,stock_length,.095),wood if identity=='shotgun' else polymer)
    box('Shoulder butt pad',(0,stock_length,.04),(.05,.012,.11),polymer)
    box('Support foreend',(0,-support,.045),(.046,.17 if identity=='shotgun' else .14,.054),wood if identity=='shotgun' else polymer)
    box('Trigger guard lower',(0,-.022,-.02),(.014,.075,.006),steel)
    box('Trigger guard front',(0,-.059,.0),(.014,.007,.044),steel)
    if identity!='shotgun':
        box('Magazine',(0,-.105,-.045),(.026,.055,.15),polymer)
    # Open annulus with an internal bore rather than a capped cylinder.
    start=-.14;radius=.012 if identity=='shotgun' else .009;inner=radius*.65
    vertices=[]
    for y,r in [(start,radius),(muzzle,radius),(muzzle,inner),(muzzle+.025,inner)]:
        for i in range(24):
            a=i*math.tau/24;vertices.append((math.cos(a)*r,y,.064+math.sin(a)*r))
    faces=[]
    for ring in range(3):
        for i in range(24):faces.append((ring*24+i,ring*24+(i+1)%24,(ring+1)*24+(i+1)%24,(ring+1)*24+i))
    mesh=bpy.data.meshes.new('Open barrel');mesh.from_pydata(vertices,[],faces);mesh.update()
    o=bpy.data.objects.new('Open barrel',mesh);bpy.context.collection.objects.link(o);o.parent=root;o.data.materials.append(steel)
    box('Front sight',(0,muzzle+.035,.084),(.005,.012,.016),steel)
    anchors={'GripAnchor':(0,.015,0),'SupportGrip':(0,-support,.02),'SupportRearGrip':(0,-support+.06,.02),'ShoulderAnchor':(0,stock_length+.006,.04),'Muzzle':(0,muzzle,.064)}
    for name,pos in anchors.items():
        o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=root;o.location=pos
    bpy.ops.wm.save_as_mainfile(filepath=str(out/f'{identity}.blend'))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(out/f'{identity}.glb'),export_format='GLB',export_apply=True)
    (out/'contract.json').write_text(json.dumps({'runtime_approved':False,'weapon':identity,'units':'metres','forward_blender':'-Y','anchors_blender':anchors,'overall_length_m':length,'pending':['authored finish','hand mesh contact','shoulder contact','all gait and aim reviews','firing origin']},indent=2))
    print('LONG WEAPON FIT BUILT',identity)
