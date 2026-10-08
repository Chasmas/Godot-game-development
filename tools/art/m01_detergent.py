"""Authored non-emissive detergent packaging with an ImageGen paper label."""
import math
from pathlib import Path
import bpy

def material(name, color, roughness):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = roughness
    return m

def bottle(x, y, base, tint=(.74,.73,.62)):
    plastic = material('Detergent moulded plastic', tint, .48)
    cap = material('Detergent teal ribbed cap', (.025,.15,.16), .52)
    rings = [(0,.065),(.012,.085),(.035,.092),(.22,.092),(.26,.082),(.30,.04),(.33,.038)]
    vertices = [(x+radius*math.cos(i*math.tau/32), y+radius*.72*math.sin(i*math.tau/32), base+z) for z,radius in rings for i in range(32)]
    faces = [(r*32+i,r*32+(i+1)%32,(r+1)*32+(i+1)%32,(r+1)*32+i) for r in range(len(rings)-1) for i in range(32)]
    faces += [tuple(reversed(range(32))),tuple((len(rings)-1)*32+i for i in range(32))]
    mesh = bpy.data.meshes.new('Detergent shoulder profile')
    mesh.from_pydata(vertices,[],faces)
    mesh.materials.append(plastic)
    obj = bpy.data.objects.new('Palm Fresh bottle',mesh)
    bpy.context.collection.objects.link(obj)
    for poly in mesh.polygons: poly.use_smooth = len(poly.vertices)==4
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.045,depth=.055,location=(x,y,base+.35))
    bpy.context.object.data.materials.append(cap)
    for i in range(20):
        angle=i*math.tau/20
        bpy.ops.mesh.primitive_cube_add(size=1,location=(x+.045*math.cos(angle),y+.045*math.sin(angle),base+.35))
        rib=bpy.context.object
        rib.name='Cap grip rib'
        rib.scale=(.006,.006,.043)
        rib.data.materials.append(cap)
    label = material('Palm Fresh printed label', (1,1,1), .76)
    nodes=label.node_tree.nodes
    image=nodes.new('ShaderNodeTexImage')
    image.image=bpy.data.images.load(str(Path(__file__).resolve().parents[2]/'assets/art/materials/m01/palm_fresh_label_v1.png'),check_existing=True)
    label.node_tree.links.new(image.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    # Flat label follows the front face; distinct UVs retain the entire design.
    me=bpy.data.meshes.new('Detergent label mesh')
    me.from_pydata([(x-.058,y-.067,base+.05),(x+.058,y-.067,base+.05),(x+.058,y-.067,base+.23),(x-.058,y-.067,base+.23)],[],[(0,1,2,3)])
    uv=me.uv_layers.new()
    for loop,coord in zip(uv.data,[(0,0),(1,0),(1,1),(0,1)]): loop.uv=coord
    me.materials.append(label)
    ob=bpy.data.objects.new('Palm Fresh paper label',me)
    bpy.context.collection.objects.link(ob)
    return obj
