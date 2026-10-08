"""Inspect the existing canine mesh before choosing a rigging workflow."""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
breed = args[0] if args else "hellhound"
if breed not in {"hellhound", "shepherd", "doberman", "rottweiler"}:
    raise ValueError("Unsupported canine source: " + breed)
OUT = ROOT / "build/canine_review" / breed
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/art/Artwork/3d" / breed / "model.glb"))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
lo = Vector(tuple(min(point[i] for point in points) for i in range(3)))
hi = Vector(tuple(max(point[i] for point in points) for i in range(3)))
report = {"breed": breed, "bounds_min": list(lo), "bounds_max": list(hi), "objects": []}
for obj in bpy.context.scene.objects:
    entry = {"name": obj.name, "type": obj.type}
    if obj.type == "MESH":
        entry.update(vertices=len(obj.data.vertices), materials=[mat.name for mat in obj.data.materials if mat],
                     vertex_groups=[group.name for group in obj.vertex_groups])
    if obj.type == "ARMATURE":
        entry["bones"] = [bone.name for bone in obj.data.bones]
    report["objects"].append(entry)
(OUT / "audit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
center = (lo + hi) * 0.5
extent = max(hi - lo)
bpy.ops.object.camera_add(location=center + Vector((1.4, -1.8, 1.2)) * extent)
camera = bpy.context.object
camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = extent * 1.5
bpy.context.scene.camera = camera
for offset, power in [((1, -2, 3), 1200), ((-2, 1, 2), 700)]:
    bpy.ops.object.light_add(type="AREA", location=center + Vector(offset) * extent)
    light = bpy.context.object
    light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()
    light.data.energy = power
    light.data.shape = "DISK"
    light.data.size = extent * 2
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 900
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.world.color = (0.08, 0.08, 0.08)
scene.render.filepath = str(OUT / "source_review.png")
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source_review.blend"))
bpy.ops.render.render(write_still=True)
