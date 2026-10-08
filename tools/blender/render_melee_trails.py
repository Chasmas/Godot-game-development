"""Author transparent melee ribbon candidates in Blender; no runtime approval."""
import bpy, math, json
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT / "build/melee_trail_review"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.engine="BLENDER_EEVEE"
scene.render.resolution_x=scene.render.resolution_y=256
scene.render.resolution_percentage=100
scene.render.film_transparent=True
scene.render.image_settings.file_format="PNG"
scene.render.image_settings.color_mode="RGBA"
scene.view_settings.view_transform="Standard"
bpy.ops.object.camera_add(location=(0,-4*math.cos(math.radians(50)),4*math.sin(math.radians(50))))
scene.camera=bpy.context.object
scene.camera.rotation_euler=(-scene.camera.location).to_track_quat("-Z","Y").to_euler()
scene.camera.data.type="ORTHO"
scene.camera.data.ortho_scale=2.4
materials=[]
for name, color, opacity in [("Soft silver body",(.65,.82,.95),.55),("Bright leading edge",(.9,.98,1),.9),("Detached fine filament",(.55,.75,.9),.5)]:
    m=bpy.data.materials.new(name);m.use_nodes=True
    n=m.node_tree.nodes;n.clear()
    out=n.new("ShaderNodeOutputMaterial")
    mix=n.new("ShaderNodeMixShader");mix.inputs[0].default_value=opacity
    transparent=n.new("ShaderNodeBsdfTransparent")
    emission=n.new("ShaderNodeEmission");emission.inputs[0].default_value=(*color,1)
    m.node_tree.links.new(transparent.outputs[0],mix.inputs[1])
    m.node_tree.links.new(emission.outputs[0],mix.inputs[2])
    m.node_tree.links.new(mix.outputs[0],out.inputs[0])
    materials.append(m)
def ribbon(name, centers, widths, material):
    vertices=[];faces=[]
    for i,p in enumerate(centers):
        before=centers[max(0,i-1)];after=centers[min(len(centers)-1,i+1)]
        dx,dy=after[0]-before[0],after[1]-before[1]
        length=max(math.hypot(dx,dy),1e-6)
        nx,ny=-dy/length,dx/length
        vertices.extend([(p[0]+nx*widths[i],p[1]+ny*widths[i],0),(p[0]-nx*widths[i],p[1]-ny*widths[i],0)])
        if i:faces.append((i*2-2,i*2-1,i*2+1,i*2))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);scene.collection.objects.link(obj);mesh.materials.append(material)
for kind in ["swing","thrust"]:
    folder=OUT/kind;folder.mkdir(exist_ok=True)
    for frame in range(8):
        for obj in list(bpy.data.objects):
            if obj.type=="MESH":bpy.data.objects.remove(obj,do_unlink=True)
        progress=frame/7
        envelope=math.sin(math.pi*(.08+.84*progress))
        for strand in range(3):
            centers=[];widths=[]
            for i in range(49):
                u=i/48
                if kind=="swing":
                    head=-1.2+2.25*progress
                    angle=head-(1-u)*(.45+.45*envelope)
                    radius=.78+strand*.035
                    x,y=radius*math.cos(angle),-radius*math.sin(angle)
                else:
                    x=.15+(.55+.36*progress)*u
                    y=(strand-1)*.022*math.sin(u*math.pi)+.01*math.sin(u*math.pi*2)
                centers.append((x,y))
                widths.append((.045 if strand==0 else .007)*math.sin(u*math.pi)**.8*envelope)
            ribbon(kind+str(strand),centers,widths,materials[strand])
        scene.render.filepath=str(folder/f"{frame:03}.png")
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(kind+".blend")))
(OUT/"review.json").write_text(json.dumps({"approved":False,"frames":8,"size":[256,256],"origin":"center","ortho_scale":2.4,"kinds":["swing","thrust"],"source":"Blender ribbons with soft silver body and fine detached filaments"},indent=2))
