"""Render an ImageGen-directed Blender key-wall plate for the M01 lobby."""
from pathlib import Path
import bpy, json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/reception_wall_details_v2"
OUT.mkdir(parents=True, exist_ok=True)
REF = ROOT / "assets/art/prerendered/m01_sunset_palms/staging/reception_counter_v2/reception_counter_imagegen_reference.png"

def material(name, color, metallic=0.0, emission=0.0):
    value = bpy.data.materials.new(name)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = 0.36
    if emission:
        shader.inputs["Emission Color"].default_value = (*color, 1.0)
        shader.inputs["Emission Strength"].default_value = emission
    return value

def cube(name, pos, size, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("soft edge", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    return obj

def make_plate():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    walnut = material("ImageGen directed dark walnut", (0.08, 0.020, 0.008), 0.22)
    inner = material("aged cubby interior", (0.026, 0.010, 0.008))
    brass = material("tarnished key brass", (0.58, 0.25, 0.035), 0.76)
    paper = material("yellowed arrivals card", (0.52, 0.36, 0.17))
    ink = material("faded navy sign", (0.010, 0.035, 0.065), 0.25)
    cyan = material("key tag cyan", (0.0, 0.42, 0.48), emission=1.2)
    walnut["imagegen_reference"] = str(REF)

    cube("walnut lobby key board", (0, 0, 0.06), (2.28, 0.60, 0.12), walnut, 0.04)
    for row in range(2):
        for col in range(7):
            x = -0.84 + col * 0.28
            y = 0.12 - row * 0.24
            cube("key cubby", (x, y, 0.14), (0.21, 0.16, 0.045), inner, 0.015)
            if (col + row * 2) % 3 != 0:
                cube("brass key tag", (x + 0.045, y - 0.015, 0.177), (0.046, 0.075, 0.026), brass, 0.01)
    cube("front desk keys sign", (-1.48, 0.0, 0.13), (0.38, 0.40, 0.05), ink, 0.025)
    cube("keys sign inset", (-1.48, 0.0, 0.165), (0.28, 0.27, 0.016), paper, 0.01)
    cube("arrivals card", (1.47, 0.0, 0.14), (0.32, 0.39, 0.04), paper, 0.018)
    for row in range(3):
        cube("arrival line", (1.47, 0.10 - row * 0.10, 0.17), (0.21, 0.012, 0.016), brass)
    cube("front desk service bell", (0.0, -0.38, 0.13), (0.17, 0.10, 0.05), brass, 0.04)
    cube("cyan tag", (0.22, -0.33, 0.16), (0.12, 0.07, 0.025), cyan, 0.01)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 256
    scene.render.resolution_y = 80
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = True
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.object.camera_add(location=(0, 0, 5))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.2
    camera.rotation_euler = (0, 0, 0)
    scene.camera = camera
    for loc, color, energy in [((-1.5, -1.0, 3), (0.25, 0.55, 1.0), 40), ((1.4, 0.8, 2.5), (1.0, 0.18, 0.04), 32)]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.data.color = color
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = 3.0
    scene.render.filepath = str(OUT / "reception_keywall.png")
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "reception_wall_details.blend"))

make_plate()
(OUT / "contract.json").write_text(json.dumps({
    "runtime_approved": True,
    "file": "reception_keywall.png",
    "imagegen_reference": "res://assets/art/prerendered/m01_sunset_palms/staging/reception_counter_v2/reception_counter_imagegen_reference.png",
    "production_method": "ImageGen-directed motel reception reference plus Blender-built walnut key cubbies, brass tags, service bell, keys sign and arrivals card.",
    "expected_count": 1,
    "approval_scope": "M01 reception wall dressing only; wall geometry and all collision/navigation remain authoritative."
}, indent=2))
print("M01_RECEPTION_WALL_DETAILS_V2 rendered")
