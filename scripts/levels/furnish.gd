class_name Furnish
extends RefCounted
## Furniture that makes a room a room: painted pieces (tools/art sprites)
## chosen by what the room is and where we are - sofas, shelves, lamps and
## palms against the walls, a set piece on a rug in the middle of the big
## rooms (a pool table, a DJ booth, a champagne tower, a buffet). Solid
## pieces block like furniture and are cut out of the nav grid; nothing
## goes in front of a door, on a spawn, a pickup or a patrol point.
## Deterministic per level.

const T := 16

## piece -> [tiles along the wall, tiles deep, solid]
const PIECES := {
	"sofa": [3.0, 1.4, true], "coffee_table": [2.0, 1.2, true], "floor_lamp": [1.0, 1.0, false],
	"potted_palm": [1.2, 1.2, false], "bar_cart": [1.0, 1.0, true], "speaker_stack": [1.0, 1.0, true],
	"cocktail_table": [1.4, 1.4, true], "pool_table": [4.0, 2.2, true], "dj_booth": [3.0, 1.6, true],
	"champagne_tower": [1.8, 1.8, true], "buffet_table": [4.0, 1.5, true], "sideboard": [2.5, 1.0, true],
	"bookshelf": [2.5, 1.0, true], "fireplace": [2.5, 1.0, true], "statue": [1.2, 1.2, true],
	"grandfather_clock": [1.0, 1.0, true], "luggage_cart": [1.4, 1.4, true], "dressing_table": [2.5, 1.2, true],
	"clothes_rack": [2.5, 1.0, true], "light_stand": [1.2, 1.2, false], "flight_case": [1.2, 1.2, true],
	"camera_dolly": [2.4, 1.6, true], "director_chair": [1.0, 1.0, false], "scrap_pile": [2.0, 2.0, true],
	"engine_block": [1.4, 1.4, true], "toolbox_chest": [1.4, 1.0, true], "filing_cabinet": [1.0, 1.0, true],
	"tyre_stack": [1.2, 1.2, true], "oil_drum": [1.0, 1.0, true], "pallet": [1.4, 1.4, false],
	"jukebox": [1.2, 1.2, true], "armchair": [1.4, 1.4, true], "round_rug": [4.0, 4.0, false],
}

## room kind -> [wall pieces, centre set pieces]
const THEMES := {
	"lounge": [["sofa", "floor_lamp", "potted_palm", "bar_cart", "bookshelf", "armchair", "jukebox", "speaker_stack"], ["pool_table", "coffee_table", "cocktail_table"]],
	"ballroom": [["speaker_stack", "potted_palm", "statue", "sofa", "bar_cart", "floor_lamp"], ["dj_booth", "champagne_tower", "cocktail_table"]],
	"dining": [["sideboard", "potted_palm", "grandfather_clock", "bar_cart", "fireplace"], ["buffet_table", "champagne_tower"]],
	"library": [["bookshelf", "bookshelf", "floor_lamp", "armchair", "fireplace", "grandfather_clock"], ["coffee_table"]],
	"foyer": [["potted_palm", "statue", "grandfather_clock", "sofa", "luggage_cart", "floor_lamp"], ["round_rug"]],
	"lobby": [["potted_palm", "sofa", "luggage_cart", "floor_lamp", "armchair"], ["coffee_table"]],
	"office": [["filing_cabinet", "bookshelf", "potted_palm", "floor_lamp", "armchair"], []],
	"security_office": [["filing_cabinet", "filing_cabinet", "speaker_stack"], []],
	"control_room": [["filing_cabinet", "flight_case", "speaker_stack"], []],
	"guest_room": [["dressing_table", "floor_lamp", "clothes_rack", "armchair"], []],
	"dressing_room": [["dressing_table", "dressing_table", "clothes_rack", "floor_lamp", "director_chair"], []],
	"wardrobe": [["clothes_rack", "clothes_rack", "flight_case"], []],
	"stage": [["light_stand", "flight_case", "speaker_stack", "director_chair", "light_stand"], ["camera_dolly"]],
	"industrial": [["toolbox_chest", "oil_drum", "tyre_stack", "pallet", "engine_block"], ["scrap_pile"]],
	"yard": [["scrap_pile", "tyre_stack", "oil_drum", "engine_block", "pallet"], ["scrap_pile"]],
	"generic": [["potted_palm", "floor_lamp", "armchair", "bookshelf"], []],
}

## The Villa Estrella's rooms, by zone (the level doesn't name them otherwise).
const ZONE_KIND := {"ballroom": "ballroom", "foyer": "foyer", "west_wing": "lounge", "east_wing": "dining"}

static func build(level: Node, b: LevelBuilder, rooms: Array) -> void:
	var layer := FurnitureLayer.new()
	layer.name = "Furniture"
	layer.z_index = 1
	level.add_child(layer)
	var blocked := _blocked_cells(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(b.data.get("id", "")))
	for r in rooms:
		var kind: String = r.kind
		if b.data.get("id", "") == "m04_villa_estrella" and ZONE_KIND.has(r.zone):
			kind = ZONE_KIND[r.zone]
		if kind in ["corridor", "lot", "courtyard", "kennel", "laundry", "bathroom", "crypt", "nursery"]:
			continue
		var th: Array = THEMES.get(kind, THEMES.generic)
		if r.cells.size() < 12:
			continue
		var used := {}
		if kind == "ballroom":
			_ballroom(r, b, blocked, used, layer, rng)
		_centre(r, b, th[1], blocked, used, layer, rng)
		_walls(r, b, th[0], blocked, used, layer, rng)
		if OS.get_environment("FURNISH_DEBUG") != "":
			print("furnish ", kind, " ", r.zone, " cells ", r.cells.size(), " rect ", r.rect, " items ", layer.items.size())
	layer.queue_redraw()

## Cells nothing may cover: every map character that isn't plain floor
## (spawns, enemies, pickups, props, doors) with a margin, patrol points,
## and the two cells in front of every door.
static func _blocked_cells(b: LevelBuilder) -> Dictionary:
	var out := {}
	for y in b.h:
		for x in b.w:
			var c := b.ch(x, y)
			if c in ["#", " ", "*", "^", "o"]:
				continue   # walls, and lights (they hang from the ceiling)
			if not LevelBuilder.FLOORS.contains(c):
				var m := 2 if c in ["D", "L", "W", "X", "P", "@"] else 1
				for dy in range(-m, m + 1):
					for dx in range(-m, m + 1):
						out[Vector2i(x + dx, y + dy)] = true
	for cfg in b.data.get("enemies", {}).values():
		for p in cfg.get("patrol", []):
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					out[Vector2i(int(p[0]) + dx, int(p[1]) + dy)] = true
	return out

static func _free(r, b: LevelBuilder, rect: Rect2i, blocked: Dictionary, used: Dictionary) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if blocked.has(c) or used.has(c) or not c in r.cells:
				return false
			if not LevelBuilder.FLOORS.contains(b.ch(x, y)):
				return false
	return true

static func _claim(rect: Rect2i, used: Dictionary, margin := 0) -> void:
	for y in range(rect.position.y - margin, rect.end.y + margin):
		for x in range(rect.position.x - margin, rect.end.x + margin):
			used[Vector2i(x, y)] = true

## A set piece on a rug in the middle of a big room, with room to walk
## round it on every side.
static func _centre(r, b: LevelBuilder, pieces: Array, blocked: Dictionary, used: Dictionary, layer, rng: RandomNumberGenerator) -> void:
	if pieces.is_empty() or r.rect.size.x < 7 or r.rect.size.y < 6:
		return
	var id: String = pieces[rng.randi() % pieces.size()]
	var d: Array = PIECES[id]
	var w := int(ceil(d[0]))
	var h := int(ceil(d[1]))
	# big rooms get a set piece every ~9 tiles, not just one in the middle
	var anchors: Array = []
	var nx := maxi(1, r.rect.size.x / 9)
	var ny := maxi(1, r.rect.size.y / 8)
	for iy in ny:
		for ix in nx:
			anchors.append(r.rect.position + Vector2i(int((ix + 0.5) * r.rect.size.x / nx), int((iy + 0.5) * r.rect.size.y / ny)))
	for a in anchors:
		var pid: String = pieces[rng.randi() % pieces.size()]
		_set_piece(r, b, pid, a, blocked, used, layer, rng, pieces)

static func _set_piece(r, b: LevelBuilder, id: String, c: Vector2i, blocked: Dictionary, used: Dictionary, layer, rng: RandomNumberGenerator, pieces: Array) -> void:
	var d: Array = PIECES[id]
	var w := int(ceil(d[0]))
	var h := int(ceil(d[1]))
	var rect := Rect2i(c.x - w / 2, c.y - h / 2, w, h)
	if not _free(r, b, rect.grow(1), blocked, used):
		return
	# Rugs belong to deliberate interior seating and entertainment vignettes.
	# The old universal rug made salvage and service props look repeated and
	# disconnected from their setting.
	if id in ["pool_table", "coffee_table", "cocktail_table", "dj_booth", "champagne_tower", "buffet_table"]:
		var rug := rect.grow(1)
		layer.add("round_rug", Rect2(Vector2(rug.position) * T, Vector2(rug.size) * T), 0.0, false, true)
	layer.add(id, Rect2(Vector2(rect.position) * T + Vector2(2, 2), Vector2(rect.size) * T - Vector2(4, 4)), 0.0, bool(d[2]))
	_claim(rect, used, 2)
	if bool(d[2]):
		_solid(b, rect)
	# a couple of smaller pieces around it in the big rooms (cocktail tables round the booth)
	if r.rect.size.x >= 12 and pieces.size() > 1:
		var small: String = pieces[-1]
		for off in [Vector2i(-w - 3, 0), Vector2i(w + 2, 0)]:
			var sr := Rect2i(rect.position + off, Vector2i(2, 2))
			if _free(r, b, sr.grow(1), blocked, used):
				layer.add(small, Rect2(Vector2(sr.position) * T + Vector2(4, 4), Vector2(sr.size) * T - Vector2(8, 8)), rng.randf_range(-0.3, 0.3), true)
				_claim(sr, used, 1)
				_solid(b, sr)

## Along the walls: runs of free cells against a wall, a piece every few
## tiles, facing into the room.
static func _walls(r, b: LevelBuilder, pieces: Array, blocked: Dictionary, used: Dictionary, layer, rng: RandomNumberGenerator) -> void:
	if pieces.is_empty():
		return
	var budget := clampi(r.cells.size() / 9, 2, 22)
	var tries := 0
	var cells: Array = r.cells.duplicate()
	# deterministic shuffle
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	for cell in cells:
		if budget <= 0 or tries > 1200:
			break
		tries += 1
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if b.ch(cell.x + dir.x, cell.y + dir.y) != "#":
				continue
			var id: String = pieces[rng.randi() % pieces.size()]
			var d: Array = PIECES[id]
			var along := int(ceil(d[0]))
			var deep := int(ceil(d[1]))
			var horiz: bool = dir.y != 0
			var rect := Rect2i(cell.x, cell.y, along, deep) if horiz else Rect2i(cell.x, cell.y, deep, along)
			if dir == Vector2i(0, 1):
				rect.position.y = cell.y - deep + 1
			elif dir == Vector2i(1, 0):
				rect.position.x = cell.x - deep + 1
			# the whole piece against the same wall
			var ok := true
			for k in along:
				var wc: Vector2i = (Vector2i(rect.position.x + k, cell.y) if horiz else Vector2i(cell.x, rect.position.y + k)) + dir
				if b.ch(wc.x, wc.y) != "#":
					ok = false
			# keep a walkway in front of it
			var front := rect
			if horiz:
				front.position.y += -dir.y * deep
			else:
				front.position.x += -dir.x * deep
			if not ok or not _free(r, b, rect, blocked, used) or not _free(r, b, front, blocked, used):
				continue
			# the back of the piece against the wall: rotate so its top edge faces the wall
			var ang: float = {Vector2i(0, -1): 0.0, Vector2i(0, 1): PI, Vector2i(-1, 0): -PI * 0.5, Vector2i(1, 0): PI * 0.5}[dir]
			var px := Rect2(Vector2(rect.position) * T + Vector2(1, 1), Vector2(rect.size) * T - Vector2(2, 2))
			layer.add(id, px, ang, bool(d[2]))
			_claim(rect, used, 1)
			_claim(front, used, 0)
			if bool(d[2]):
				_solid(b, rect)
			budget -= 1
			break

## A ballroom: a marble dance floor inlaid in the middle (under everything,
## so the fight still has its space) and round tables laid for a party all
## round it, each with its chairs.
static func _ballroom(r, b: LevelBuilder, blocked: Dictionary, used: Dictionary, layer, rng: RandomNumberGenerator) -> void:
	var inner: Rect2i = r.rect.grow(-4)
	if inner.size.x >= 6 and inner.size.y >= 5:
		var df := DanceFloor.new()
		df.rect = Rect2(Vector2(inner.position) * T, Vector2(inner.size) * T)
		df.z_index = -9
		b.level.add_child(df)
		StaticBake.queue(b.level, df, df.rect.grow(8.0))
	# a ring of tables between the walls and the dance floor
	var spots: Array = []
	for x in range(r.rect.position.x + 2, r.rect.end.x - 2, 5):
		spots.append(Vector2i(x, r.rect.position.y + 2))
		spots.append(Vector2i(x, r.rect.end.y - 3))
	for y in range(r.rect.position.y + 6, r.rect.end.y - 5, 5):
		spots.append(Vector2i(r.rect.position.x + 2, y))
		spots.append(Vector2i(r.rect.end.x - 3, y))
	for c in spots:
		var tr := Rect2i(c, Vector2i(2, 2))
		if not _free(r, b, tr.grow(1), blocked, used):
			continue
		layer.add("cocktail_table", Rect2(Vector2(tr.position) * T + Vector2(3, 3), Vector2(tr.size) * T - Vector2(6, 6)), rng.randf_range(-0.4, 0.4), true)
		# chairs round it, turned to face the table, one pushed back
		var mid := (Vector2(tr.position) + Vector2(1, 1)) * T
		for k in 4:
			var a := k * PI * 0.5 + PI * 0.25 + rng.randf_range(-0.15, 0.15)
			var dist := 19.0 + (6.0 if k == rng.randi() % 4 else 0.0)
			var p := mid + Vector2.from_angle(a) * dist
			layer.add("wooden_chair", Rect2(p - Vector2(6, 6), Vector2(12, 12)), a + PI * 0.5, false)
		_claim(tr, used, 1)
		_solid(b, tr)

static func _solid(b: LevelBuilder, rect: Rect2i) -> void:
	var lvl: Node = b.level
	var body := StaticBody2D.new()
	body.collision_layer = Layers.PROP
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(rect.size) * T - Vector2(4, 4)
	cs.shape = rs
	body.position = (Vector2(rect.position) + Vector2(rect.size) * 0.5) * T
	body.add_child(cs)
	lvl.props_root.add_child(body)
	var nav: AStarGrid2D = lvl.get("nav")
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if nav and nav.is_in_boundsv(Vector2i(x, y)):
				nav.set_point_solid(Vector2i(x, y), true)
			if y >= 0 and y < b.solid_grid.size() and x >= 0 and x < b.solid_grid[y].size():
				b.solid_grid[y][x] = true


## The ballroom's dance floor: black and white marble in a checker, a brass
## border, and the villa's star inlaid in the middle in gold.
class DanceFloor extends Node2D:
	var rect := Rect2()
	func _draw() -> void:
		var marble := ArtLib.floor_tex("m", {"m": "marble"})
		var n := Vector2i(int(rect.size.x / T), int(rect.size.y / T))
		# pale squares, then dark ones (the same painting, tinted: they batch)
		for pass_dark in [false, true]:
			for y in n.y:
				for x in n.x:
					if ((x + y) % 2 == 1) != pass_dark:
						continue
					var cell := Rect2(rect.position + Vector2(x, y) * T, Vector2(T, T))
					var col := Color(0.2, 0.17, 0.22, 0.92) if pass_dark else Color(1, 0.97, 0.94, 0.92)
					if marble:
						var src := Rect2(fposmod(cell.position.x * 4.0, 512.0), fposmod(cell.position.y * 4.0, 512.0), 64, 64)
						draw_texture_rect_region(marble, cell, src, col)
					else:
						draw_rect(cell, col)
		# the brass border
		var gold := Color(0.85, 0.66, 0.28)
		draw_rect(rect.grow(2.0), Color(0.1, 0.06, 0.04), false, 3.0)
		draw_rect(rect.grow(0.5), gold, false, 1.5)
		# the star medallion
		var c := rect.get_center()
		var R := minf(rect.size.x, rect.size.y) * 0.22
		draw_circle(c, R * 1.15, Color(0.1, 0.06, 0.08, 0.9))
		draw_arc(c, R * 1.15, 0, TAU, 48, gold, 2.0)
		draw_arc(c, R * 1.02, 0, TAU, 48, Color(gold, 0.6), 1.0)
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI * 0.5 + i * PI / 5.0
			pts.append(c + Vector2.from_angle(a) * (R if i % 2 == 0 else R * 0.42))
		draw_colored_polygon(pts, gold)
		for i in 5:
			var a := -PI * 0.5 + i * TAU / 5.0
			draw_line(c, c + Vector2.from_angle(a) * R, Color(1, 0.9, 0.55, 0.7), 1.0)


## Draws every piece once: a soft contact shadow, then the painting fitted
## into its footprint, turned to its wall.
class FurnitureLayer extends Node2D:
	var items: Array = []    ## [id, rect, angle, solid, flat]

	func add(id: String, r: Rect2, ang: float, solid: bool, flat := false) -> void:
		items.append([id, r, ang, solid, flat])

	func _draw() -> void:
		# rugs first, then everything standing on them
		for pass_flat in [true, false]:
			for it in items:
				if bool(it[4]) != pass_flat:
					continue
				var tex := ArtLib.sprite(str(it[0]))
				if tex == null:
					continue
				var r: Rect2 = it[1]
				var ang: float = it[2]
				var sz := r.size
				if absf(sin(ang)) > 0.5:
					sz = Vector2(sz.y, sz.x)
				var ta := float(tex.get_width()) / float(tex.get_height())
				var fit := Vector2(sz.x, sz.x / ta) if sz.x / sz.y < ta else Vector2(sz.y * ta, sz.y)
				draw_set_transform(r.get_center(), ang, Vector2.ONE)
				if not bool(it[4]):
					draw_texture_rect(tex, Rect2(-fit * 0.5 + Vector2(2, 3).rotated(-ang), fit), false, Color(0, 0, 0, 0.35))
				draw_texture_rect(tex, Rect2(-fit * 0.5, fit), false, Color(1, 1, 1, 0.92) if bool(it[4]) else Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
