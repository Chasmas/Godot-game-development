class_name LevelBuilder
extends RefCounted
## Turns an ASCII level file (see tools/build_m01.py for the legend) into a
## live level: collision, occluders, floors, doors, windows, furniture,
## props, lights, pickups, enemies, NPCs, interactables and a nav grid.

const T := 16
const FLOORS := ".,_:=\"~;+-"
const LOW_CHARS := "TCblwkcn"
const PROP_CHARS := "VtQIYFo"
const ENEMY_CHARS := {"g": &"guard", "m": &"gunner", "h": &"hunter", "H": &"heavy", "s": &"scout", "r": &"riot", "B": &"night_manager", "d": &"dog", "y": &"dog_rott",
	"z": &"zombie", "u": &"ghoul", "M": &"demon", "q": &"cultist", "v": &"hellhound"}
const WEAPON_CHARS := {"1": &"pistol", "2": &"whisper", "3": &"revolver", "4": &"smg", "5": &"shotgun", "6": &"rifle",
	"7": &"knife", "8": &"bat", "9": &"pipe", "0": &"machete", "!": &"bottle", "?": &"brick", "G": &"hotshot", "(": &"boomstick", ")": &"flamethrower"}
const FURN := {"T": "table", "C": "counter", "b": "bed", "l": "lounger", "w": "washer", "k": "desk", "K": "car", "Z": "dumpster", "c": "crate", "n": "cage", "j": "wreck"}
const PROPS := {"V": "vending", "t": "tv", "Q": "arcade", "I": "ice", "Y": "plant", "F": "fuse", "o": "lamp"}

var level: Node2D
var data: Dictionary
var rows: PackedStringArray
var w := 0
var h := 0
var floor_grid: Array = []      # [y][x] floor char
var solid_grid: Array = []      # [y][x] bool, for nav
var skip_enemies: Dictionary = {}
var skip_items: Dictionary = {}
var ambient := Color(0.36, 0.33, 0.52)
var boost := 1.8          ## readability multiplier for unlit things (walls, characters)

func _init(p_level: Node2D, p_data: Dictionary) -> void:
	level = p_level
	data = p_data
	rows = PackedStringArray(data.get("map", []))
	h = rows.size()
	for r in rows:
		w = maxi(w, r.length())
	var a: Array = data.get("ambient", [0.36, 0.33, 0.52])
	ambient = Color(a[0], a[1], a[2])
	boost = 0.85 / maxf(0.2, (ambient.r + ambient.g + ambient.b) / 3.0)

func ch(x: int, y: int) -> String:
	if y < 0 or y >= h or x < 0 or x >= rows[y].length():
		return "#"
	return rows[y][x]

func key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func cell_center(x: int, y: int) -> Vector2:
	return Vector2(x * T + T * 0.5, y * T + T * 0.5)

## Which light zone a switch / fuse box controls: level "power" map overrides.
func power_zone(x: int, y: int) -> String:
	var pw: Dictionary = data.get("power", {})
	if pw.has(key(x, y)):
		return str(pw[key(x, y)])
	return zone_at_cell(x, y)

func zone_at_cell(x: int, y: int) -> String:
	var zones: Dictionary = data.get("zones", {})
	for zname in zones.keys():
		var r: Array = zones[zname]
		if x >= r[0] and y >= r[1] and x < r[0] + r[2] and y < r[1] + r[3]:
			return str(zname).replace("_alley", "")
	return "default"

# ======================================================================== build
func build() -> Dictionary:
	var out := {"spawn": Vector2(100, 100), "reinforcements": [], "enemies": [], "exit_pos": Vector2.ZERO, "npcs": [], "lights": [], "boss": null, "interactables": [], "upgrades": [], "switches": []}
	_compute_floors()
	_build_floor_chunks()
	_build_walls()
	var visited := {}
	for y in h:
		for x in rows[y].length():
			var c := ch(x, y)
			var k := key(x, y)
			var center := cell_center(x, y)
			if visited.has(k):
				continue
			if c == "D" or c == "L":
				_build_door(x, y, c, visited)
			elif c == "W":
				_build_window(x, y, visited)
			elif FURN.has(c):
				_build_furniture(x, y, c, visited)
			elif PROPS.has(c):
				var p := BreakableProp.new()
				p.setup(PROPS[c], center, power_zone(x, y))
				level.props_root.add_child(p)
				if c == "o":
					var lf := LightFixture.new()
					lf.setup(zone_at_cell(x, y), Color(1, 0.85, 0.6), 70.0, 0.8, true)
					p.add_child(lf)
					p.light = lf
					out.lights.append(lf)
			elif c == "%":
				var wwall := BreakableProp.new()
				wwall.setup("weak_wall", center)
				level.props_root.add_child(wwall)
			elif c == "E":
				var tank := ExplosiveTank.new()
				tank.position = center
				level.props_root.add_child(tank)
			elif c == "*" or c == "^":
				var col := _light_color(x, y)
				var lf2 := LightFixture.new()
				var zone := zone_at_cell(x, y)
				var ext := zone == "exterior"
				var fz: Array = data.get("flicker_zones", [])
				var flick := c == "^" or (fz.has(zone) and randf() < 0.6) or randf() < 0.05
				lf2.setup(zone, col, 150.0 if ext else 118.0, 1.35 if ext else 0.72, true, flick)
				lf2.position = center
				level.lights_root.add_child(lf2)
				out.lights.append(lf2)
			elif c == "S":
				var sw := Power.Switch.new()
				sw.zone = power_zone(x, y)
				sw.level = level
				sw.position = center
				level.props_root.add_child(sw)
				out.switches.append(sw)
			elif c == "U":
				var uid := "upg_" + k
				if skip_items.has(uid):
					continue
				var up := Upgrades.Pickup.new()
				up.item_id = uid
				up.upgrade_id = StringName(str(data.get("upgrades", {}).get(k, "")))
				up.position = center
				level.pickups_root.add_child(up)
				out.upgrades.append(up)
			elif c == "A":
				var al := AlarmPanel.new()
				al.position = center
				level.props_root.add_child(al)
			elif c == "$" or c == "&":
				var cd: Dictionary = data.get("collectibles", {}).get(k, {})
				var cid: String = cd.get("id", "collectible_" + k)
				if skip_items.has(cid):
					continue
				var it := Interactable.new()
				it.setup(cd.get("kind", "tape"), "TAKE " + str(cd.get("kind", "tape")).to_upper(), cid)
				it.set_meta("title", cd.get("title", "???"))
				it.set_meta("text", cd.get("text", ""))
				it.position = center
				level.props_root.add_child(it)
				it.used.connect(level._on_collectible)
				out.interactables.append(it)
			elif c == "O":
				var ph := Interactable.new()
				ph.setup("phone", "ANSWER PHONE", "phone")
				ph.enabled = false
				ph.position = center
				level.props_root.add_child(ph)
				ph.used.connect(level._on_phone)
				level.phone = ph
			elif c == "X":
				var car := Interactable.new()
				car.setup("car", "DRIVE AWAY", "exit")
				car.enabled = false
				car.one_shot = true
				car.position = center
				level.props_root.add_child(car)
				car.used.connect(level._on_exit)
				level.exit_car = car
				out.exit_pos = center
				var hc := HeroCar.new()
				var hcd: Dictionary = data.get("hero_car", {})
				hc.position = Vector2(float(hcd.pos[0]), float(hcd.pos[1])) * 16.0 if hcd.has("pos") else center
				for v in hcd.get("route_in", []):
					hc.route_in.append(Vector2(float(v[0]), float(v[1])) * 16.0)
				for v in hcd.get("route_out", []):
					hc.route_out.append(Vector2(float(v[0]), float(v[1])) * 16.0)
				if hc.route_in.size() >= 2:
					var n: int = hc.route_in.size()
					hc._dir = (hc.route_in[n - 1] - hc.route_in[n - 2]).normalized()
					hc.rotation = hc._dir.angle()
				for g in hcd.get("gates", []):
					# [x0, y0, x1, y1]: the stretch of boundary opened for the car
					var bg := HeroCar.BoomGate.new()
					bg.level = level
					var vertical: bool = int(g[3]) > int(g[1])
					bg.axis = Vector2.DOWN if vertical else Vector2.RIGHT
					bg.span = ((float(g[3]) - float(g[1])) if vertical else (float(g[2]) - float(g[0]))) * 16.0 + 16.0
					bg.position = Vector2(float(g[0]) * 16.0 + 8.0, float(g[1]) * 16.0) if vertical else Vector2(float(g[0]) * 16.0, float(g[1]) * 16.0 + 8.0)
					level.props_root.add_child(bg)
					hc.gates.append(bg)
				level.props_root.add_child(hc)
				level.hero_car = hc
			elif c == "P":
				out.spawn = center
			elif c == "R":
				out.reinforcements.append(center)
			elif c == "@":
				_spawn_npc(x, y, center, out)
			elif ENEMY_CHARS.has(c):
				_spawn_enemy(x, y, c, center, out)
			elif WEAPON_CHARS.has(c):
				var wid: StringName = WEAPON_CHARS[c]
				if skip_items.has("w_" + k):
					continue
				var wd := DB.weapon(wid)
				if wd:
					var wi := WeaponInstance.create(wd)
					wi.reserve = int(round(wi.reserve * Difficulty.mult("ammo_mult")))
					var pk := WeaponPickup.spawn(level.pickup_root(), wi, center + Vector2(randf_range(-3, 3), randf_range(-3, 3)))
					pk.set_meta("item_key", "w_" + k)
	level.nav = _build_nav()
	return out

func _compute_floors() -> void:
	floor_grid.resize(h)
	solid_grid.resize(h)
	for y in h:
		var fr := []
		var sr := []
		fr.resize(w)
		sr.resize(w)
		for x in w:
			var c := ch(x, y)
			fr[x] = c if FLOORS.contains(c) else ""
			sr[x] = false
		floor_grid[y] = fr
		solid_grid[y] = sr
	# inherit floors for object cells
	for y in h:
		for x in w:
			if floor_grid[y][x] == "":
				var c := ch(x, y)
				if c == "#" or c == " ":
					continue
				if c == "*" and (ch(x - 1, y) == "~" or ch(x + 1, y) == "~") and (ch(x, y - 1) == "~" or ch(x, y + 1) == "~"):
					floor_grid[y][x] = "~"   # light sunk in the pool
					continue
				floor_grid[y][x] = _neighbour_floor(x, y)

func _neighbour_floor(x: int, y: int) -> String:
	for r in range(1, 4):
		for d in [Vector2i(-r, 0), Vector2i(r, 0), Vector2i(0, -r), Vector2i(0, r)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if ny >= 0 and ny < h and nx >= 0 and nx < w:
				var c := ch(nx, ny)
				if FLOORS.contains(c) and c != "~":
					return c
	return ","

func is_parking_row(y: int) -> bool:
	for r in data.get("parking_rows", []):
		if y >= int(r[0]) and y <= int(r[1]):
			return true
	return false

func wall_colors(zone: String) -> Array:
	var wc: Dictionary = data.get("wall_colors", {})
	if wc.has(zone):
		var a: Array = wc[zone]
		return [Color.html("#" + str(a[0])), Color.html("#" + str(a[1])), Color.html("#" + str(a[2]))]
	if wc.has("default"):
		var d: Array = wc["default"]
		return [Color.html("#" + str(d[0])), Color.html("#" + str(d[1])), Color.html("#" + str(d[2]))]
	return []

func _light_color(x: int, y: int) -> Color:
	var cols: Dictionary = data.get("light_colors", {})
	var f: String = floor_grid[y][x]
	if ch(x, y + 1) == "~" or ch(x - 1, y) == "~" or ch(x + 1, y) == "~":
		f = "~"
	return Color.html("#" + str(cols.get(f, "ffc890")))

# ---------------------------------------------------------------- floors
func _build_floor_chunks() -> void:
	var cs := 16
	for cy in range(0, h, cs):
		for cx in range(0, w, cs):
			var chunk := FloorChunk.new()
			chunk.builder = self
			chunk.rect = Rect2i(cx, cy, mini(cs, w - cx), mini(cs, h - cy))
			chunk.z_index = -10
			level.floor_root.add_child(chunk)

# ---------------------------------------------------------------- walls
func _is_wall(x: int, y: int) -> bool:
	return ch(x, y) == "#"

func _build_walls() -> void:
	var used := {}
	for y in h:
		for x in w:
			if not _is_wall(x, y) or used.has(key(x, y)):
				continue
			var x1 := x
			while x1 + 1 < w and _is_wall(x1 + 1, y) and not used.has(key(x1 + 1, y)):
				x1 += 1
			var y1 := y
			var ok := true
			while ok and y1 + 1 < h:
				for xx in range(x, x1 + 1):
					if not _is_wall(xx, y1 + 1) or used.has(key(xx, y1 + 1)):
						ok = false
						break
				if ok:
					y1 += 1
			for yy in range(y, y1 + 1):
				for xx in range(x, x1 + 1):
					used[key(xx, yy)] = true
					solid_grid[yy][xx] = true
			var rect := Rect2(x * T, y * T, (x1 - x + 1) * T, (y1 - y + 1) * T)
			var body := StaticBody2D.new()
			body.collision_layer = Layers.WORLD
			body.collision_mask = 0
			body.position = rect.get_center()
			body.add_to_group("walls")
			var shape := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = rect.size
			shape.shape = rs
			body.add_child(shape)
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			var hs := rect.size * 0.5
			poly.polygon = PackedVector2Array([-hs, Vector2(hs.x, -hs.y), hs, Vector2(-hs.x, hs.y)])
			occ.occluder = poly
			body.add_child(occ)
			level.walls_root.add_child(body)
	# pits (pool water): block walking, not bullets or sight
	var pit_used := {}
	for y in h:
		for x in w:
			if floor_grid[y][x] != "~" or pit_used.has(key(x, y)):
				continue
			var x1 := x
			while x1 + 1 < w and floor_grid[y][x1 + 1] == "~" and not pit_used.has(key(x1 + 1, y)):
				x1 += 1
			var y1 := y
			var ok2 := true
			while ok2 and y1 + 1 < h:
				for xx in range(x, x1 + 1):
					if floor_grid[y1 + 1][xx] != "~" or pit_used.has(key(xx, y1 + 1)):
						ok2 = false
						break
				if ok2:
					y1 += 1
			for yy in range(y, y1 + 1):
				for xx in range(x, x1 + 1):
					pit_used[key(xx, yy)] = true
					solid_grid[yy][xx] = true
			var prect := Rect2(x * T, y * T, (x1 - x + 1) * T, (y1 - y + 1) * T)
			var pit := StaticBody2D.new()
			pit.collision_layer = Layers.PIT
			pit.collision_mask = 0
			pit.position = prect.get_center()
			var pshape := CollisionShape2D.new()
			var prs := RectangleShape2D.new()
			prs.size = prect.size - Vector2(4, 4)
			pshape.shape = prs
			pit.add_child(pshape)
			level.walls_root.add_child(pit)
	# wall visuals, chunked
	var cs := 16
	for cy in range(0, h, cs):
		for cx in range(0, w, cs):
			var wc := WallChunk.new()
			wc.builder = self
			wc.rect = Rect2i(cx, cy, mini(cs, w - cx), mini(cs, h - cy))
			wc.z_index = 6
			wc.light_mask = 2
			level.walls_root.add_child(wc)

# ---------------------------------------------------------------- doors / windows
func _run(x: int, y: int, c: String, visited: Dictionary) -> Array:
	## returns [cells, horizontal]
	var cells := [Vector2i(x, y)]
	visited[key(x, y)] = true
	var horizontal := ch(x + 1, y) == c
	var nx := x
	var ny := y
	while true:
		if horizontal:
			nx += 1
		else:
			ny += 1
		if ch(nx, ny) != c or visited.has(key(nx, ny)):
			break
		cells.append(Vector2i(nx, ny))
		visited[key(nx, ny)] = true
	if cells.size() == 1:
		horizontal = _is_wall(x - 1, y) or _is_wall(x + 1, y)
	return [cells, horizontal]

func _build_door(x: int, y: int, c: String, visited: Dictionary) -> void:
	var r := _run(x, y, c, visited)
	var cells: Array = r[0]
	var horizontal: bool = r[1]
	var locked := c == "L"
	var n := cells.size()
	# split long runs into double doors
	var parts := [[0, n]] if n <= 2 else [[0, n / 2], [n / 2, n - n / 2]]
	for part in parts:
		var start: Vector2i = cells[part[0]]
		var cnt: int = part[1]
		var d := Door.new()
		var length := float(cnt * T)
		if horizontal:
			d.setup(Vector2(start.x * T, start.y * T + T * 0.5), length, 0.0, locked)
		else:
			d.setup(Vector2(start.x * T + T * 0.5, start.y * T), length, PI * 0.5, locked)
		level.doors_root.add_child(d)
		if locked:
			level.locked_doors.append(d)
	for cc in cells:
		solid_grid[cc.y][cc.x] = locked

func _build_window(x: int, y: int, visited: Dictionary) -> void:
	var r := _run(x, y, "W", visited)
	var cells: Array = r[0]
	var horizontal: bool = r[1]
	var s: Vector2i = cells[0]
	var n := cells.size()
	var rect: Rect2
	if horizontal:
		rect = Rect2(s.x * T, s.y * T + 6, n * T, 4)
	else:
		rect = Rect2(s.x * T + 6, s.y * T, 4, n * T)
	var g := GlassWindow.new()
	g.setup(rect)
	level.props_root.add_child(g)
	for cc in cells:
		solid_grid[cc.y][cc.x] = true

func _build_furniture(x: int, y: int, c: String, visited: Dictionary) -> void:
	# flood fill same char -> bounding rect
	var stack := [Vector2i(x, y)]
	var minp := Vector2i(x, y)
	var maxp := Vector2i(x, y)
	visited[key(x, y)] = true
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		minp = Vector2i(mini(minp.x, p.x), mini(minp.y, p.y))
		maxp = Vector2i(maxi(maxp.x, p.x), maxi(maxp.y, p.y))
		solid_grid[p.y][p.x] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			if ch(q.x, q.y) == c and not visited.has(key(q.x, q.y)):
				visited[key(q.x, q.y)] = true
				stack.append(q)
	var rect := Rect2(minp.x * T, minp.y * T, (maxp.x - minp.x + 1) * T, (maxp.y - minp.y + 1) * T)
	var f := Furniture.new()
	var kind: String = FURN[c]
	var variant := (x * 7 + y * 3) % 5 if kind != "dumpster" else 4
	if kind == "car" or kind == "wreck":
		for yy in range(minp.y - 1, maxp.y + 2):
			for xx in range(minp.x - 1, maxp.x + 2):
				if ch(xx, yy) == "X":
					variant = 0   # Cass's car: red, always
		if variant == 4:
			variant = 2
	f.setup("car" if kind == "dumpster" else kind, rect, variant)
	level.props_root.add_child(f)

# ---------------------------------------------------------------- actors
func _facing_from(v: Variant) -> Vector2:
	match str(v):
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		"up": return Vector2.UP
		"down": return Vector2.DOWN
	return Vector2.from_angle(randf() * TAU)

func _spawn_enemy(x: int, y: int, c: String, center: Vector2, out: Dictionary) -> void:
	var id := "e_" + key(x, y)
	if skip_enemies.has(id):
		return
	var cfg: Dictionary = data.get("enemies", {}).get(key(x, y), {})
	# a cell can name a special archetype ("kind": "sniper" / "handler")
	var kind := StringName(cfg.get("kind", ENEMY_CHARS[c]))
	var edata := DB.enemy(kind)
	if edata == null:
		return
	var e: Enemy
	if c == "B":
		if kind == &"burning_man":
			e = BossBurningMan.new()
		elif kind == &"fireman":
			e = BossFireman.new()
		else:
			e = BossNightManager.new()
	elif c == "d" or c == "y" or c == "v":
		e = Dog.new()
	elif kind == &"sniper":
		e = Sniper.new()
	elif kind == &"handler":
		e = Handler.new()
	else:
		e = Enemy.new()
	e.enemy_id = id
	e.position = center
	level.actors_root.add_child(e)
	if cfg.has("patrol"):
		var pts := PackedVector2Array()
		for p in cfg.patrol:
			pts.append(cell_center(int(p[0]), int(p[1])))
		e.patrol_points = pts
	e.setup(edata, level, _facing_from(cfg.get("facing", "")))
	if e is Dog:
		(e as Dog).sleeping = bool(cfg.get("sleep", false))
		(e as Dog).sniff_mode = bool(cfg.get("sniff", not cfg.has("patrol")))
	if c == "B":
		var cov := PackedVector2Array()
		for p in data.get("boss_cover", []):
			cov.append(cell_center(int(p[0]), int(p[1])))
		(e as BossNightManager).cover_points = cov
		out.boss = e
	out.enemies.append(e)
	if e is Handler and (e as Handler).dog:
		out.enemies.append((e as Handler).dog)

func _spawn_npc(x: int, y: int, center: Vector2, out: Dictionary) -> void:
	var cfg: Dictionary = data.get("npcs", {}).get(key(x, y), {})
	var n := NPC.new()
	n.npc_id = cfg.get("id", "guest")
	n.palette = cfg.get("palette", "civilian")
	n.lines = cfg.get("lines", [])
	n.position = center
	level.actors_root.add_child(n)
	out.npcs.append(n)

# ---------------------------------------------------------------- nav
func _build_nav() -> AStarGrid2D:
	var nav := AStarGrid2D.new()
	nav.region = Rect2i(0, 0, w, h)
	nav.cell_size = Vector2(T, T)
	nav.offset = Vector2(T * 0.5, T * 0.5)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	nav.update()
	for y in h:
		for x in w:
			var c := ch(x, y)
			var solid: bool = solid_grid[y][x] or c == " " or c == "~" or PROPS.has(c) or c == "E" or c == "%"
			if solid:
				nav.set_point_solid(Vector2i(x, y), true)
	return nav


## Draws a block of floor tiles with detailed procedural materials (lit by
## lights): grout, grain, stains, cracks, puddles, plus ambient occlusion
## where floors meet walls.
class FloorChunk extends Node2D:
	var builder: LevelBuilder
	var rect: Rect2i

	func _draw() -> void:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var f: String = builder.floor_grid[y][x]
				if f == "":
					continue
				var p := Vector2(x * LevelBuilder.T, y * LevelBuilder.T)
				_tile(f, p, x, y)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if builder.floor_grid[y][x] != "" and builder.floor_grid[y][x] != "~":
					_ao(Vector2(x * LevelBuilder.T, y * LevelBuilder.T), x, y)

	func _h(x: int, y: int, salt := 0) -> int:
		var v := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
		v = (v ^ (v >> 13)) * 1274126177
		return absi(v ^ (v >> 16))

	func _solid(x: int, y: int) -> bool:
		var c := builder.ch(x, y)
		return c == "#" or c == "W" or c == "%" or c == " "

	## soft contact shadows where the floor meets a wall (cel-style banding)
	func _ao(p: Vector2, x: int, y: int) -> void:
		var T2 := float(LevelBuilder.T)
		var bands := [0.26, 0.15, 0.07]
		for i in 3:
			var a: float = bands[i]
			var w := 2.0
			if _solid(x, y - 1):
				draw_rect(Rect2(p + Vector2(0, i * w), Vector2(T2, w)), Color(0.02, 0.0, 0.05, a))
			if _solid(x - 1, y):
				draw_rect(Rect2(p + Vector2(i * w, 0), Vector2(w, T2)), Color(0.02, 0.0, 0.05, a * 0.85))
			if _solid(x + 1, y):
				draw_rect(Rect2(p + Vector2(T2 - (i + 1) * w, 0), Vector2(w, T2)), Color(0.02, 0.0, 0.05, a * 0.6))
			if _solid(x, y + 1):
				draw_rect(Rect2(p + Vector2(0, T2 - (i + 1) * w), Vector2(T2, w)), Color(0.02, 0.0, 0.05, a * 0.45))

	## Painted floor tile (ArtLib): the seamless texture sampled in world
	## space, a little per-tile tone so it never reads as wallpaper, and the
	## procedural details that carry gameplay or story (parking lines,
	## puddles, stains, spike marks) on top.
	func _tile_painted(tex: Texture2D, f: String, p: Vector2, x: int, y: int) -> void:
		var T2 := float(LevelBuilder.T)
		var h := _h(x, y)
		var src := Rect2(fposmod(p.x * 2.0, 256.0), fposmod(p.y * 2.0, 256.0), 32, 32)
		draw_texture_rect_region(tex, Rect2(p, Vector2(T2, T2)), src)
		var tone := float(_h(x / 2, y / 2, 7) % 5) / 4.0
		draw_rect(Rect2(p, Vector2(T2, T2)), Color(0.05, 0.0, 0.1, 0.04 + 0.05 * tone))
		match f:
			":":
				if x % 4 == 0 and builder.is_parking_row(y):
					draw_rect(Rect2(p, Vector2(1.5, T2)), Color(0.95, 0.9, 0.6, 0.85))
				if h % 19 == 3:
					draw_set_transform(p + Vector2(8, 8), 0.0, Vector2(1.0, 0.55))
					draw_circle(Vector2.ZERO, 9.0, Color(0.1, 0.12, 0.22, 0.5))
					draw_arc(Vector2.ZERO, 9.0, PI * 1.1, PI * 1.7, 6, Color(0.8, 0.85, 1.0, 0.3), 1.0)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			".":
				if h % 17 == 0:
					draw_circle(p + Vector2(4 + h % 8, 5 + (h >> 4) % 7), 3.0 + (h % 3), Color(0.25, 0.05, 0.12, 0.4))
			"-":
				if h % 37 == 4:
					var tc: Color = [Color(1.0, 0.3, 0.45), Color(0.3, 0.9, 1.0), Color(1.0, 0.85, 0.3)][h % 3]
					var cc := p + Vector2(8, 8)
					draw_line(cc - Vector2(4, 0), cc + Vector2(4, 0), tc, 2.0)
					draw_line(cc - Vector2(0, 4), cc + Vector2(0, 4), tc, 2.0)

	func _tile(f: String, p: Vector2, x: int, y: int) -> void:
		var T2 := float(LevelBuilder.T)
		var r := Rect2(p, Vector2(T2, T2))
		var h := _h(x, y)
		var ptex := ArtLib.floor_tex(f, builder.data.get("floor_textures", {}))
		if ptex:
			_tile_painted(ptex, f, p, x, y)
			return
		match f:
			".":   # 80s motel carpet: diamond lattice, wear, the odd stain
				var base := Color(0.52, 0.14, 0.28) if (x / 6 + y / 6) % 7 != 0 else Color(0.47, 0.12, 0.26)
				draw_rect(r, base)
				var c1 := Color(0.95, 0.55, 0.3)
				var c2 := Color(0.2, 0.7, 0.7)
				var ctr := p + Vector2(8, 8)
				draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -6), ctr + Vector2(6, 0), ctr + Vector2(0, 6), ctr + Vector2(-6, 0)]), Color(base.darkened(0.14)))
				var dc: Color = (c1 if (x + y) % 2 == 0 else c2).lerp(base, 0.45)
				draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -2), ctr + Vector2(2, 0), ctr + Vector2(0, 2), ctr + Vector2(-2, 0)]), dc)
				for cor in [Vector2(0, 0), Vector2(15, 0), Vector2(0, 15), Vector2(15, 15)]:
					draw_rect(Rect2(p + cor, Vector2(1, 1)), c2 if (x + y) % 2 == 0 else c1)
				if h % 17 == 0:
					draw_circle(p + Vector2(4 + h % 8, 5 + (h >> 4) % 7), 3.0 + (h % 3), Color(0.25, 0.05, 0.12, 0.45))
				if h % 31 == 1:
					draw_circle(p + Vector2(3 + (h >> 3) % 10, 3 + (h >> 7) % 10), 1.0, Color(0.05, 0.03, 0.03, 0.9))
			",":   # checker tile with grout, gloss and chips
				var a := Color(0.87, 0.83, 0.77)
				var b := Color(0.62, 0.66, 0.73)
				for qy in 2:
					for qx in 2:
						var c := a if (qx + qy) % 2 == 0 else b
						var q := Rect2(p + Vector2(qx * 8, qy * 8), Vector2(8, 8))
						draw_rect(q, c)
						draw_rect(Rect2(q.position + Vector2(1, 1), Vector2(3, 1)), Color(1, 1, 1, 0.35))
						draw_rect(Rect2(q.position + Vector2(0, 7), Vector2(8, 1)), c.darkened(0.18))
				draw_rect(Rect2(p, Vector2(T2, 1)), Color(0.4, 0.4, 0.45, 0.5))
				draw_rect(Rect2(p, Vector2(1, T2)), Color(0.4, 0.4, 0.45, 0.5))
				if h % 13 == 0:
					var s0 := p + Vector2(2 + h % 10, 2 + (h >> 4) % 10)
					draw_polyline(PackedVector2Array([s0, s0 + Vector2(3, 2), s0 + Vector2(4, 5), s0 + Vector2(7, 6)]), Color(0.3, 0.3, 0.35, 0.7), 1.0)
			"_":   # wood planks: per-plank tone, grain, knots, seams
				for i in 4:
					var yy := p.y + i * 4
					var tone := 0.5 + 0.08 * float((_h(x / 3, y * 4 + i) % 5)) / 4.0
					var c := Color(tone * 1.1, tone * 0.68, tone * 0.36)
					draw_rect(Rect2(p.x, yy, T2, 4), c)
					draw_line(Vector2(p.x, yy + 1.5), Vector2(p.x + T2, yy + 1.8), c.darkened(0.12), 1.0)
					draw_line(Vector2(p.x, yy + 3.5), Vector2(p.x + T2, yy + 3.5), Color(0.25, 0.13, 0.06), 1.0)
					var sx := p.x + float((x * 5 + i * 7) % 16)
					draw_line(Vector2(sx, yy), Vector2(sx, yy + 4), Color(0.25, 0.13, 0.06), 1.0)
				if h % 11 == 0:
					draw_circle(p + Vector2(4 + h % 8, 3 + (h >> 5) % 10), 1.4, Color(0.3, 0.16, 0.07))
			":":   # asphalt: aggregate speckle, cracks, oil stains, puddles
				draw_rect(r, Color(0.27, 0.26, 0.31))
				for i in 6:
					var q2 := p + Vector2(float((h >> (i * 2)) % 16), float((h >> (i * 2 + 5)) % 16))
					draw_rect(Rect2(q2, Vector2(1, 1)), Color(0.42, 0.4, 0.47) if i % 2 == 0 else Color(0.18, 0.17, 0.21))
				if x % 4 == 0 and builder.is_parking_row(y):
					draw_rect(Rect2(p, Vector2(1.5, T2)), Color(0.95, 0.9, 0.6, 0.85))
				if h % 11 == 0:
					var c0 := p + Vector2(h % 12, (h >> 4) % 12)
					draw_polyline(PackedVector2Array([c0, c0 + Vector2(4, 3), c0 + Vector2(6, 8), c0 + Vector2(11, 10)]), Color(0.12, 0.11, 0.14), 1.0)
					draw_line(c0 + Vector2(4, 3), c0 + Vector2(8, 1), Color(0.12, 0.11, 0.14), 1.0)
				if h % 23 == 2:
					draw_set_transform(p + Vector2(8, 8), 0.4, Vector2(1.0, 0.6))
					draw_circle(Vector2.ZERO, 7.0, Color(0.1, 0.08, 0.14, 0.55))
					draw_circle(Vector2(1, -1), 3.0, Color(0.35, 0.2, 0.45, 0.35))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if h % 19 == 3:
					draw_set_transform(p + Vector2(8, 8), 0.0, Vector2(1.0, 0.55))
					draw_circle(Vector2.ZERO, 9.0, Color(0.1, 0.12, 0.22, 0.55))
					draw_circle(Vector2(-3, -2), 4.0, Color(0.45, 0.35, 0.65, 0.25))
					draw_arc(Vector2.ZERO, 9.0, PI * 1.1, PI * 1.7, 6, Color(0.8, 0.85, 1.0, 0.35), 1.0)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"=":   # concrete slabs with seams, pits and stains
				var shade := 0.58 + 0.03 * float(_h(x / 2, y / 2) % 3)
				draw_rect(r, Color(shade, shade * 0.97, shade * 1.03))
				if x % 2 == 0:
					draw_rect(Rect2(p, Vector2(1, T2)), Color(0.4, 0.38, 0.44))
				if y % 2 == 0:
					draw_rect(Rect2(p, Vector2(T2, 1)), Color(0.4, 0.38, 0.44))
				for i in 3:
					draw_rect(Rect2(p + Vector2(float((h >> (i * 3)) % 15), float((h >> (i * 3 + 7)) % 15)), Vector2(1, 1)), Color(0.45, 0.43, 0.5))
				if h % 15 == 0:
					draw_circle(p + Vector2(8, 8), 4.0, Color(0.35, 0.32, 0.36, 0.35))
			"\"":  # grass with blade variation and little flowers
				draw_rect(r, Color(0.15, 0.4, 0.23))
				for i in 8:
					var q3 := p + Vector2(float((x * 13 + i * 5 + h) % 15), float((y * 7 + i * 11 + (h >> 3)) % 15) + 2)
					var gc := Color(0.28, 0.62, 0.34) if i % 3 != 0 else Color(0.1, 0.3, 0.17)
					draw_line(q3, q3 + Vector2((i % 3) - 1, -3), gc, 1.0)
				if h % 9 == 0:
					var fp := p + Vector2(3 + h % 10, 3 + (h >> 4) % 10)
					draw_circle(fp, 1.2, [Color(1, 0.85, 0.3), Color(1, 0.5, 0.7), Color(0.95, 0.95, 1)][h % 3])
			"~":   # pool: deep gradient + tile edge (caustics animate in PoolFX)
				draw_rect(r, Color(0.04, 0.26, 0.5))
				draw_rect(Rect2(p + Vector2(0, 8), Vector2(T2, 8)), Color(0.03, 0.21, 0.44))
				for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
					if builder.ch(x + d.x, y + d.y) != "~" and builder.floor_grid[y + d.y][x + d.x] != "~":
						var er := Rect2(p, Vector2(T2, 3)) if d.y == -1 else (Rect2(p + Vector2(0, T2 - 3), Vector2(T2, 3)) if d.y == 1 else (Rect2(p, Vector2(3, T2)) if d.x == -1 else Rect2(p + Vector2(T2 - 3, 0), Vector2(3, T2))))
						draw_rect(er, Color(0.92, 0.96, 1.0))
						draw_rect(er.grow(-1), Color(0.55, 0.85, 0.95))
			";":   # packed desert dirt / gravel with tyre ruts and scrub
				draw_rect(r, Color(0.46, 0.36, 0.27))
				for i in 7:
					var q4 := p + Vector2(float((h >> (i * 2)) % 16), float((h >> (i * 2 + 5)) % 16))
					draw_rect(Rect2(q4, Vector2(1, 1)), Color(0.6, 0.5, 0.38) if i % 2 == 0 else Color(0.33, 0.25, 0.19))
				if h % 7 == 0:
					draw_circle(p + Vector2(3 + h % 10, 3 + (h >> 4) % 10), 1.3, Color(0.55, 0.52, 0.5))
				if h % 29 == 5:
					var sc := p + Vector2(8, 8)
					for k in 5:
						draw_line(sc, sc + Vector2.from_angle(k * 1.25 + 0.3) * 3.5, Color(0.42, 0.45, 0.24), 1.0)
				if x % 9 == 3 or x % 9 == 5:
					draw_rect(Rect2(p + Vector2(2, 0), Vector2(2, T2)), Color(0.4, 0.31, 0.23, 0.6))
			"+":   # steel diamond-plate / grating
				draw_rect(r, Color(0.36, 0.38, 0.42))
				for gy in 4:
					for gx in 4:
						var gp := p + Vector2(gx * 4 + (2 if gy % 2 == 0 else 0), gy * 4 + 1)
						draw_line(gp, gp + Vector2(2, 1), Color(0.55, 0.58, 0.63), 1.0)
				draw_rect(Rect2(p, Vector2(T2, 1)), Color(0.22, 0.23, 0.27))
				draw_rect(Rect2(p, Vector2(1, T2)), Color(0.22, 0.23, 0.27))
				if h % 13 == 0:
					draw_circle(p + Vector2(4 + h % 8, 4 + (h >> 3) % 8), 3.0, Color(0.3, 0.2, 0.12, 0.45))
			"-":   # soundstage floor: matte black paint, scuffs, gaffer-tape marks
				var tone := 0.1 + 0.015 * float(_h(x / 3, y / 3) % 3)
				draw_rect(r, Color(tone, tone * 0.95, tone * 1.1))
				for i in 4:
					draw_rect(Rect2(p + Vector2(float((h >> (i * 3)) % 15), float((h >> (i * 3 + 6)) % 15)), Vector2(1, 1)), Color(0.2, 0.19, 0.24))
				if h % 9 == 0:
					draw_line(p + Vector2(2 + h % 6, 3 + (h >> 4) % 9), p + Vector2(9 + h % 6, 4 + (h >> 4) % 9), Color(0.16, 0.15, 0.2), 1.0)
				if h % 37 == 4:
					# a spike mark: two crossed strips of coloured tape
					var tc: Color = [Color(1.0, 0.3, 0.45), Color(0.3, 0.9, 1.0), Color(1.0, 0.85, 0.3)][h % 3]
					var cc := p + Vector2(8, 8)
					draw_line(cc - Vector2(4, 0), cc + Vector2(4, 0), tc, 2.0)
					draw_line(cc - Vector2(0, 4), cc + Vector2(0, 4), tc, 2.0)
				if y % 8 == 0 and h % 3 == 0:
					draw_rect(Rect2(p + Vector2(0, 7), Vector2(T2, 1)), Color(1, 1, 1, 0.04))
			_:
				draw_rect(r, Color(0.4, 0.4, 0.4))


## Unlit wall tops (readable, HM-style) with bevels, texture and a shaded
## front face / baseboard where the wall meets the floor.
class WallChunk extends Node2D:
	var builder: LevelBuilder
	var rect: Rect2i

	func _draw() -> void:
		var T2 := float(LevelBuilder.T)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				if builder.ch(x, y) != "#":
					continue
				var p := Vector2(x * T2, y * T2)
				var zone := builder.zone_at_cell(x, y)
				var top := Color(0.92, 0.8, 0.68)
				var edge := Color(0.55, 0.36, 0.4)
				var trim := Color(0.95, 0.42, 0.55)
				var wcs := builder.wall_colors(zone)
				if not wcs.is_empty():
					top = wcs[0]
					edge = wcs[1]
					trim = wcs[2]
				elif zone == "lobby":
					top = Color(0.78, 0.9, 0.86)
					edge = Color(0.3, 0.5, 0.52)
					trim = Color(0.35, 0.85, 0.9)
				var border := x == 0 or y == 0 or x >= builder.w - 1 or y >= builder.h - 1 or (x == builder.w - 2)
				if border:
					top = Color(0.14, 0.1, 0.2)
					edge = Color(0.08, 0.05, 0.12)
					trim = Color(0.2, 0.12, 0.3)
				var bst := builder.boost
				top = top * bst * 0.78
				edge = edge * bst * 0.9
				draw_rect(Rect2(p, Vector2(T2, T2)), top)
				# stucco texture
				var hh := (x * 928371 + y * 364479) & 0xffff
				for i in 4:
					draw_rect(Rect2(p + Vector2(float((hh >> (i * 3)) % 15), float((hh >> (i * 3 + 5)) % 15)), Vector2(1, 1)), top.darkened(0.08))
				var open_s := builder.ch(x, y + 1) != "#" and y + 1 < builder.h
				var open_n := builder.ch(x, y - 1) != "#"
				var open_w := builder.ch(x - 1, y) != "#"
				var open_e := builder.ch(x + 1, y) != "#"
				if open_n:
					draw_rect(Rect2(p, Vector2(T2, 1)), Color(1, 1, 1, 0.45))
					draw_rect(Rect2(p + Vector2(0, 1), Vector2(T2, 1)), Color(1, 1, 1, 0.15))
				if open_s:
					# front face: two-tone cel band + neon trim + baseboard
					draw_rect(Rect2(p + Vector2(0, T2 - 6), Vector2(T2, 6)), edge)
					draw_rect(Rect2(p + Vector2(0, T2 - 6), Vector2(T2, 2)), edge.lightened(0.15))
					draw_rect(Rect2(p + Vector2(0, T2 - 7), Vector2(T2, 1)), trim * (bst * 0.7) if not border else trim)
					draw_rect(Rect2(p + Vector2(0, T2 - 1), Vector2(T2, 1)), Color(0.05, 0.02, 0.07))
				if open_w:
					draw_rect(Rect2(p, Vector2(1, T2)), Color(0.06, 0.03, 0.08))
					draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, T2)), Color(1, 1, 1, 0.12))
				if open_e:
					draw_rect(Rect2(p + Vector2(T2 - 1, 0), Vector2(1, T2)), Color(0.06, 0.03, 0.08))
					draw_rect(Rect2(p + Vector2(T2 - 2, 0), Vector2(1, T2)), top.darkened(0.15))
