"""Blender-authored folding chair; real geometry, worn vinyl and metal frame."""
import bpy, sys, os
from mathutils import Vector

out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, metal=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = 0.55
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 85
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.12
    bump.inputs["Distance"].default_value = 0.008
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    return mat

steel = material("Brushed dark steel", (0.22, 0.24, 0.28), 0.8)
vinyl = material("Oxblood worn vinyl", (0.22, 0.042, 0.028))
rubber = material("Rubber feet", (0.015, 0.012, 0.018))
seam = material("Vinyl seam piping", (0.09, 0.018, 0.012))

def tube(name, a, b, radius, mat):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=(b-a).length, location=(a+b)*0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Rounded tube ends", "BEVEL")
    bevel.width, bevel.segments = 0.002, 2

def pad(name, loc, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Soft upholstered edges", "BEVEL")
    bevel.width, bevel.segments = 0.016, 3

pad("Seat cushion", (0, 0, 0.46), (0.44, 0.43, 0.045), vinyl)
pad("Back cushion", (0, -0.235, 0.76), (0.43, 0.038, 0.25), vinyl)
pad("Seat piping", (0, 0, 0.439), (0.448, 0.438, 0.012), seam)
for side in (-1, 1):
    x = side * 0.245
    tube("Front leg and back upright", (x, 0.24, 0.025), (x, -0.25, 0.90), 0.015, steel)
    tube("Crossed rear leg", (x, -0.27, 0.025), (x, 0.20, 0.50), 0.015, steel)
    tube("Seat rail", (x, -0.22, 0.43), (x, 0.22, 0.43), 0.012, steel)
    tube("Hinge bolt", (x-side*0.018, -0.03, 0.45), (x+side*0.020, -0.03, 0.45), 0.025, steel)
    for y in (-0.27, 0.24):
        pad("Rubber foot cap", (x, y, 0.016), (0.043, 0.043, 0.032), rubber)
tube("Back upper rail", (-0.245, -0.25, 0.90), (0.245, -0.25, 0.90), 0.015, steel)
tube("Lower front brace", (-0.245, 0.12, 0.23), (0.245, 0.12, 0.23), 0.012, steel)
os.makedirs(os.path.dirname(out), exist_ok=True)
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
source = os.path.join(root, "assets", "art", "Artwork", "3d", "folding_chair", "scene.blend")
os.makedirs(os.path.dirname(source), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=source)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_apply=True, export_animations=False)
print("Folding chair exported:", out)
