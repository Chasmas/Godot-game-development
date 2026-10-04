class_name RoomKitsMore
extends RefCounted
## Composed layouts for every room type that isn't a motel guest room:
## warehouses and yards (Yermo, the prop store), kennels, offices, the
## studio's stage, dressing rooms and wardrobe, and the dream's mansion
## (ballroom, foyer, library, dining room, nursery, bathroom, crypt).
## Pieces go where they would be in a real room: in rows along walls,
## matched pairs, by the doors; not scattered.

## Level-specific room kinds, refining Dressing's own classification.
static func refine(r, b: LevelBuilder) -> String:
	var z: String = r.zone
	if b.data.get("nightmare", false):
		match z:
			"ballroom":
				return "ballroom"
			"foyer":
				return "foyer"
			"west_wing":
				return "dining" if int(r.furn.get("T", 0)) >= 10 else "library"
			"east_wing":
				match r.floor:
					"=":
						return "crypt"
					",":
						return "bathroom"
					_:
						return "nursery"
	if r.floor == "-":
		return "stage"
	if z == "wardrobe":
		return "dressing_room" if r.floor == "." else "wardrobe"
	if z == "offices":
		match r.floor:
			"_":
				return "control_room"
			"=":
				return "security_office"
	return r.kind

static func compose(kind: String, r, b: LevelBuilder, layer, glow, used: Dictionary, rng: RandomNumberGenerator) -> void:
	var north := _wall_cells(r, b, used, Vector2i(0, -1))
	var south := _wall_cells(r, b, used, Vector2i(0, 1))
	var west := _wall_cells(r, b, used, Vector2i(-1, 0))
	var east := _wall_cells(r, b, used, Vector2i(1, 0))
	match kind:
		"industrial":
			_row(layer, used, north, "pallet", 3, 0.0, Vector2(0, -2), rng)
			_row(layer, used, south, "barrel_trio", 5, 0.0, Vector2(0, 2), rng)
			_one(layer, used, west, "workbench", PI * 0.5, Vector2(-3, 0), rng)
			_one(layer, used, east, "forklift", -PI * 0.5, Vector2(2, 0), rng)
			_stripes_at_doors(r, layer)
		"kennel":
			_row(layer, used, south, "dog_bed", 3, 0.0, Vector2(0, 2), rng)
			_row(layer, used, north, "bowl", 2, 0.0, Vector2(0, -3), rng)
			_one(layer, used, west, "feed_sacks", PI * 0.5, Vector2(-2, 0), rng)
		"office", "security_office", "control_room":
			for c in r.cells:
				if b.ch(c.x, c.y) == "k" and b.ch(c.x, c.y + 1) != "k":
					var ch: Vector2i = c + Vector2i(0, 1)
					if RoomKits._ok(b, ch, used):
						used[ch] = true
						layer.items.append(["office_chair", RoomKits._px(ch) + Vector2(rng.randf_range(-2, 2), -2), rng.randf_range(-0.4, 0.4), rng.randi() % 4])
			var wall_kind := "filing"
			if kind == "security_office":
				wall_kind = "lockers"
			elif kind == "control_room":
				wall_kind = "monitor_stack"
			_row(layer, used, east if kind == "control_room" else north, wall_kind, 2, 0.0, Vector2(0, -2), rng, 4)
			_one(layer, used, south, "water_cooler", 0.0, Vector2(0, 2), rng)
			_one(layer, used, west, "coat_rack", 0.0, Vector2(-3, 0), rng)
		"stage":
			var n := 0
			for c in r.cells:
				if n >= 7:
					break
				if (c.x + c.y * 3) % 17 == 0 and RoomKits._ok(b, c, used):
					used[c] = true
					layer.items.append(["cable_run", RoomKits._px(c), rng.randf_range(0, TAU), rng.randi() % 4])
					n += 1
			_row(layer, used, north, "apple_box", 6, 0.0, Vector2(0, -2), rng, 6)
			_row(layer, used, south, "director_chair", 9, 0.0, Vector2(0, 1), rng, 3)
		"dressing_room":
			_row(layer, used, north, "makeup_table", 3, 0.0, Vector2(0, -3), rng, 4)
			_row(layer, used, south, "wig_head", 4, 0.0, Vector2(0, 2), rng, 3)
		"wardrobe":
			_row(layer, used, east, "shoe_rack", 3, PI * 0.5, Vector2(3, 0), rng, 4)
		"ballroom":
			_symmetric(layer, used, north, "candelabra_floor", Vector2(0, -2))
			_symmetric(layer, used, south, "candelabra_floor", Vector2(0, 2))
			_row(layer, used, west, "chair_ornate", 3, PI * 0.5, Vector2(-2, 0), rng)
			_row(layer, used, east, "chair_ornate", 3, -PI * 0.5, Vector2(2, 0), rng)
		"foyer":
			var c0 := Vector2i(roundi(r.rect.get_center().x), roundi(r.rect.get_center().y))
			layer.items.append(["rug_grand", RoomKits._px(c0), 0.0, 0])
			_symmetric(layer, used, north, "candelabra_floor", Vector2(0, -2))
		"library":
			_row(layer, used, south, "book_stack", 2, 0.0, Vector2(0, 2), rng)
			_one(layer, used, east, "armchair", -PI * 0.5, Vector2(2, 0), rng)
			_one(layer, used, west, "reading_lamp", 0.0, Vector2(-2, 0), rng)
		"dining":
			for c in r.cells:
				if b.ch(c.x, c.y) != "T" or c.x % 2 != 0:
					continue
				for d in [Vector2i(0, -1), Vector2i(0, 1)]:
					var nc: Vector2i = c + d
					if b.ch(nc.x, nc.y) != "T" and RoomKits._ok(b, nc, used):
						used[nc] = true
						layer.items.append(["chair_ornate", RoomKits._px(nc) - Vector2(d), Vector2(-d).angle() + PI * 0.5, 0])
		"nursery":
			_one(layer, used, north, "crib", 0.0, Vector2(0, -2), rng)
			_one(layer, used, east, "rocking_horse", -PI * 0.5, Vector2(2, 0), rng)
			_row(layer, used, south, "toy_car", 3, 0.0, Vector2(0, 2), rng, 3)
			_row(layer, used, west, "teddy", 4, 0.0, Vector2(-2, 0), rng, 2)
		"bathroom":
			_one(layer, used, north, "bathtub", 0.0, Vector2(0, -2), rng)
			_one(layer, used, south, "rubber_duck", 0.0, Vector2.ZERO, rng)
		"crypt":
			_row(layer, used, south, "candles", 3, 0.0, Vector2(0, 1), rng)
			_row(layer, used, north, "candles", 4, 0.0, Vector2(0, -1), rng)

static func _wall_cells(r, b: LevelBuilder, used: Dictionary, dir: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in r.cells:
		if RoomKits._ok(b, c, used) and b.ch(c.x + dir.x, c.y + dir.y) == "#":
			out.append(c)
	if dir.y != 0:
		out.sort_custom(func(a, z): return a.x < z.x)
	else:
		out.sort_custom(func(a, z): return a.y < z.y)
	return out

## Every `step` cells along a wall, evenly, up to `cap`.
static func _row(layer, used: Dictionary, cells: Array[Vector2i], kind: String, step: int, rot: float, nudge: Vector2, rng: RandomNumberGenerator, cap := 99) -> void:
	var n := 0
	for i in range(1, cells.size() - 1, maxi(1, step)):
		var c: Vector2i = cells[i]
		if used.has(c):
			continue
		used[c] = true
		layer.items.append([kind, RoomKits._px(c) + nudge, rot, rng.randi() % 4])
		n += 1
		if n >= cap:
			break

static func _one(layer, used: Dictionary, cells: Array[Vector2i], kind: String, rot: float, nudge: Vector2, rng: RandomNumberGenerator) -> void:
	if cells.is_empty():
		return
	var c: Vector2i = cells[cells.size() / 2]
	if used.has(c):
		return
	used[c] = true
	layer.items.append([kind, RoomKits._px(c) + nudge, rot, rng.randi() % 4])

## A matched pair a third of the way in from each end of a wall.
static func _symmetric(layer, used: Dictionary, cells: Array[Vector2i], kind: String, nudge: Vector2) -> void:
	if cells.size() < 5:
		return
	for c in [cells[cells.size() / 3], cells[cells.size() - 1 - cells.size() / 3]]:
		if not used.has(c):
			used[c] = true
			layer.items.append([kind, RoomKits._px(c) + nudge, 0.0, 0])

static func _stripes_at_doors(r, layer) -> void:
	for d in r.doors:
		for o in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var c: Vector2i = d + o
			if r.cells.has(c):
				layer.items.append(["hazard_stripes", RoomKits._px(c), 0.0 if o.y != 0 else PI * 0.5, 0])

## Painted versions (tools/art, ArtLib.sprite) of dressing pieces: kind ->
## [sprite, size in world px]. Drawn in the piece's own orientation, fitted
## inside that size; the hand-drawn version is the fallback.
const PAINTED := {
	"office_chair": ["office_chair", Vector2(10, 10)], "armchair": ["armchair", Vector2(12, 11)],
	"jukebox": ["jukebox", Vector2(13, 11)], "pinball": ["pinball", Vector2(9, 14)],
	"pallet": ["pallet", Vector2(15, 11)], "workbench": ["workbench", Vector2(19, 9)],
	"tires": ["tyre_stack", Vector2(10, 10)],
	"chair_ornate": ["wooden_chair", Vector2(9, 9)], "filing": ["filing_cabinet", Vector2(10, 11)],
	"forklift": ["hq_forklift", Vector2(18, 15)], "makeup_table": ["hq_makeup_station", Vector2(16, 11)],
	"monitor_stack": ["tv_crt", Vector2(11, 9)], "director_chair": ["director_chair", Vector2(10, 9)],
	"apple_box": ["studio_apple_box", Vector2(9, 7)], "coat_rack": ["clothes_rack", Vector2(10, 10)],
	"barrel_trio": ["yard_oil_barrel_cluster", Vector2(15, 13)], "reading_lamp": ["floor_lamp", Vector2(8, 8)],
}

static func draw_painted(ci: CanvasItem, k: String) -> bool:
	if not PAINTED.has(k):
		return false
	var tex := ArtLib.sprite(str(PAINTED[k][0]))
	if tex == null:
		return false
	var box: Vector2 = PAINTED[k][1]
	var ta := float(tex.get_width()) / float(tex.get_height())
	var sz := Vector2(box.x, box.x / ta) if box.x / box.y < ta else Vector2(box.y * ta, box.y)
	ci.draw_texture_rect(tex, Rect2(-sz * 0.5 + Vector2(1.0, 1.5), sz), false, Color(0, 0, 0, 0.3))   # contact shadow
	ci.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
	return true

## Drawings for the pieces above. Returns false for kinds it doesn't know.
static func draw(ci: CanvasItem, k: String, v: int) -> bool:
	if draw_painted(ci, k):
		return true
	var ink := Color(0.06, 0.03, 0.07)
	match k:
		"pallet":
			ci.draw_rect(Rect2(-7, -5, 14, 10), ink)
			for i in 4:
				ci.draw_rect(Rect2(-6.5, -4.5 + i * 2.5, 13, 1.8), Color(0.62, 0.48, 0.3).darkened(0.1 * (i % 2)))
			if v % 2 == 0:
				ci.draw_rect(Rect2(-5, -4, 10, 8), Color(0.55, 0.42, 0.28))
				ci.draw_line(Vector2(-5, 0), Vector2(5, 0), Color(0.85, 0.75, 0.5), 0.6)
		"barrel_trio":
			for i in 3:
				var p := Vector2(-4 + i * 4, (i % 2) * 3 - 1.5)
				var col: Color = [Color(0.2, 0.4, 0.7), Color(0.75, 0.2, 0.15), Color(0.3, 0.45, 0.25), Color(0.8, 0.6, 0.15)][(v + i) % 4]
				ci.draw_circle(p, 3.2, ink)
				ci.draw_circle(p, 2.8, col)
				ci.draw_arc(p, 1.8, 0, TAU, 10, col.darkened(0.3), 0.6)
		"workbench":
			ci.draw_rect(Rect2(-9, -4, 18, 8), ink)
			ci.draw_rect(Rect2(-8.5, -3.5, 17, 7), Color(0.5, 0.35, 0.2))
			ci.draw_rect(Rect2(-6, -2, 4, 2), Color(0.7, 0.7, 0.75))
			ci.draw_line(Vector2(1, -1), Vector2(6, 1), Color(0.75, 0.2, 0.15), 1.0)
			ci.draw_circle(Vector2(6, 2), 1.0, Color(0.9, 0.8, 0.3))
		"forklift":
			ci.draw_rect(Rect2(-6, -5, 12, 9), ink)
			ci.draw_rect(Rect2(-5.5, -4.5, 11, 8), Color(0.95, 0.75, 0.15))
			ci.draw_rect(Rect2(-3, -3, 6, 4), Color(0.2, 0.2, 0.22))
			ci.draw_line(Vector2(-4, 4), Vector2(-4, 9), Color(0.5, 0.5, 0.55), 1.2)
			ci.draw_line(Vector2(4, 4), Vector2(4, 9), Color(0.5, 0.5, 0.55), 1.2)
		"hazard_stripes":
			for i in 5:
				ci.draw_line(Vector2(-8 + i * 4, -3), Vector2(-5 + i * 4, 3), Color(0.95, 0.8, 0.1, 0.8), 1.5)
		"dog_bed":
			ci.draw_circle(Vector2.ZERO, 5.0, ink)
			ci.draw_circle(Vector2.ZERO, 4.5, [Color(0.6, 0.2, 0.2), Color(0.3, 0.4, 0.6), Color(0.5, 0.45, 0.3), Color(0.35, 0.5, 0.35)][v])
			ci.draw_circle(Vector2.ZERO, 3.0, Color(0.85, 0.8, 0.7))
		"feed_sacks":
			for i in 2:
				ci.draw_rect(Rect2(-5 + i * 4, -3 - i, 6, 7), ink)
				ci.draw_rect(Rect2(-4.5 + i * 4, -2.5 - i, 5, 6), Color(0.8, 0.72, 0.5))
				ci.draw_rect(Rect2(-4 + i * 4, -1 - i, 4, 1.5), Color(0.7, 0.2, 0.15))
		"office_chair":
			ci.draw_circle(Vector2.ZERO, 3.5, ink)
			ci.draw_circle(Vector2.ZERO, 3.0, Color(0.2, 0.2, 0.24))
			ci.draw_rect(Rect2(-3, 2, 6, 2), Color(0.15, 0.15, 0.18))
		"filing":
			ci.draw_rect(Rect2(-4, -4, 8, 8), ink)
			ci.draw_rect(Rect2(-3.5, -3.5, 7, 7), Color(0.55, 0.58, 0.6))
			for i in 3:
				ci.draw_line(Vector2(-1, -2 + i * 2.2), Vector2(1, -2 + i * 2.2), Color(0.2, 0.2, 0.22), 0.8)
		"lockers":
			for i in 3:
				ci.draw_rect(Rect2(-6 + i * 4, -4, 4, 8), ink)
				ci.draw_rect(Rect2(-5.5 + i * 4, -3.5, 3, 7), Color(0.35, 0.45, 0.55))
				ci.draw_line(Vector2(-4.5 + i * 4, -2), Vector2(-3.5 + i * 4, -2), Color(0.8, 0.8, 0.85), 0.5)
		"monitor_stack":
			for i in 2:
				ci.draw_rect(Rect2(-5 + i * 5, -3, 5, 5), ink)
				ci.draw_rect(Rect2(-4.5 + i * 5, -2.5, 4, 3.5), [Color(0.2, 0.5, 0.6), Color(0.5, 0.2, 0.5)][i])
		"water_cooler":
			ci.draw_rect(Rect2(-2.5, -2.5, 5, 5), Color(0.9, 0.9, 0.92))
			ci.draw_circle(Vector2(0, -0.5), 2.2, Color(0.5, 0.75, 0.95, 0.9))
		"coat_rack":
			ci.draw_circle(Vector2.ZERO, 1.2, Color(0.35, 0.22, 0.12))
			for i in 4:
				ci.draw_line(Vector2.ZERO, Vector2.from_angle(i * TAU / 4.0 + 0.4) * 3.5, Color(0.35, 0.22, 0.12), 0.8)
			ci.draw_circle(Vector2(2, 1), 2.0, [Color(0.6, 0.45, 0.3), Color(0.3, 0.3, 0.35), Color(0.7, 0.2, 0.2), Color(0.5, 0.5, 0.4)][v])
		"cable_run":
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(Vector2(-12 + i * 3, sin(i * 1.3 + v) * 2.5))
			ci.draw_polyline(pts, Color(0.08, 0.08, 0.1), 1.2)
		"apple_box":
			ci.draw_rect(Rect2(-4, -2.5, 8, 5), ink)
			ci.draw_rect(Rect2(-3.5, -2, 7, 4), Color(0.72, 0.58, 0.38))
			ci.draw_rect(Rect2(-1.5, -1, 3, 2), Color(0.3, 0.2, 0.1))
		"director_chair":
			ci.draw_rect(Rect2(-4, -3, 8, 6), ink)
			ci.draw_rect(Rect2(-3.5, -2.5, 7, 5), Color(0.5, 0.35, 0.2))
			ci.draw_rect(Rect2(-3.5, -2.5, 7, 2), Color(0.1, 0.1, 0.12))
		"makeup_table":
			ci.draw_rect(Rect2(-7, -3, 14, 6), ink)
			ci.draw_rect(Rect2(-6.5, -2.5, 13, 5), Color(0.9, 0.85, 0.8))
			for i in 5:
				ci.draw_circle(Vector2(-6 + i * 3, -3), 0.9, Color(1.0, 0.95, 0.7))
			ci.draw_circle(Vector2(-2, 0.5), 0.8, Color(0.85, 0.2, 0.3))
			ci.draw_rect(Rect2(1, 0, 3, 1), Color(0.3, 0.25, 0.3))
		"wig_head":
			ci.draw_circle(Vector2.ZERO, 2.5, Color(0.9, 0.85, 0.8))
			ci.draw_arc(Vector2.ZERO, 2.8, PI, TAU, 10, [Color(0.6, 0.3, 0.15), Color(0.95, 0.85, 0.4), Color(0.15, 0.1, 0.1), Color(0.8, 0.3, 0.6)][v], 2.0)
		"shoe_rack":
			ci.draw_rect(Rect2(-6, -2, 12, 4), Color(0.4, 0.28, 0.18))
			for i in 4:
				ci.draw_rect(Rect2(-5.5 + i * 3, -1.5, 2, 3), [Color(0.8, 0.1, 0.2), Color(0.1, 0.1, 0.12), Color(0.9, 0.85, 0.7), Color(0.6, 0.4, 0.2)][(i + v) % 4])
		"candelabra_floor":
			var tex: Texture2D = ArtLib.sprite("candelabra")
			if tex:
				ci.draw_texture_rect(tex, Rect2(-8, -8, 16, 16), false)
			else:
				for i in 3:
					ci.draw_circle(Vector2(-3 + i * 3, 0), 1.0, Color(1.0, 0.8, 0.3))
		"chair_ornate":
			ci.draw_rect(Rect2(-3.5, -3.5, 7, 7), ink)
			ci.draw_rect(Rect2(-3, -3, 6, 6), Color(0.45, 0.1, 0.12))
			ci.draw_rect(Rect2(-3, -3, 6, 2), Color(0.55, 0.4, 0.15))
		"rug_grand":
			var rug_tex := ArtLib.sprite("hq_persian_rug")
			if rug_tex:
				ci.draw_texture_rect(rug_tex, Rect2(-40, -25, 80, 50), false)
				return true
			ci.draw_rect(Rect2(-30, -18, 60, 36), Color(0.35, 0.05, 0.08))
			ci.draw_rect(Rect2(-27, -15, 54, 30), Color(0.55, 0.1, 0.12))
			ci.draw_rect(Rect2(-20, -9, 40, 18), Color(0.7, 0.55, 0.2), false, 1.0)
			ci.draw_circle(Vector2.ZERO, 6.0, Color(0.7, 0.55, 0.2, 0.6))
		"book_stack":
			for i in 3:
				ci.draw_rect(Rect2(-3, -1 - i * 1.6, 6, 1.4), [Color(0.5, 0.15, 0.15), Color(0.15, 0.3, 0.45), Color(0.4, 0.35, 0.15)][i])
		"reading_lamp":
			ci.draw_circle(Vector2.ZERO, 3.0, Color(0.95, 0.85, 0.55))
			ci.draw_circle(Vector2.ZERO, 1.2, Color(1, 1, 0.85))
		"crib":
			ci.draw_rect(Rect2(-7, -4, 14, 8), Color(0.9, 0.88, 0.85))
			ci.draw_rect(Rect2(-6, -3, 12, 6), Color(0.75, 0.8, 0.9))
			for i in 6:
				ci.draw_line(Vector2(-6 + i * 2.4, -4), Vector2(-6 + i * 2.4, -3), Color(0.8, 0.78, 0.75), 0.6)
		"rocking_horse":
			ci.draw_arc(Vector2(0, 2), 6.0, PI * 1.15, PI * 1.85, 10, Color(0.5, 0.32, 0.18), 1.2)
			ci.draw_rect(Rect2(-3.5, -3, 7, 3), Color(0.95, 0.9, 0.85))
			ci.draw_circle(Vector2(3.5, -3.5), 1.4, Color(0.95, 0.9, 0.85))
		"bathtub":
			ci.draw_rect(Rect2(-9, -5, 18, 10), ink)
			ci.draw_rect(Rect2(-8.5, -4.5, 17, 9), Color(0.92, 0.92, 0.95))
			ci.draw_rect(Rect2(-7, -3, 14, 6), Color(0.55, 0.12, 0.14) if v == 0 else Color(0.6, 0.75, 0.85))
			ci.draw_circle(Vector2(7, 0), 0.8, Color(0.7, 0.7, 0.72))
		"rubber_duck":
			ci.draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.85, 0.1))
			ci.draw_circle(Vector2(1.5, -1), 1.2, Color(1.0, 0.85, 0.1))
			ci.draw_rect(Rect2(2.4, -1.2, 1.2, 0.6), Color(1.0, 0.5, 0.1))
		_:
			return false
	return true
