"""Render spent brass and shotgun hull candidates with open mouths and rims."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
out = ROOT / "build/reload_prop_review"
out.mkdir(parents=True, exist_ok=True)
for shotgun in [False, True]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    def material(name, color, metal):
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = (*color, 1)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = (*color, 1)
        shader.inputs["Metallic"].default_value = metal
        shader.inputs["Roughness"].default_value = 0.3
        return mat
    brass = material("Spent brass", (0.52, 0.3, 0.06), 0.8)
    body = material("Red polymer hull", (0.34, 0.012, 0.015), 0.1) if shotgun else brass
    dark = material("Interior soot", (0.025, 0.018, 0.01), 0.1)
    radius, length = (0.009, 0.065) if shotgun else (0.005, 0.022)
    def cylinder(name, r, depth, z, mat):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=r, depth=depth, location=(0, 0, z))
        obj = bpy.context.object
        obj.name = name
        obj.data.materials.append(mat)
        bevel = obj.modifiers.new("Rolled edge", "BEVEL")
        bevel.width = 0.0003
        bevel.segments = 2
        obj.modifiers.new("Normals", "WEIGHTED_NORMAL")
    cylinder("Case wall", radius, length, 0, body)
    cylinder("Dark recessed open mouth", radius * 0.83, 0.0003, length / 2 + 0.0002, dark)
    bpy.ops.mesh.primitive_torus_add(major_radius=radius * 0.92, minor_radius=radius * 0.08, location=(0, 0, length / 2 + 0.0004))
    bpy.context.object.data.materials.append(body)
    cylinder("Extraction rim", radius * 1.12, 0.0015, -length / 2, brass)
    if shotgun:
        cylinder("Brass head", radius * 1.02, 0.012, -length / 2 + 0.006, brass)
    cylinder("Primer", radius * 0.35, 0.0005, -length / 2 - 0.001, brass)
    bpy.ops.object.camera_add(location=(length * 2, -length * 3, length * 2))
    camera = bpy.context.object
    camera.rotation_euler = (-camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.clip_start = 0.0001
    camera.data.clip_end = 10
    camera.data.ortho_scale = length * 1.5
    bpy.context.scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(0.1, -0.15, 0.2))
    lamp = bpy.context.object
    lamp.rotation_euler = (-lamp.location).to_track_quat("-Z", "Y").to_euler()
    lamp.data.energy, lamp.data.size = 4, 0.2
    scene = bpy.context.scene
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.15, 0.15, 0.15)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.render.resolution_x = scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    name = "spent_shotgun" if shotgun else "spent_brass"
    bpy.ops.wm.save_as_mainfile(filepath=str(out / (name + ".blend")))
    scene.render.filepath = str(out / (name + ".png"))
    bpy.ops.render.render(write_still=True)
