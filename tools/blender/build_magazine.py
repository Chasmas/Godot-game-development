"""Render detailed magazine candidates for the existing 2D reload effect."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
out = ROOT / "build/reload_prop_review"
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
def material(name, color, metal, roughness):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = roughness
    return result
steel = material("Blued steel", (0.075, 0.085, 0.105), 0.8, 0.32)
edge = material("Worn edges", (0.24, 0.27, 0.30), 0.85, 0.28)
brass = material("Cartridge brass", (0.55, 0.32, 0.08), 0.75, 0.24)
def box(name, position, dimensions, mat, bevel=0.001):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    modifier = obj.modifiers.new("Machined edges", "BEVEL")
    modifier.width = bevel
    modifier.segments = 3
    obj.modifiers.new("Normals", "WEIGHTED_NORMAL")
    return obj
box("Magazine body", (0, 0, 0), (0.038, 0.024, 0.115), steel)
box("Floor plate", (0, 0, -0.057), (0.042, 0.028, 0.005), edge)
for x in [-0.015, 0.015]:
    box("Feed lip", (x, 0, 0.059), (0.005, 0.021, 0.008), edge)
for z in [-0.04, -0.02, 0, 0.02, 0.04]:
    box("Stamped reinforcing rib", (0, -0.0125, z), (0.031, 0.0015, 0.002), edge, 0.0005)
bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.0045, depth=0.018,
                                   location=(0, 0.002, 0.058), rotation=(math.pi / 2, 0, 0))
round_obj = bpy.context.object
round_obj.name = "Visible brass cartridge"
round_obj.data.materials.append(brass)
copper = material("Copper jacket", (0.4, 0.15, 0.07), 0.7, 0.3)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=(0, -0.009, 0.058))
bullet = bpy.context.object
bullet.name = "Rounded projectile"
bullet.scale = (0.0044, 0.006, 0.0044)
bullet.data.materials.append(copper)
bpy.ops.object.camera_add(location=(0.10, -0.18, 0.14))
camera = bpy.context.object
camera.rotation_euler = (-camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 0.155
bpy.context.scene.camera = camera
for position, power in [((0.15, -0.25, 0.30), 5), ((-0.15, 0.1, 0.15), 3)]:
    bpy.ops.object.light_add(type="AREA", location=position)
    lamp = bpy.context.object
    lamp.rotation_euler = (-lamp.location).to_track_quat("-Z", "Y").to_euler()
    lamp.data.energy = power
    lamp.data.size = 0.25
scene = bpy.context.scene
scene.world = bpy.data.worlds.new("World")
scene.world.color = (0.15, 0.15, 0.15)
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.render.resolution_x = scene.render.resolution_y = 256
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
bpy.ops.wm.save_as_mainfile(filepath=str(out / "magazine.blend"))
for name, loaded in [("magazine_loaded", True), ("magazine_empty", False)]:
    round_obj.hide_render = not loaded
    bullet.hide_render = not loaded
    scene.render.filepath = str(out / (name + ".png"))
    bpy.ops.render.render(write_still=True)
