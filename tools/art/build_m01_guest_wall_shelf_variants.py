"""Author two visual-only M01 guest-room shelf variants in Blender.

They share the footprint and camera of guest_wall_shelf_v1 so the runtime can
alternate them without changing layout, collision or navigation.
"""
from pathlib import Path
import json

import bpy


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/art/prerendered/m01_sunset_palms/runtime/guest_wall_shelf_v1"
OUT.mkdir(parents=True, exist_ok=True)


def material(name: str, color: tuple[float, float, float], metallic=0.0, emission=0.0):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes.get("Principled BSDF")
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Metallic"].default_value = metallic
	bsdf.inputs["Roughness"].default_value = .48
	if emission:
		bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
		bsdf.inputs["Emission Strength"].default_value = emission
	return m


def cube(name: str, position, size, mat, bevel=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1, location=position)
	obj = bpy.context.object
	obj.name = name
	obj.dimensions = size
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	obj.data.materials.append(mat)
	if bevel:
		modifier = obj.modifiers.new("edge softness", "BEVEL")
		modifier.width = bevel
		modifier.segments = 2
	return obj


def configure_scene(name: str):
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 192
	scene.render.resolution_y = 96
	scene.render.resolution_percentage = 100
	scene.render.image_settings.file_format = "PNG"
	scene.render.film_transparent = True
	scene.view_settings.look = "AgX - Medium High Contrast"
	bpy.ops.object.camera_add(location=(0, 0, 5))
	camera = bpy.context.object
	camera.name = name + " camera"
	camera.data.type = "ORTHO"
	camera.data.ortho_scale = 1.7
	scene.camera = camera
	for position, energy, tint, size in [((-1, -1, 3), 120, (.25, .75, 1), 3), ((1, 1, 2), 80, (1, .15, .35), 2)]:
		bpy.ops.object.light_add(type="AREA", location=position)
		light = bpy.context.object
		light.data.energy = energy
		light.data.color = tint
		light.data.shape = "DISK"
		light.data.size = size
	return scene


def shelf_base():
	walnut = material("weathered walnut", (.13, .035, .018))
	brass = material("brass edge", (.52, .19, .04), .6)
	cube("shelf board", (0, 0, .08), (1.35, .18, .12), walnut, .025)
	cube("brass front", (0, -.105, .13), (1.38, .025, .055), brass, .008)
	return walnut, brass


def books(offset: float, colors: list):
	for index, x in enumerate([-.52, -.36, -.19, -.02]):
		cube("cloth-bound book %d" % index, (x + offset, 0, .245), (.105, .12, .25 + (index % 2) * .075), colors[index % len(colors)], .01)


def render_radio_variant():
	scene = configure_scene("radio shelf")
	walnut, brass = shelf_base()
	books(0.0, [material("book turquoise", (.02, .20, .24)), material("book ochre", (.52, .23, .035)), material("book burgundy", (.40, .025, .05))])
	black = material("radio charcoal", (.012, .014, .022), .25)
	grille = material("radio grille", (.11, .14, .16), .65)
	ash = material("ceramic ashtray", (.20, .12, .26), .1)
	cube("pocket radio", (.38, 0, .245), (.31, .17, .24), black, .025)
	cube("radio grille", (.38, -.091, .245), (.20, .012, .11), grille, .006)
	bpy.ops.mesh.primitive_torus_add(major_radius=.09, minor_radius=.018, major_segments=16, minor_segments=6, location=(.63, 0, .19))
	bpy.context.object.name = "ceramic ashtray"
	bpy.context.object.data.materials.append(ash)
	scene.render.filepath = str(OUT / "guest_wall_shelf_radio.png")
	bpy.ops.render.render(write_still=True)
	bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "guest_wall_shelf_radio.blend"))


def render_vase_variant():
	scene = configure_scene("vase shelf")
	walnut, brass = shelf_base()
	books(-.08, [material("book cream", (.66, .48, .20)), material("book moss", (.10, .29, .13)), material("book coral", (.50, .035, .06))])
	pot = material("glazed teal pot", (.02, .30, .32), .28)
	leaf = material("eucalyptus leaves", (.06, .28, .16))
	flower = material("tiny coral flowers", (1.0, .04, .16), 0.18)
	for x, scale in [(0.38, 1.0), (.58, .68)]:
		bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=7, radius=.12 * scale, location=(x, 0, .20))
		vase = bpy.context.object
		vase.name = "glazed vase"
		vase.scale = (1.0, .76, 1.15)
		vase.data.materials.append(pot)
		for dx, dy in [(-.045, 0), (.035, .025), (.01, -.05)]:
			bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.10 * scale, location=(x + dx, dy, .38 + scale * .05))
			foliage = bpy.context.object
			foliage.name = "shelf leaf"
			foliage.scale = (1.0, .55, .25)
			foliage.data.materials.append(leaf)
		bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=5, radius=.03 * scale, location=(x, -.04, .51))
		bpy.context.object.name = "small flower"
		bpy.context.object.data.materials.append(flower)
	scene.render.filepath = str(OUT / "guest_wall_shelf_vases.png")
	bpy.ops.render.render(write_still=True)
	bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "guest_wall_shelf_vases.blend"))


render_radio_variant()
render_vase_variant()
contract_path = OUT / "contract.json"
contract = json.loads(contract_path.read_text(encoding="utf-8"))
contract["files"] = ["guest_wall_shelf.png", "guest_wall_shelf_radio.png", "guest_wall_shelf_vases.png"]
contract["approval_scope"] = "M01 guest-room visual-only high wall shelf variants; no collision, navigation, interaction or geometry changes."
contract_path.write_text(json.dumps(contract, indent=2), encoding="utf-8")
print("M01_GUEST_WALL_SHELF_VARIANTS: rendered")
