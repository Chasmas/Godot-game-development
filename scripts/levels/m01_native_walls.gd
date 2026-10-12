class_name M01NativeWalls
extends RefCounted

const DIRECTORY := "res://assets/art/prerendered/m01_sunset_palms/runtime/walls_v1/"

static func build(level: Level) -> void:
	if level.mission == null or level.mission.id != &"m01_checkout": return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "runtime_contract.json"))
	if not parsed is Dictionary: return
	var contract: Dictionary = parsed
	if not bool(contract.get("runtime_approved", false)): return
	if str(contract.get("source_level_sha256", "")) != FileAccess.get_sha256("res://levels/m01_sunset_palms.json"):
		push_warning("M01 wall map changed; retaining legacy wall drawing")
		return
	var texture := load(DIRECTORY + str(contract.get("image", ""))) as Texture2D
	if texture == null or texture.get_size() != Vector2(2176, 1952): return
	var image := texture.get_image()
	if image == null: return
	var root := Node2D.new()
	root.name = "NativeM01Walls"
	var count := 0
	for y in range(0, texture.get_height(), 128):
		for x in range(0, texture.get_width(), 128):
			var region := Rect2i(x, y, mini(128, texture.get_width() - x), mini(128, texture.get_height() - y))
			if image.get_region(region).is_invisible(): continue
			var tile := Sprite2D.new()
			tile.texture = texture
			tile.region_enabled = true
			tile.region_rect = Rect2(region)
			tile.centered = false
			tile.position = Vector2(x, y) * .5
			tile.scale = Vector2.ONE * .5
			tile.z_index = 6
			tile.light_mask = int(contract.get("runtime_light_mask", 2))
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			root.add_child(tile)
			count += 1
	if count == 0: return
	var hidden := 0
	for child in level.walls_root.get_children():
		if child is LevelBuilder.WallChunk:
			child.hide()
			hidden += 1
	if hidden == 0:
		root.queue_free()
		return
	var facades := WallFacades.new()
	facades.rows = level.data.get("map", [])
	facades.name = "M01WallFacades"
	root.add_child(facades)
	level.walls_root.add_child(root)

## The painted wall sheet carries the wallpaper and windows.  This small
## foreground pass supplies the missing wall thickness at every exposed lower
## edge, so rooms read as shallow oblique spaces instead of flat block shapes.
class WallFacades extends Node2D:
	var rows: Array = []
	const TILE := 16.0
	const FACE_HEIGHT := 11.0
	const TOP_LEDGE := 1.25
	const FACADE_TEXTURE := preload("res://assets/art/prerendered/m01_sunset_palms/runtime/walls_v1/m01_wall_fascia_v1.png")

	func _ready() -> void:
		z_index = 6
		light_mask = 2
		queue_redraw()

	func _wall_at(x: int, y: int) -> bool:
		return y >= 0 and y < rows.size() and x >= 0 and x < str(rows[y]).length() and str(rows[y])[x] == "#"

	func _draw() -> void:
		for y in rows.size():
			var row := str(rows[y])
			for x in row.length():
				if row[x] != "#" or _wall_at(x, y + 1):
					continue
				# Each exposed lower edge gets actual painted motel plaster rather than
				# a procedural block. Offset the sampled panel deterministically so a
				# long corridor does not repeat the same stain or crack each tile.
				var face := Rect2(x * TILE, y * TILE + TILE - FACE_HEIGHT, TILE, FACE_HEIGHT)
				var source := Rect2(float(posmod(x * 73 + y * 29, 192)), 0, 192, 96)
				draw_texture_rect_region(FACADE_TEXTURE, face, source)
				# A thin sill and deep lower contact shadow make the lower wall read
				# as an oblique facade, not a flat map-cell block. Both are paint only.
				draw_rect(Rect2(face.position, Vector2(TILE, TOP_LEDGE)), Color("4b2d41"))
				draw_line(Vector2(face.position.x, face.position.y + TOP_LEDGE), Vector2(face.end.x, face.position.y + TOP_LEDGE), Color("d17d78"), .55)
				draw_line(Vector2(face.position.x, face.end.y - .5), Vector2(face.end.x, face.end.y - .5), Color(0.018, 0.01, 0.028, 0.9), 1.25)
				# Short dark corner returns break long wall runs into architectural spans.
				if not _wall_at(x - 1, y): draw_line(face.position, Vector2(face.position.x, face.end.y), Color("221829"), 1.1)
				if not _wall_at(x + 1, y): draw_line(Vector2(face.end.x - .5, face.position.y), face.end - Vector2(.5, 0), Color("221829"), 1.1)
