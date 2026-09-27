class_name Dressing
extends RefCounted
## Set dressing: makes every room say what it is and who was in it.
##
## 1. Rooms are found by flood fill (floor cells bounded by walls, doors and
##    windows) and classified from their floor and furniture (a bed on
##    carpet = guest room, a washer = laundry, cages = kennel, ...).
## 2. Each room type has its own prop vocabulary; props go on free floor
##    cells, mostly along walls, never in front of doors, never on spawn or
##    pickup cells. Deterministic: the same level always dresses the same.
## 3. Wall faces get detail where they're visible: room numbers beside
##    doors, pictures, extinguishers, EXIT signs, notices, pipes.
## No collision, no nav changes: purely visual, drawn once into static
## layers (floor clutter under furniture, wall detail over walls).

const T := 16

class Room:
	var id := 0
	var cells: Array[Vector2i] = []
	var rect := Rect2i()
	var floor := ","
	var zone := ""
	var kind := "generic"
	var furn: Dictionary = {}       ## furniture/prop char -> count
	var doors: Array[Vector2i] = []

static func build(level: Node, builder: LevelBuilder, wall_art: WallArt = null) -> void:
	var rooms := _find_rooms(builder)
	var floor_layer := ClutterLayer.new()
	floor_layer.name = "Dressing"
	floor_layer.z_index = -7
	var wall_layer := ClutterLayer.new()
	wall_layer.name = "WallDressing"
	wall_layer.z_index = 7
	wall_layer.boost = builder.boost * 0.78
	wall_layer.light_mask = 0
	var glow_layer := ClutterLayer.new()
	glow_layer.name = "LightPools"
	glow_layer.z_index = -8
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = mat
	var room_no := [100]
	for r in rooms:
		_dress_room(r, builder, floor_layer, glow_layer)
		_dress_walls(r, builder, wall_layer, room_no, wall_art)
	for layer in [glow_layer, floor_layer, wall_layer]:
		level.add_child(layer)

# ------------------------------------------------------------------ rooms
static func _passable(b: LevelBuilder, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= b.w or y >= b.h:
		return false
	var c := b.ch(x, y)
	if c in ["#", "W", "%", "D", "L", " "]:
		return false
	return b.floor_grid[y][x] != ""

static func _find_rooms(b: LevelBuilder) -> Array:
	var seen := {}
	var rooms: Array = []
	for y in b.h:
		for x in b.w:
			var k := Vector2i(x, y)
			if seen.has(k) or not _passable(b, x, y):
				continue
			var r := Room.new()
			r.id = rooms.size()
			var stack: Array[Vector2i] = [k]
			seen[k] = true
			var lo := k
			var hi := k
			var floors := {}
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				r.cells.append(c)
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
				hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
				var chr := b.ch(c.x, c.y)
				var fl: String = b.floor_grid[c.y][c.x]
				floors[fl] = int(floors.get(fl, 0)) + 1
				if not LevelBuilder.FLOORS.contains(chr):
					r.furn[chr] = int(r.furn.get(chr, 0)) + 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if n.x < 0 or n.y < 0 or n.x >= b.w or n.y >= b.h:
						continue
					var nc := b.ch(n.x, n.y)
					if (nc == "D" or nc == "L") and not r.doors.has(n):
						r.doors.append(n)
					if not seen.has(n) and _passable(b, n.x, n.y):
						seen[n] = true
						stack.append(n)
			r.rect = Rect2i(lo, hi - lo + Vector2i.ONE)
			var best := 0
			for f in floors.keys():
				if int(floors[f]) > best and f != "~":
					best = int(floors[f])
					r.floor = f
			var mid: Vector2i = r.cells[r.cells.size() / 2]
			r.zone = b.zone_at_cell(mid.x, mid.y)
			r.kind = _classify(r)
			r.kind = RoomKitsMore.refine(r, b)
			rooms.append(r)
	return rooms

static func _classify(r: Room) -> String:
	var narrow := mini(r.rect.size.x, r.rect.size.y) <= 3
	if r.furn.has("n"):
		return "kennel"
	if r.furn.has("w"):
		return "laundry"
	if r.furn.has("b"):
		return "guest_room"
	if r.floor == "+":
		return "industrial"
	if r.furn.has("k"):
		return "office"
	if r.furn.has("Q") or (r.floor == "_" and r.furn.has("T")):
		return "lounge"
	match r.floor:
		";":
			return "yard"
		":":
			return "lot"
		"=", "\"":
			return "courtyard"
		",":
			return "lobby" if r.zone == "lobby" and not narrow else "corridor"
		".":
			return "office"
		"_":
			return "lounge"
	return "generic"

# ------------------------------------------------------------------ props
const VOCAB := {
	"guest_room": ["suitcase", "clothes", "clothes", "towel", "pizza_box", "ashtray", "bottle", "magazine", "shoes", "tray", "cans", "rug"],
	"corridor":   ["tray", "newspaper", "butts", "cart", "plant_pot", "cans", "shoes", "butts"],
	"lobby":      ["newspaper", "plant_pot", "rug", "magazine", "butts", "luggage"],
	"laundry":    ["basket", "towel", "towel", "detergent", "clothes", "puddle"],
	"office":     ["papers", "papers", "boxes", "coffee", "binder", "trash", "papers"],
	"lounge":     ["bottle", "bottle", "cans", "ashtray", "cards", "glasses", "butts", "rug"],
	"industrial": ["drum", "toolbox", "oil", "oil", "tires", "chain", "boxes", "wrench", "puddle"],
	"kennel":     ["bowl", "bone", "hay", "hay", "chew", "bone", "bowl"],
	"courtyard":  ["towel", "cans", "leaves", "flamingo", "butts", "sandals"],
	"lot":        ["trash", "cans", "newspaper", "hubcap", "oil"],
	"yard":       ["tires", "scrap", "hubcap", "scrap", "drum", "oil"],
	"generic":    ["papers", "cans", "butts", "boxes"],
	"stage":      ["cable_run", "apple_box", "papers", "coffee", "butts"],
	"dressing_room": ["clothes", "towel", "coffee", "shoes"],
	"wardrobe":   ["clothes", "clothes", "shoes", "boxes"],
	"control_room": ["papers", "coffee", "binder", "papers", "trash"],
	"security_office": ["coffee", "papers", "butts"],
	"ballroom":   ["glasses", "bottle", "leaves", "cards"],
	"foyer":      ["leaves", "newspaper", "glasses"],
	"library":    ["book_stack", "papers", "book_stack", "candles"],
	"dining":     ["glasses", "bottle", "bones"],
	"nursery":    ["toy_car", "crayons", "teddy"],
	"bathroom":   ["towel", "puddle", "towel"],
	"crypt":      ["bones", "candles", "leaves"],
}
## Items that sit against a wall (the rest can go anywhere free).
const WALL_ITEMS := ["suitcase", "boxes", "drum", "tires", "cart", "plant_pot", "basket", "detergent", "binder", "luggage", "hay", "toolbox"]

static func _free(b: LevelBuilder, c: Vector2i) -> bool:
	var chr := b.ch(c.x, c.y)
	if not LevelBuilder.FLOORS.contains(chr) or chr == "~":
		return false
	# keep doorways and the tile in front of them clear
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := b.ch(c.x + d.x, c.y + d.y)
		if n == "D" or n == "L" or n == "W":
			return false
	return true

static func _near_wall(b: LevelBuilder, c: Vector2i) -> Vector2i:
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		if b.ch(c.x + d.x, c.y + d.y) == "#":
			return d
	return Vector2i.ZERO

static func _dress_room(r: Room, b: LevelBuilder, layer: ClutterLayer, glow: ClutterLayer) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d,%d,%s" % [r.rect.position.x, r.rect.position.y, r.kind])
	var vocab: Array = VOCAB.get(r.kind, VOCAB.generic)
	var free: Array[Vector2i] = []
	var wall_free: Array[Vector2i] = []
	for c in r.cells:
		if _free(b, c):
			free.append(c)
			if _near_wall(b, c) != Vector2i.ZERO:
				wall_free.append(c)
	if free.is_empty():
		return
	var area := r.cells.size()
	# guest rooms get a little loose clutter; their furniture comes from RoomKits
	var n := clampi(area / (14 if r.kind == "guest_room" else 9), 1, 16)
	if r.kind in ["lot", "yard", "courtyard"]:
		n = clampi(area / 30, 2, 18)
	var used := {}
	for i in n:
		var kind: String = vocab[rng.randi() % vocab.size()]
		var pool: Array[Vector2i] = wall_free if (kind in WALL_ITEMS and not wall_free.is_empty()) else free
		var c: Vector2i = pool[rng.randi() % pool.size()]
		if used.has(c):
			continue
		used[c] = true
		var wall_dir := _near_wall(b, c)
		var pos := Vector2(c.x * T + 8, c.y * T + 8)
		var rot := rng.randf_range(-0.5, 0.5)
		if kind in WALL_ITEMS and wall_dir != Vector2i.ZERO:
			pos += Vector2(wall_dir) * 3.5
			rot = Vector2(wall_dir).angle() + PI * 0.5 + rng.randf_range(-0.12, 0.12)
		else:
			pos += Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
		layer.items.append([kind, pos, rot, rng.randi() % 4])
	# guest rooms are composed around the bed; lounges get their machines
	if r.kind == "guest_room":
		RoomKits.guest_room(r, b, layer, glow, used, rng)
		return
	if r.kind == "lounge":
		RoomKits.lounge(r, b, layer, glow, used, rng)
	else:
		RoomKitsMore.compose(r.kind, r, b, layer, glow, used, rng)
	# offices: a desk lamp with a warm pool of light
	if r.kind == "office" or r.kind == "lounge":
		for c in r.cells:
			if b.ch(c.x, c.y) == "b" and b.ch(c.x, c.y - 1) != "b":
				var side := Vector2i(1, 0) if _free(b, c + Vector2i(1, 0)) else Vector2i(-1, 0)
				var lc := c + side
				if _free(b, lc) and not used.has(lc):
					used[lc] = true
					var lp := Vector2(lc.x * T + 8, lc.y * T + 6)
					layer.items.append(["nightstand", lp, 0.0, rng.randi() % 4])
					glow.items.append(["glow", lp, 0.0, 0])
				break

# ------------------------------------------------------------------ walls
## Walls are drawn with a visible front face on their south side. Details go
## on those faces: room numbers next to doors, pictures in rooms, safety
## signage in corridors, pipes in industrial spaces.
static func _dress_walls(r: Room, b: LevelBuilder, layer: ClutterLayer, room_no: Array, wa: WallArt = null) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("w%d,%d" % [r.rect.position.x, r.rect.position.y])
	# visible faces: wall cell directly north of a room cell
	var faces: Array[Vector2i] = []
	for c in r.cells:
		var wc := c + Vector2i(0, -1)
		if b.ch(wc.x, wc.y) == "#" and b.ch(wc.x - 1, wc.y) != "D" and b.ch(wc.x + 1, wc.y) != "D":
			faces.append(wc)
	if faces.is_empty():
		return
	# the wall's visible front band is its bottom 6 px: hang things there
	var face_pos := func(wc: Vector2i) -> Vector2: return Vector2(wc.x * T + 8, wc.y * T + T - 2.5)
	# faces sorted left to right: placements below are composed, not random
	faces.sort_custom(func(a, c): return a.x < c.x if a.y == c.y else a.y < c.y)
	var mid_face: Vector2i = faces[faces.size() / 2]
	match r.kind:
		"guest_room":
			# one painting, centred over the headboard when the bed is against
			# the north wall, else centred on the room's north wall
			var bed_x := []
			for c in r.cells:
				if b.ch(c.x, c.y) == "b" and b.ch(c.x, c.y - 1) == "#":
					bed_x.append(c.x)
			var target: Vector2 = face_pos.call(mid_face)
			if not bed_x.is_empty():
				var bx := 0.0
				for x in bed_x:
					bx += float(x)
				bx /= bed_x.size()
				target = Vector2(bx * T + 8, mid_face.y * T + T - 2.5)
			if wa:
				wa.add_painting(target + Vector2(0, -4), r.id + room_no[0])
			else:
				layer.items.append(["picture", target, 0.0, rng.randi() % 4])
			# the wall AC unit goes at the far end of the same wall
			if faces.size() > 4:
				layer.items.append(["ac_unit", face_pos.call(faces[faces.size() - 1]), 0.0, 0])
		"corridor", "lobby":
			var k := 0
			for wc in faces:
				k += 1
				if k % 9 == 4:
					layer.items.append(["extinguisher" if rng.randf() < 0.5 else "notice", face_pos.call(wc), 0.0, rng.randi() % 4])
			if r.kind == "lobby":
				layer.items.append(["key_rack", face_pos.call(faces[maxi(0, faces.size() / 2 - 2)]), 0.0, 0])
				if wa:
					wa.add_neon(face_pos.call(mid_face) + Vector2(0, -4), "palm", Color("35e0ff"))
		"office":
			# a poster centred on the back wall, the calendar beside it
			if wa:
				wa.add_poster(face_pos.call(mid_face) + Vector2(0, -3), WallArt.POSTER_DEFS.keys()[(r.id * 3) % WallArt.POSTER_DEFS.size()])
			if faces.size() > 2:
				layer.items.append(["calendar", face_pos.call(faces[maxi(0, faces.size() / 2 - 2)]), 0.0, rng.randi() % 4])
		"lounge":
			# a neon sign centred on the wall, two posters framing it
			if wa:
				wa.add_neon(face_pos.call(mid_face) + Vector2(0, -4), ["cocktail", "star", "heart"][r.id % 3], WallArt.NEON_COLORS[r.id % WallArt.NEON_COLORS.size()])
				var keys := WallArt.POSTER_DEFS.keys()
				if faces.size() >= 7:
					wa.add_poster(face_pos.call(faces[faces.size() / 2 - 3]) + Vector2(0, -3), keys[(r.id * 2) % keys.size()])
					wa.add_poster(face_pos.call(faces[faces.size() / 2 + 3]) + Vector2(0, -3), keys[(r.id * 2 + 1) % keys.size()])
			else:
				layer.items.append(["poster", face_pos.call(mid_face), 0.0, rng.randi() % 4])
		"industrial", "laundry":
			# a pipe run along the longest face, with a gauge
			for wc in faces:
				layer.items.append(["pipe", face_pos.call(wc), 0.0, 0])
			layer.items.append(["gauge", face_pos.call(faces[faces.size() / 2]), 0.0, 0])
		"kennel":
			layer.items.append(["beware", face_pos.call(faces[rng.randi() % faces.size()]), 0.0, 0])
			layer.items.append(["leash_hook", face_pos.call(faces[rng.randi() % faces.size()]), 0.0, 0])
	# room numbers on the corridor side of guest room doors
	if r.kind == "guest_room":
		for d in r.doors:
			# the plate goes on the wall beside the door, on the side facing out
			var beside := d + Vector2i(1, 0) if b.ch(d.x + 1, d.y) == "#" else d + Vector2i(-1, 0)
			if b.ch(beside.x, beside.y) == "#":
				room_no[0] += 1
				layer.items.append(["room_no", Vector2(beside.x * T + 8, beside.y * T + 5), 0.0, room_no[0]])
			break
	# EXIT sign over doors that lead outside
	for d in r.doors:
		var outside := false
		for dd in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var z := b.zone_at_cell(d.x + dd.x, d.y + dd.y)
			if z == "exterior" and r.zone != "exterior":
				outside = true
		if outside and b.ch(d.x, d.y - 1) == "#":
			layer.items.append(["exit", Vector2(d.x * T + 8, (d.y - 1) * T + 6), 0.0, 0])

# ------------------------------------------------------------------ drawing
## One node draws a whole layer of dressing once (static: Godot keeps the
## draw list; nothing is redrawn per frame).
class ClutterLayer extends Node2D:
	var items: Array = []    ## [kind, pos, rot, variant]
	var boost := 1.0

	func _draw() -> void:
		for it in items:
			draw_set_transform(it[1], it[2], Vector2.ONE)
			_item(str(it[0]), int(it[3]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _b(c: Color) -> Color:
		return Color(c.r * boost, c.g * boost, c.b * boost, c.a) if boost != 1.0 else c

	func _item(k: String, v: int) -> void:
		var ink := Color(0.06, 0.03, 0.07)
		match k:
			"suitcase":
				draw_rect(Rect2(-5, -3.5, 10, 7), ink)
				var col: Color = [Color(0.45, 0.25, 0.15), Color(0.2, 0.25, 0.4), Color(0.5, 0.1, 0.15), Color(0.25, 0.3, 0.22)][v]
				draw_rect(Rect2(-4.5, -3, 9, 6), col)
				draw_rect(Rect2(-4.5, -3, 9, 1), col.lightened(0.25))
				draw_rect(Rect2(-1.5, -4.5, 3, 1.2), ink)
				if v % 2 == 0:   # open: clothes spilling out
					draw_rect(Rect2(-3.5, -2, 7, 4), Color(0.8, 0.75, 0.7))
					draw_rect(Rect2(-2, -1, 3, 2), Color(0.3, 0.55, 0.75))
			"clothes":
				var c1: Color = [Color(0.3, 0.45, 0.7), Color(0.8, 0.3, 0.45), Color(0.9, 0.88, 0.8), Color(0.2, 0.2, 0.22)][v]
				draw_colored_polygon(PackedVector2Array([Vector2(-5, -2), Vector2(-1, -4), Vector2(4, -2), Vector2(5, 2), Vector2(0, 4), Vector2(-4, 3)]), c1.darkened(0.15))
				draw_line(Vector2(-3, 0), Vector2(3, -1), c1.lightened(0.2), 1.0)
				draw_line(Vector2(-4, 2), Vector2(-6, 4), c1.darkened(0.2), 1.5)   # sleeve
			"towel":
				draw_rect(Rect2(-4, -2.5, 8, 5), [Color(0.9, 0.9, 0.95), Color(0.95, 0.7, 0.75), Color(0.6, 0.85, 0.9), Color(0.9, 0.85, 0.6)][v])
				draw_line(Vector2(-4, 1.5), Vector2(4, 1.5), Color(0, 0, 0, 0.18), 1.0)
			"pizza_box":
				draw_rect(Rect2(-5, -5, 10, 10), ink)
				draw_rect(Rect2(-4.5, -4.5, 9, 9), Color(0.82, 0.7, 0.5))
				draw_circle(Vector2.ZERO, 2.5, Color(0.75, 0.2, 0.15))
				draw_string(UIStyle.font_bold(), Vector2(-3.5, 4), "PIZZA", HORIZONTAL_ALIGNMENT_LEFT, -1, 3, Color(0.7, 0.1, 0.1))
			"ashtray":
				draw_circle(Vector2.ZERO, 2.4, Color(0.55, 0.6, 0.65))
				draw_circle(Vector2.ZERO, 1.6, Color(0.25, 0.25, 0.28))
				draw_line(Vector2(-1, 0), Vector2(2.5, -1), Color(0.95, 0.9, 0.8), 0.8)
			"butts":
				for i in 3:
					var p := Vector2(i * 2.5 - 2.5, (i % 2) * 1.5 - 0.5)
					draw_line(p, p + Vector2(1.5, 0.4).rotated(i), Color(0.95, 0.9, 0.8), 0.8)
					draw_rect(Rect2(p, Vector2(0.6, 0.6)), Color(0.85, 0.5, 0.2))
			"bottle":
				draw_line(Vector2(-3, 0), Vector2(2, 0), ink, 2.6)
				draw_line(Vector2(-3, 0), Vector2(2, 0), [Color(0.2, 0.5, 0.25), Color(0.5, 0.3, 0.1), Color(0.8, 0.8, 0.85), Color(0.2, 0.3, 0.5)][v], 1.8)
				draw_line(Vector2(2, 0), Vector2(4, 0), Color(0.9, 0.85, 0.7), 1.0)
			"cans":
				for i in 2 + v % 2:
					var p := Vector2(i * 3.0 - 2.0, (i % 2) * 2.0)
					draw_circle(p, 1.4, ink)
					draw_circle(p, 1.0, [Color(0.85, 0.15, 0.2), Color(0.8, 0.8, 0.85), Color(0.2, 0.4, 0.8)][(v + i) % 3])
			"magazine", "newspaper":
				var pc: Color = Color(0.9, 0.88, 0.8) if k == "newspaper" else [Color(0.9, 0.4, 0.6), Color(0.3, 0.7, 0.9), Color(0.95, 0.8, 0.2), Color(0.6, 0.4, 0.9)][v]
				draw_rect(Rect2(-4, -3, 8, 6), pc)
				for i in 3:
					draw_line(Vector2(-3, -1.5 + i * 1.5), Vector2(3, -1.5 + i * 1.5), Color(0, 0, 0, 0.3), 0.6)
			"shoes", "sandals":
				for sgn in [-1.0, 1.0]:
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					var sp := Vector2(sgn * 1.8, sgn * 0.5)
					var sc: Color = Color(0.15, 0.12, 0.1) if k == "shoes" else Color(0.9, 0.5, 0.2)
					draw_rect(Rect2(sp - Vector2(1.1, 2.2), Vector2(2.2, 4.4)), sc)
			"tray":
				draw_rect(Rect2(-5, -3.5, 10, 7), Color(0.7, 0.72, 0.76))
				draw_circle(Vector2(-2, 0), 2.0, Color(0.95, 0.95, 0.92))
				draw_circle(Vector2(-2, 0), 1.0, Color(0.6, 0.35, 0.2))
				draw_rect(Rect2(1.5, -2, 1.5, 4), Color(0.8, 0.8, 0.85))
			"rug":
				var rc: Color = [Color(0.55, 0.35, 0.2), Color(0.25, 0.35, 0.5), Color(0.5, 0.2, 0.25), Color(0.35, 0.45, 0.3)][v]
				draw_rect(Rect2(-8, -5, 16, 10), Color(rc, 0.85))
				draw_rect(Rect2(-6.5, -3.5, 13, 7), rc.lightened(0.15), false, 1.0)
			"cart":
				draw_rect(Rect2(-6, -3.5, 12, 7), ink)
				draw_rect(Rect2(-5.5, -3, 11, 6), Color(0.85, 0.85, 0.9))
				draw_rect(Rect2(-4, -2, 3, 4), Color(0.9, 0.9, 0.95))
				draw_rect(Rect2(0, -2, 4, 4), Color(0.6, 0.8, 0.85))
			"plant_pot":
				draw_circle(Vector2.ZERO, 3.2, Color(0.55, 0.3, 0.18))
				for i in 5:
					draw_line(Vector2.ZERO, Vector2.from_angle(i * 1.25) * 4.5, Color(0.2, 0.55, 0.28), 1.4)
			"luggage":
				draw_rect(Rect2(-4, -3, 8, 6), Color(0.35, 0.22, 0.12))
				draw_rect(Rect2(-2, -5, 5, 3), Color(0.5, 0.15, 0.2))
			"basket":
				draw_circle(Vector2.ZERO, 4.0, Color(0.7, 0.6, 0.4))
				draw_circle(Vector2.ZERO, 3.0, Color(0.85, 0.85, 0.9))
				draw_rect(Rect2(-1.5, -1, 3, 2), Color(0.5, 0.7, 0.85))
			"detergent":
				draw_rect(Rect2(-3, -2.5, 6, 5), Color(1.0, 0.55, 0.1))
				draw_rect(Rect2(-2, -1, 4, 2), Color(0.95, 0.95, 1.0))
			"puddle":
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
				draw_circle(Vector2.ZERO, 5.0, Color(0.35, 0.45, 0.65, 0.35))
				draw_arc(Vector2.ZERO, 5.0, PI, PI * 1.6, 6, Color(0.8, 0.9, 1.0, 0.35), 0.8)
			"papers":
				for i in 2 + v % 3:
					draw_set_transform(Vector2(i * 2.0 - 2.0, (i % 2) * 1.5), float(i) * 0.4 - 0.4, Vector2.ONE)
					draw_rect(Rect2(-2.5, -3, 5, 6), Color(0.92, 0.9, 0.84))
					draw_line(Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Color(0.2, 0.2, 0.3, 0.5), 0.5)
					draw_line(Vector2(-1.5, 0), Vector2(1.5, 0), Color(0.2, 0.2, 0.3, 0.5), 0.5)
			"boxes":
				draw_rect(Rect2(-5, -4, 10, 8), ink)
				draw_rect(Rect2(-4.5, -3.5, 9, 7), Color(0.66, 0.5, 0.3))
				draw_line(Vector2(-4.5, 0), Vector2(4.5, 0), Color(0.5, 0.36, 0.2), 1.0)
				if v % 2 == 0:
					draw_rect(Rect2(-1, -5.5, 6, 5), Color(0.6, 0.45, 0.27))
			"coffee":
				draw_circle(Vector2.ZERO, 1.8, Color(0.9, 0.9, 0.88))
				draw_circle(Vector2.ZERO, 1.2, Color(0.3, 0.18, 0.1))
				draw_arc(Vector2(4, 1), 2.0, 0, TAU, 10, Color(0.35, 0.2, 0.1, 0.4), 0.6)   # a ring stain
			"binder":
				draw_rect(Rect2(-3, -4, 6, 8), [Color(0.2, 0.3, 0.6), Color(0.6, 0.15, 0.2), Color(0.2, 0.2, 0.22), Color(0.2, 0.5, 0.3)][v])
			"trash":
				draw_circle(Vector2.ZERO, 3.5, Color(0.1, 0.1, 0.12))
				draw_circle(Vector2(-1, -1), 1.2, Color(0.3, 0.3, 0.35))
			"cards":
				for i in 4:
					draw_set_transform(Vector2(i * 1.5 - 2.0, 0), i * 0.5, Vector2.ONE)
					draw_rect(Rect2(-1.2, -1.7, 2.4, 3.4), Color(0.95, 0.95, 0.9))
					draw_rect(Rect2(-0.4, -0.4, 0.8, 0.8), Color(0.8, 0.1, 0.1) if i % 2 == 0 else ink)
			"glasses":
				draw_circle(Vector2(-1.5, 0), 1.3, Color(0.8, 0.9, 1.0, 0.6))
				draw_circle(Vector2(1.8, 0.6), 1.3, Color(0.8, 0.9, 1.0, 0.6))
				draw_circle(Vector2(1.8, 0.6), 0.7, Color(0.9, 0.7, 0.2, 0.7))
			"drum":
				draw_circle(Vector2.ZERO, 5.0, ink)
				draw_circle(Vector2.ZERO, 4.4, [Color(0.25, 0.4, 0.3), Color(0.5, 0.25, 0.15), Color(0.2, 0.3, 0.5), Color(0.5, 0.45, 0.2)][v])
				draw_arc(Vector2.ZERO, 3.0, 0, TAU, 12, Color(0, 0, 0, 0.3), 0.8)
				draw_circle(Vector2(1.5, -1.5), 0.8, Color(0.1, 0.1, 0.1))
			"toolbox":
				draw_rect(Rect2(-5, -2.5, 10, 5), ink)
				draw_rect(Rect2(-4.5, -2, 9, 4), Color(0.75, 0.12, 0.12))
				draw_line(Vector2(-2, -3), Vector2(2, -3), Color(0.3, 0.3, 0.3), 1.0)
			"oil":
				draw_set_transform(Vector2.ZERO, float(v), Vector2(1.0, 0.65))
				draw_circle(Vector2.ZERO, 5.5, Color(0.04, 0.03, 0.06, 0.55))
				draw_circle(Vector2(-1.5, -1), 2.2, Color(0.3, 0.2, 0.45, 0.3))
			"tires":
				for i in 1 + v % 2:
					var tp := Vector2(i * 3.0, -i * 2.0)
					draw_circle(tp, 4.5, Color(0.08, 0.08, 0.09))
					draw_circle(tp, 2.2, Color(0.2, 0.2, 0.22))
			"chain":
				for i in 5:
					draw_arc(Vector2(i * 1.8 - 4.0, sin(i) * 0.8), 0.9, 0, TAU, 6, Color(0.55, 0.55, 0.6), 0.6)
			"wrench":
				draw_line(Vector2(-4, 0), Vector2(3, 0), Color(0.65, 0.67, 0.72), 1.2)
				draw_arc(Vector2(4, 0), 1.3, -2.2, 2.2, 6, Color(0.65, 0.67, 0.72), 1.0)
			"bowl":
				draw_circle(Vector2.ZERO, 2.6, Color(0.65, 0.12, 0.15))
				draw_circle(Vector2.ZERO, 1.7, Color(0.45, 0.3, 0.15))
			"bone":
				draw_line(Vector2(-3, 0), Vector2(3, 0), Color(0.95, 0.92, 0.85), 1.2)
				for e in [Vector2(-3, -0.8), Vector2(-3, 0.8), Vector2(3, -0.8), Vector2(3, 0.8)]:
					draw_circle(e, 0.8, Color(0.95, 0.92, 0.85))
			"chew":
				draw_circle(Vector2.ZERO, 1.6, Color(0.9, 0.3, 0.3))
				draw_circle(Vector2(0.5, -0.5), 0.5, Color(1, 1, 1, 0.5))
			"hay":
				for i in 10:
					var a := float(i) * 0.7 + v
					draw_line(Vector2.from_angle(a) * 1.0, Vector2.from_angle(a + 0.3) * 4.5, Color(0.8, 0.68, 0.35, 0.8), 0.7)
			"leaves":
				for i in 3:
					draw_colored_polygon(PackedVector2Array([Vector2(i * 3 - 3, 0), Vector2(i * 3 - 2, -1.2), Vector2(i * 3 - 1, 0), Vector2(i * 3 - 2, 1.2)]), Color(0.35, 0.45, 0.2))
			"flamingo":
				draw_circle(Vector2.ZERO, 3.2, Color(1.0, 0.45, 0.65))
				draw_circle(Vector2.ZERO, 1.6, Color(0.75, 0.35, 0.5))
				draw_line(Vector2(2.5, -1), Vector2(4, -4), Color(1.0, 0.45, 0.65), 1.2)
			"hubcap":
				draw_circle(Vector2.ZERO, 3.0, Color(0.7, 0.72, 0.76))
				draw_circle(Vector2.ZERO, 1.2, Color(0.4, 0.42, 0.46))
			"scrap":
				draw_colored_polygon(PackedVector2Array([Vector2(-5, -2), Vector2(1, -4), Vector2(5, -1), Vector2(2, 3), Vector2(-4, 2)]), Color(0.45, 0.3, 0.22))
				draw_line(Vector2(-3, 0), Vector2(3, -2), Color(0.6, 0.4, 0.25), 1.0)
			"nightstand":
				draw_rect(Rect2(-4, -3.5, 8, 7), ink)
				draw_rect(Rect2(-3.5, -3, 7, 6), Color(0.45, 0.27, 0.14))
				draw_circle(Vector2(0, -0.5), 2.0, Color(0.95, 0.85, 0.55))    # lamp shade
				draw_circle(Vector2(0, -0.5), 0.8, Color(1, 1, 0.85))
			"glow":
				# fake light pool, drawn additively under everything
				for i in 5:
					draw_circle(Vector2.ZERO, 26.0 - i * 5.0, Color(0.55, 0.38, 0.16, 0.05))
			# ---- wall-face items (drawn on the wall's visible front band)
			"picture":
				draw_rect(Rect2(-4, -3, 8, 5), _b(Color(0.25, 0.16, 0.08)))
				var sky: Color = [Color(1.0, 0.5, 0.35), Color(0.35, 0.6, 0.9), Color(0.9, 0.4, 0.7), Color(0.4, 0.75, 0.6)][v]
				draw_rect(Rect2(-3.2, -2.3, 6.4, 3.6), _b(sky))
				draw_rect(Rect2(-3.2, 0.2, 6.4, 1.1), _b(sky.darkened(0.45)))
				if v % 2 == 0:   # a palm on the horizon
					draw_line(Vector2(1.5, 1.2), Vector2(1.5, -1.2), _b(Color(0.15, 0.3, 0.15)), 0.6)
					draw_line(Vector2(0.3, -1.6), Vector2(2.7, -1.0), _b(Color(0.15, 0.3, 0.15)), 0.6)
			"ac_unit":
				draw_rect(Rect2(-4, -3, 8, 5), _b(Color(0.75, 0.75, 0.72)))
				for i in 3:
					draw_line(Vector2(-3, -2 + i * 1.4), Vector2(3, -2 + i * 1.4), _b(Color(0.45, 0.45, 0.45)), 0.6)
			"extinguisher":
				draw_rect(Rect2(-1.5, -4, 3, 6), _b(Color(0.85, 0.1, 0.12)))
				draw_rect(Rect2(-1, -4.8, 2, 1), _b(Color(0.2, 0.2, 0.2)))
			"notice":
				draw_rect(Rect2(-3, -3.5, 6, 5), _b(Color(0.95, 0.92, 0.8)))
				draw_rect(Rect2(-3, -3.5, 6, 1.2), _b(Color(0.85, 0.2, 0.2)))
			"key_rack":
				draw_rect(Rect2(-6, -3, 12, 4), _b(Color(0.35, 0.2, 0.1)))
				for i in 6:
					draw_line(Vector2(-5 + i * 2, -2), Vector2(-5 + i * 2, 0.5 if i != 3 else -1.5), _b(Color(0.95, 0.8, 0.3)), 0.6)
			"calendar":
				draw_rect(Rect2(-3, -4, 6, 6), _b(Color(0.95, 0.95, 0.9)))
				draw_rect(Rect2(-3, -4, 6, 2.5), _b([Color(0.9, 0.5, 0.6), Color(0.4, 0.7, 0.9), Color(0.9, 0.8, 0.3), Color(0.5, 0.8, 0.5)][v]))
			"poster":
				draw_rect(Rect2(-3.5, -4.5, 7, 7), _b([Color(0.9, 0.2, 0.5), Color(0.2, 0.7, 0.9), Color(0.95, 0.75, 0.2), Color(0.5, 0.25, 0.8)][v]))
				draw_circle(Vector2(0, -1), 1.6, _b(Color(1, 0.95, 0.8)))
			"pipe":
				draw_rect(Rect2(-8, -1, 16, 2), _b(Color(0.45, 0.47, 0.5)))
				draw_rect(Rect2(-8, -1, 16, 0.6), _b(Color(0.7, 0.72, 0.75)))
			"gauge":
				draw_circle(Vector2(0, -3), 2.0, _b(Color(0.85, 0.85, 0.8)))
				draw_line(Vector2(0, -3), Vector2(1.2, -4), _b(Color(0.8, 0.1, 0.1)), 0.6)
			"beware":
				draw_rect(Rect2(-5, -4, 10, 5), _b(Color(0.95, 0.8, 0.15)))
				draw_string(UIStyle.font_bold(), Vector2(-4.5, -0.5), "DOG", HORIZONTAL_ALIGNMENT_LEFT, -1, 4, _b(Color(0.1, 0.05, 0.05)))
			"leash_hook":
				draw_circle(Vector2(0, -3), 0.8, _b(Color(0.6, 0.6, 0.65)))
				draw_line(Vector2(0, -3), Vector2(1, 1), _b(Color(0.65, 0.15, 0.15)), 0.8)
			"room_no":
				draw_rect(Rect2(-4, -2, 8, 4), _b(Color(0.12, 0.1, 0.1)))
				draw_string(UIStyle.font_bold(), Vector2(-3.5, 1.4), str(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 4, _b(Color(0.95, 0.8, 0.35)))
			"exit":
				draw_rect(Rect2(-5, -2.5, 10, 4), Color(0.1, 0.02, 0.02))
				draw_string(UIStyle.font_bold(), Vector2(-4.5, 1.0), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color(1.0, 0.2, 0.15))
			_:
				RoomKits.draw(self, k, v)
