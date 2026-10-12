"""Deterministic physical dressing for the M01 guest-room staging composition."""
import math
from pathlib import Path
import bpy
from mathutils import Vector


def dress_room(box, wood, textured):
    def solid(name, color, roughness=.7, metallic=0):
        mat=bpy.data.materials.new(name);mat.use_nodes=True
        shader=mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value=(*color,1)
        shader.inputs['Roughness'].default_value=roughness
        shader.inputs['Metallic'].default_value=metallic
        return mat

    leaf=solid('Muted botanical green',(.12,.22,.075))
    paper=solid('Warm paper',(.72,.64,.43))
    clay=solid('Worn terracotta',(.3,.12,.055))
    leather=solid('Guest suitcase brown leather',(.12,.065,.035))
    brass=solid('Aged luggage brass',(.42,.28,.10),.35,.7)
    cloth=textured('Folded towel fabric','towel')

    def image_material(name, image_path):
        mat=bpy.data.materials.new(name);mat.use_nodes=True
        nodes=mat.node_tree.nodes;links=mat.node_tree.links
        shader=nodes.get('Principled BSDF')
        image=nodes.new('ShaderNodeTexImage')
        image.image=bpy.data.images.load(str(image_path),check_existing=True)
        image.interpolation='Linear';image.extension='CLIP'
        links.new(image.outputs['Color'],shader.inputs['Base Color'])
        shader.inputs['Roughness'].default_value=.82
        return mat

    def cylinder(name,pos,radius,depth,mat):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=depth,location=pos)
        obj=bpy.context.object;obj.name=name;obj.data.materials.append(mat)
        bevel=obj.modifiers.new('Rounded rim','BEVEL');bevel.width=.008;bevel.segments=3
        return obj

    def stem(name,points,radius,mat):
        curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D'
        curve.bevel_depth=radius;curve.bevel_resolution=3
        spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
        for p,co in zip(spline.points,points):p.co=(*co,1)
        obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj)
        obj.data.materials.append(mat)

    def plant(x,y,z,scale):
        cylinder('Terracotta plant pot',(x,y,z+.12*scale),.16*scale,.24*scale,clay)
        for i in range(11):
            a=i*2.39996;h=(.36+.045*(i%5))*scale
            start=Vector((x,y,z+.23*scale))
            tip=start+Vector((math.cos(a)*.28*scale,math.sin(a)*.28*scale,h))
            stem('Arched plant stem',[start,start.lerp(tip,.55)+Vector((0,0,.1*scale)),tip],.008*scale,leaf)
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,location=tip)
            o=bpy.context.object;o.name='Lanceolate plant leaf'
            o.scale=(.045*scale,.16*scale,.014*scale);o.rotation_euler.z=a-math.pi/2
            o.data.materials.append(leaf)

    # Original ImageGen artwork is framed as an in-world print, not used as level geometry.
    box('Botanical walnut frame',(-.6,2.48,1.85),(1.35,.055,.66),wood)
    art=box('Original botanical palm lithograph',(-.6,2.445,1.85),(1.22,.014,.53),paper)
    asset=Path(__file__).resolve().parents[2]/'assets/art/materials/m01/batch_v1/guest_room_botanical_lithograph_v1.png'
    art.data.materials.clear();art.data.materials.append(image_material('Original botanical palm lithograph material',asset))
    art['source']='ImageGen original generated 2026-10-08; game dressing asset'

    cylinder('Reading table top',(-2.02,-1.72,.55),.28,.055,wood)
    for a in (0,2.094,4.189):
        cylinder('Reading table leg',(-2.02+math.cos(a)*.19,-1.72+math.sin(a)*.19,.27),.025,.54,wood)
    book=box('Guest paperback',(-2.02,-1.72,.593),(.20,.14,.026),leaf);book.rotation_euler.z=.2
    box('Paperback page block',(-2.02,-1.72,.596),(.185,.13,.017),paper)
    plant(2.20,1.92,0,1.1)
    plant(-2.32,1.19,0,.8)
    # Luggage stays outside the bed-to-TV route.
    box('Guest suitcase body',(2.02,-1.43,.22),(.67,.43,.21),leather)
    box('Suitcase lid seam',(2.02,-1.43,.326),(.68,.44,.025),wood)
    for x in (1.79,2.25):
        box('Suitcase strap',(x,-1.43,.35),(.045,.45,.02),leather)
        box('Suitcase brass clasp',(x,-1.656,.30),(.055,.022,.05),brass)
    stem('Suitcase carry handle',[(1.92,-1.67,.24),(1.92,-1.70,.29),(2.12,-1.70,.29),(2.12,-1.67,.24)],.014,leather)
    # Dense draped mesh makes visible soft folds instead of a bevelled slab.
    verts=[];faces=[];nx=64;ny=28
    for j in range(ny+1):
        v=j/ny
        for i in range(nx+1):
            u=i/nx;x=-1.45+u*1.70;y=.34+v*.44
            edge=max(0,(abs(u-.5)-.40)/.10)
            z=.705-.27*edge+.012*math.sin(u*math.pi*15)+.005*math.sin(v*math.pi*6+u*11)
            verts.append((x,y,z))
    for j in range(ny):
        for i in range(nx):
            k=j*(nx+1)+i;faces.append((k,k+1,k+nx+2,k+nx+1))
    mesh=bpy.data.meshes.new('Folded textile mesh');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Folded guest blanket with hanging edges',mesh)
    bpy.context.collection.objects.link(obj);obj.data.materials.append(cloth)
    for polygon in mesh.polygons:polygon.use_smooth=True
    obj.modifiers.new('Textile thickness','SOLIDIFY').thickness=.004
    # Replace the staging bed's rigid cover with a continuous draped surface.
    cover=next(o for o in bpy.context.scene.objects if o.name.startswith('Bedspread with rounded'))
    cover.hide_render=True
    for o in bpy.context.scene.objects:
        if o.name.startswith('Sewn bedspread perimeter'):o.hide_render=True
    verts=[];faces=[];nx=100;ny=80
    for j in range(ny+1):
        sy=-1.30+j/ny*1.82
        for i in range(nx+1):
            sx=-1.05+i/nx*2.10
            side=max(0,abs(sx)-.76);foot=max(0,-sy-.99)
            x=-.6+max(-.78,min(.78,sx));y=1.28+max(-1.02,sy)
            hem=max(side,foot)
            x+=math.copysign(.02*math.sin(sy*34)*min(1,side*12),sx)
            y-=.014*math.sin(sx*38)*min(1,foot*12)
            wave=.010*math.sin(sx*20+sy*5)+.007*math.sin(sy*29+sx*8)
            z=.65-hem+wave
            verts.append((x,y,z))
    for j in range(ny):
        for i in range(nx):
            k=j*(nx+1)+i;faces.append((k,k+1,k+nx+2,k+nx+1))
    mesh=bpy.data.meshes.new('Continuous bedspread drape');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Authored bedspread folds and hanging skirt',mesh)
    bpy.context.collection.objects.link(obj);obj.data.materials.append(cover.data.materials[0])
    for polygon in mesh.polygons:polygon.use_smooth=True
    obj.modifiers.new('Bedspread fabric thickness','SOLIDIFY').thickness=.004
    # Geometric creases use authored noise, never colour-to-height conversion.
    for pillow in [o for o in bpy.context.scene.objects if o.name.startswith('Soft ivory pillow')]:
        sub=pillow.modifiers.new('Pillow cloth subdivision','SUBSURF');sub.levels=3
        tex=bpy.data.textures.new(pillow.name+' broad cloth creases',type='CLOUDS')
        tex.noise_scale=.12;tex.noise_depth=1
        crease=pillow.modifiers.new('Soft pillow compression','DISPLACE')
        crease.texture=tex;crease.strength=.012;crease.mid_level=.5
