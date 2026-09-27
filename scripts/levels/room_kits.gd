class_name RoomKits
extends RefCounted
## Composed rooms. Instead of scattering clutter, a guest room is laid out
## around its bed the way a motel room is: nightstands either side of the
## headboard, a rug at the foot, the dresser and TV on the far wall facing
## the bed, an armchair and side table in a free corner. Then the room gets
## a *story* - who is staying in it - and that decides the props left out:
##   party     cans, pizza, cards, a boombox, bottles by the bed
##   business  briefcase, a tie on the bed, papers, a clock radio
##   romance   roses, champagne in an ice bucket, candles, a heart balloon
##   creepy    VHS tapes, Polaroids on the floor, a candle circle
##   family    a toy car, crayons, a cot-side teddy, a travel cot
##   fishing   a tackle box, a rod against the wall, a cooler
## Lounges get a jukebox, stools and a pinball machine along a wall.
## Everything here is decoration (no collision); drawn by Dressing's layer.

const THEMES := ["party", "business", "romance", "creepy", "family", "fishing"]
const THEME_PROPS := {
	"party": ["cans", "pizza_box", "cards", "boombox", "bottle", "cans", "bottle"],
	"business": ["briefcase", "tie", "papers", "coffee", "papers"],
	"romance": ["roses", "champagne", "candles", "balloon", "roses"],
	"creepy": ["vhs", "polaroids", "candles", "vhs", "polaroids"],
	"family": ["toy_car", "crayons", "teddy", "toy_car"],
	"fishing": ["tackle", "rod", "cooler", "cans"],
}

## Lay out a guest room. `used` marks taken cells; returns nothing, fills the layers.
static func guest_room(r, b: LevelBuilder, layer, glow, used: Dictionary, rng: RandomNumberGenerator) -> void:
	var beds: Array[Vector2i] = []
	for c in r.cells:
		if b.ch(c.x, c.y) == "b":
			beds.append(c)
	if beds.is_empty():
		return
	var lo: Vector2i = beds[0]
	var hi: Vector2i = beds[0]
	for c in beds:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var bed := Rect2i(lo, hi - lo + Vector2i.ONE)
	# the headboard is against a wall: find which side
	var head := Vector2i(-1, 0)
	var best := -1
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var walls := 0
		for c in beds:
			var n: Vector2i = c + d
			if b.ch(n.x, n.y) == "#":
				walls += 1
		if walls > best:
			best = walls
			head = d
	var foot := -head
	# along the headboard: perpendicular to the head direction
	var side := Vector2i(0, 1) if head.x != 0 else Vector2i(1, 0)
	# nightstands either side of the headboard, a lamp's warm pool on each
	var head_row: Array[Vector2i] = []
	for c in beds:
		if b.ch(c.x + head.x, c.y + head.y) != "b":
			head_row.append(c)
	var ends := _row_ends(head_row, side)
	for e in [ends[0] - side, ends[1] + side]:
		if _ok(b, e, used):
			used[e] = true
			var lp := _px(e) + Vector2(head) * 2.0
			layer.items.append(["nightstand", lp, 0.0, rng.randi() % 4])
			glow.items.append(["glow", lp, 0.0, 0])
	# rug at the foot of the bed
	var foot_mid := Vector2(bed.get_center()) * 16.0 + Vector2(foot) * (Vector2(bed.size).dot(Vector2(absi(foot.x), absi(foot.y))) * 8.0 + 10.0)
	layer.items.append(["rug_big", foot_mid, Vector2(foot).angle() + PI * 0.5, rng.randi() % 4])
	# dresser + TV on the far wall, facing the bed
	var probe := Vector2i(roundi(bed.get_center().x), roundi(bed.get_center().y))
	for i in 12:
		var nx: Vector2i = probe + foot
		if b.ch(nx.x, nx.y) == "#" or not r.cells.has(nx):
			break
		probe = nx
	if probe != Vector2i(roundi(bed.get_center().x), roundi(bed.get_center().y)) and _ok(b, probe, used) and not bed.has_point(probe):
		used[probe] = true
		layer.items.append(["dresser_tv", _px(probe) + Vector2(foot) * 3.0, Vector2(-foot).angle() + PI * 0.5, rng.randi() % 4])
	# an armchair and side table in a free corner
	for c in r.cells:
		var wx := b.ch(c.x - 1, c.y) == "#" or b.ch(c.x + 1, c.y) == "#"
		var wy := b.ch(c.x, c.y - 1) == "#" or b.ch(c.x, c.y + 1) == "#"
		if wx and wy and _ok(b, c, used) and (c - bed.get_center()).length() > 2.5:
			used[c] = true
			var face := Vector2(bed.get_center() * 16.0) - _px(c)
			layer.items.append(["armchair", _px(c), face.angle() + PI * 0.5, rng.randi() % 4])
			var t2: Vector2i = c + (Vector2i(1, 0) if b.ch(c.x + 1, c.y) != "#" else Vector2i(-1, 0))
			if _ok(b, t2, used):
				used[t2] = true
				layer.items.append(["side_table", _px(t2), 0.0, rng.randi() % 4])
			break
	# who is staying here: their things, near the bed and the chair
	var theme: String = THEMES[rng.randi() % THEMES.size()]
	var props: Array = THEME_PROPS[theme]
	var near: Array[Vector2i] = []
	for c in r.cells:
		if _ok(b, c, used) and (c - bed.get_center()).length() < 3.5:
			near.append(c)
	for i in mini(props.size(), near.size()):
		var c: Vector2i = near[rng.randi() % near.size()]
		if used.has(c):
			continue
		used[c] = true
		var kind: String = props[i]
		var rot := rng.randf_range(-0.6, 0.6)
		if kind == "rod" or kind == "balloon":
			rot = 0.0
		layer.items.append([kind, _px(c) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), rot, rng.randi() % 4])

## Lounges: a jukebox and a pinball machine against the walls, stools in a row.
static func lounge(r, b: LevelBuilder, layer, glow, used: Dictionary, rng: RandomNumberGenerator) -> void:
	var wall_cells: Array[Vector2i] = []
	for c in r.cells:
		if _ok(b, c, used) and b.ch(c.x, c.y - 1) == "#":
			wall_cells.append(c)
	if wall_cells.size() < 3:
		return
	wall_cells.sort_custom(func(a, c): return a.x < c.x)
	var jb: Vector2i = wall_cells[0]
	used[jb] = true
	layer.items.append(["jukebox", _px(jb) + Vector2(0, -3), 0.0, 0])
	glow.items.append(["glow", _px(jb), 0.0, 0])
	var pb: Vector2i = wall_cells[wall_cells.size() - 1]
	if not used.has(pb):
		used[pb] = true
		layer.items.append(["pinball", _px(pb) + Vector2(0, -2), 0.0, rng.randi() % 4])

static func _row_ends(row: Array[Vector2i], side: Vector2i) -> Array:
	var a: Vector2i = row[0]
	var z: Vector2i = row[0]
	for c in row:
		if Vector2(c - a).dot(Vector2(side)) < 0:
			a = c
		if Vector2(c - z).dot(Vector2(side)) > 0:
			z = c
	return [a, z]

static func _ok(b: LevelBuilder, c: Vector2i, used: Dictionary) -> bool:
	return not used.has(c) and Dressing._free(b, c) and not LevelBuilder.FURN.has(b.ch(c.x, c.y)) and not LevelBuilder.PROPS.has(b.ch(c.x, c.y))

static func _px(c: Vector2i) -> Vector2:
	return Vector2(c.x * 16 + 8, c.y * 16 + 8)

# ------------------------------------------------------------------ drawing
## Props the Dressing layer doesn't know itself. Top-down, small, one ink
## outline and two tones each, like the rest of the clutter.
static func draw(ci: CanvasItem, k: String, v: int) -> void:
	if RoomKitsMore.draw(ci, k, v):
		return
	var ink := Color(0.06, 0.03, 0.07)
	match k:
		"dresser_tv":
			ci.draw_rect(Rect2(-7, -3.5, 14, 7), ink)
			ci.draw_rect(Rect2(-6.5, -3, 13, 6), [Color(0.45, 0.28, 0.15), Color(0.35, 0.22, 0.14), Color(0.55, 0.4, 0.25), Color(0.3, 0.2, 0.18)][v])
			for i in 3:
				ci.draw_line(Vector2(-6, -1 + i * 2), Vector2(6, -1 + i * 2), Color(0, 0, 0, 0.25), 0.6)
			ci.draw_rect(Rect2(-3.5, -3, 7, 5), ink)                  # the TV
			ci.draw_rect(Rect2(-3, -2.6, 6, 3.4), Color(0.25, 0.4, 0.5))
			ci.draw_rect(Rect2(-2.6, -2.3, 2, 1), Color(0.7, 0.9, 1.0, 0.6))
			ci.draw_line(Vector2(-2, -3), Vector2(-3.5, -5.5), Color(0.6, 0.6, 0.65), 0.6)   # rabbit ears
			ci.draw_line(Vector2(2, -3), Vector2(3.5, -5.5), Color(0.6, 0.6, 0.65), 0.6)
		"armchair":
			var c: Color = [Color(0.55, 0.35, 0.2), Color(0.35, 0.5, 0.45), Color(0.6, 0.25, 0.35), Color(0.45, 0.4, 0.55)][v]
			ci.draw_rect(Rect2(-5.5, -5, 11, 10), ink)
			ci.draw_rect(Rect2(-5, -4.5, 10, 9), c.darkened(0.2))
			ci.draw_rect(Rect2(-3.5, -1.5, 7, 5.5), c)
			ci.draw_rect(Rect2(-3.5, -4.5, 7, 2.5), c.darkened(0.35))   # back
		"side_table":
			ci.draw_circle(Vector2.ZERO, 3.5, ink)
			ci.draw_circle(Vector2.ZERO, 3.0, Color(0.5, 0.32, 0.18))
			ci.draw_circle(Vector2(1, -0.5), 1.0, Color(0.9, 0.9, 0.85))   # a glass
		"rug_big":
			var rc: Color = [Color(0.55, 0.2, 0.25), Color(0.25, 0.35, 0.5), Color(0.55, 0.45, 0.2), Color(0.35, 0.25, 0.45)][v]
			ci.draw_rect(Rect2(-12, -6, 24, 12), rc.darkened(0.25))
			ci.draw_rect(Rect2(-11, -5, 22, 10), rc)
			ci.draw_rect(Rect2(-8, -2.5, 16, 5), rc.lightened(0.15), false, 0.8)
			for i in 6:
				ci.draw_line(Vector2(-12, -5 + i * 2), Vector2(-13.5, -5 + i * 2), rc.lightened(0.3), 0.5)
				ci.draw_line(Vector2(12, -5 + i * 2), Vector2(13.5, -5 + i * 2), rc.lightened(0.3), 0.5)
		"boombox":
			ci.draw_rect(Rect2(-5, -2.5, 10, 5), ink)
			ci.draw_rect(Rect2(-4.5, -2, 9, 4), Color(0.3, 0.3, 0.34))
			ci.draw_circle(Vector2(-2.5, 0), 1.5, Color(0.12, 0.12, 0.14))
			ci.draw_circle(Vector2(2.5, 0), 1.5, Color(0.12, 0.12, 0.14))
			ci.draw_line(Vector2(-3, -2.5), Vector2(3, -2.5), Color(0.7, 0.7, 0.75), 0.6)
		"briefcase":
			ci.draw_rect(Rect2(-5, -3, 10, 6), ink)
			ci.draw_rect(Rect2(-4.5, -2.5, 9, 5), Color(0.3, 0.18, 0.1))
			ci.draw_rect(Rect2(-1.5, -3.8, 3, 1.2), Color(0.75, 0.6, 0.3))
			ci.draw_rect(Rect2(-4, -0.3, 8, 0.6), Color(0.75, 0.6, 0.3))
		"tie":
			var tc: Color = [Color(0.7, 0.1, 0.15), Color(0.2, 0.3, 0.6), Color(0.8, 0.7, 0.2), Color(0.2, 0.5, 0.3)][v]
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-1, -5), Vector2(1, -5), Vector2(1.8, 3), Vector2(0, 5), Vector2(-1.8, 3)]), tc)
			ci.draw_line(Vector2(-1.2, -1), Vector2(1.2, 0), tc.lightened(0.3), 0.6)
		"roses":
			for i in 3:
				var p := Vector2(i * 2.2 - 2.2, (i % 2) * 1.5 - 1.0)
				ci.draw_line(p, p + Vector2(0.5, 4), Color(0.2, 0.45, 0.2), 0.6)
				ci.draw_circle(p, 1.4, Color(0.8, 0.1, 0.2))
				ci.draw_circle(p + Vector2(-0.3, -0.3), 0.6, Color(0.95, 0.3, 0.4))
		"champagne":
			ci.draw_circle(Vector2.ZERO, 3.2, Color(0.7, 0.72, 0.78))    # ice bucket
			ci.draw_circle(Vector2.ZERO, 2.4, Color(0.85, 0.9, 1.0))
			ci.draw_circle(Vector2(0.5, -0.5), 1.1, Color(0.15, 0.35, 0.2))   # bottle neck
			ci.draw_circle(Vector2(0.5, -0.5), 0.5, Color(0.9, 0.8, 0.3))
		"candles":
			for i in 5:
				var p2 := Vector2.from_angle(i * TAU / 5.0) * 4.0
				ci.draw_circle(p2, 1.0, Color(0.95, 0.92, 0.85))
				ci.draw_circle(p2, 0.5, Color(1.0, 0.7, 0.2))
		"balloon":
			ci.draw_line(Vector2(0, 2), Vector2(1, 7), Color(0.9, 0.9, 0.9), 0.5)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 3), Vector2(-3.5, -1), Vector2(-2.5, -3.5), Vector2(0, -2), Vector2(2.5, -3.5), Vector2(3.5, -1)]), Color(0.95, 0.2, 0.45))
			ci.draw_circle(Vector2(-1.5, -2), 0.6, Color(1, 0.7, 0.8))
		"vhs":
			for i in 3:
				var o := Vector2(i * 1.2, -i * 1.4)
				ci.draw_rect(Rect2(o + Vector2(-4, -2.5), Vector2(8, 5)), ink)
				ci.draw_rect(Rect2(o + Vector2(-3.5, -2), Vector2(7, 4)), Color(0.12, 0.1, 0.12))
				ci.draw_rect(Rect2(o + Vector2(-3, -1.5), Vector2(6, 1.2)), [Color(0.95, 0.9, 0.8), Color(1.0, 0.8, 0.3), Color(0.9, 0.3, 0.4)][i])
		"polaroids":
			for i in 4:
				var o2 := Vector2(i * 2.5 - 4.0, (i % 2) * 2.0 - 1.0)
				ci.draw_rect(Rect2(o2 + Vector2(-1.8, -2), Vector2(3.6, 4)), Color(0.95, 0.93, 0.88))
				ci.draw_rect(Rect2(o2 + Vector2(-1.4, -1.6), Vector2(2.8, 2.4)), Color(0.3, 0.25, 0.35))
		"toy_car":
			ci.draw_rect(Rect2(-3, -1.5, 6, 3), ink)
			ci.draw_rect(Rect2(-2.6, -1.2, 5.2, 2.4), [Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.95, 0.8, 0.2), Color(0.3, 0.8, 0.4)][v])
			ci.draw_rect(Rect2(-1, -1.2, 2, 2.4), Color(0.6, 0.85, 1.0, 0.7))
		"crayons":
			for i in 4:
				ci.draw_line(Vector2(-3 + i * 1.8, -2), Vector2(-2 + i * 1.8, 2.5), [Color(0.9, 0.2, 0.2), Color(0.2, 0.6, 0.9), Color(0.95, 0.85, 0.2), Color(0.3, 0.8, 0.3)][i], 1.0)
		"teddy":
			ci.draw_circle(Vector2(0, 1), 2.6, Color(0.6, 0.4, 0.22))
			ci.draw_circle(Vector2(0, -2.2), 1.8, Color(0.65, 0.45, 0.25))
			ci.draw_circle(Vector2(-1.5, -3.5), 0.8, Color(0.6, 0.4, 0.22))
			ci.draw_circle(Vector2(1.5, -3.5), 0.8, Color(0.6, 0.4, 0.22))
		"tackle":
			ci.draw_rect(Rect2(-4.5, -3, 9, 6), ink)
			ci.draw_rect(Rect2(-4, -2.5, 8, 5), Color(0.2, 0.45, 0.35))
			ci.draw_rect(Rect2(-4, -0.3, 8, 0.6), Color(0.1, 0.25, 0.2))
			ci.draw_rect(Rect2(-1, -3.5, 2, 1), Color(0.75, 0.75, 0.8))
		"rod":
			ci.draw_line(Vector2(-7, 5), Vector2(6, -6), Color(0.3, 0.22, 0.15), 1.0)
			ci.draw_circle(Vector2(-5, 3.3), 1.2, Color(0.7, 0.72, 0.78))
			ci.draw_line(Vector2(6, -6), Vector2(7, 2), Color(0.9, 0.9, 0.9, 0.4), 0.4)
		"cooler":
			ci.draw_rect(Rect2(-5, -3.5, 10, 7), ink)
			ci.draw_rect(Rect2(-4.5, -3, 9, 6), Color(0.85, 0.25, 0.2))
			ci.draw_rect(Rect2(-4.5, -3, 9, 2), Color(0.95, 0.95, 0.92))
		"jukebox":
			ci.draw_rect(Rect2(-6, -5, 12, 9), ink)
			ci.draw_rect(Rect2(-5.5, -4.5, 11, 8), Color(0.45, 0.2, 0.1))
			ci.draw_arc(Vector2(0, -1), 4.5, PI, TAU, 16, Color(1.0, 0.6, 0.2), 1.2)
			ci.draw_arc(Vector2(0, -1), 3.2, PI, TAU, 16, Color(0.4, 0.9, 1.0), 1.0)
			ci.draw_rect(Rect2(-3.5, 0, 7, 2.5), Color(0.9, 0.85, 0.6))
		"pinball":
			ci.draw_rect(Rect2(-4, -7, 8, 13), ink)
			ci.draw_rect(Rect2(-3.5, -6.5, 7, 12), [Color(0.2, 0.2, 0.5), Color(0.5, 0.15, 0.3), Color(0.15, 0.4, 0.3), Color(0.4, 0.3, 0.1)][v])
			ci.draw_rect(Rect2(-3.5, -6.5, 7, 3), Color(1.0, 0.4, 0.7))
			for i in 3:
				ci.draw_circle(Vector2(-1.5 + i * 1.5, -1 + (i % 2)), 0.8, Color(1, 0.9, 0.3))
