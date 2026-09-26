class_name Level
extends Node2D
## Mission runtime. Builds the level from MissionData.level_file, spawns the
## player at the start or last checkpoint, runs objectives, checkpoints,
## hints, the boss encounter, the phone call, the walk back to the car,
## alarms/reinforcements, instant restart and completion.

enum Phase { INFILTRATE, CLEAR, BOSS, BOSS_DOWN, PHONE, ESCAPE, DONE }

var mission: MissionData
var data: Dictionary = {}
var nav: AStarGrid2D
var player: Player
var camera: CameraController
var hud: HUD
var pause_menu: PauseMenu
var boss: BossNightManager
var phone: Interactable
var exit_car: Interactable
var locked_doors: Array = []
var phase: Phase = Phase.INFILTRATE
var enemies: Array = []
var reinforcement_points: Array = []
var lights: Array = []
var killed_ids: Dictionary = {}
var collected: Dictionary = {}
var secrets_found: Array = []
var dark_modulate: CanvasModulate
var builder: LevelBuilder
var weather: WeatherSystem
var ambient := Color(0.4, 0.4, 0.6)
var player_light: PointLight2D
var darkness: Power.DarknessLayer
var zone_power: Dictionary = {}      ## zone -> false when blacked out
var dead_zones: Dictionary = {}      ## zones whose fuse box was destroyed
var switches: Array = []
var upgrade_pickups: Array = []

var floor_root: Node2D
var walls_root: Node2D
var doors_root: Node2D
var props_root: Node2D
var pickups_root: Node2D
var actors_root: Node2D
var lights_root: Node2D
var fx: Effects
var bullets: BulletSystem
var crowd: Crowd

var _checkpoints_hit: Dictionary = {}
var _hints_shown: Dictionary = {}
var _boss_triggered := false
var _restart_ready := false
var _t := 0.0
var _alarm_spawned := false

func _ready() -> void:
	add_to_group("level")
	mission = Game.current_mission
	if mission == null:
		mission = load("res://data/missions/m01_checkout.tres")
		Game.current_mission = mission
	if Game.current_character == null:
		Game.current_character = Game.characters.get(&"cass", load("res://data/characters/cass.tres"))
	data = _load_level(mission.level_file)
	_make_roots()
	var b := LevelBuilder.new(self, data)
	var st: Dictionary = Game.checkpoint_state
	if not st.is_empty():
		for id in st.get("killed", []):
			b.skip_enemies[id] = true
			killed_ids[id] = true
		for id in st.get("collected", []):
			b.skip_items[id] = true
			collected[id] = true
	var built := b.build()
	builder = b
	var decor_root := _root("Decor")
	Decor.build(self, decor_root, b, data.get("decor", []))
	if SaveManager.get_setting("set_dressing", true):
		Dressing.build(self, b)
	var motes := AmbientMotes.new()
	motes.level = self
	add_child(motes)
	var amb := Ambience.new()
	amb.name = "Ambience"
	amb.level = self
	add_child(amb)
	weather = WeatherSystem.new()
	weather.setup(self, b, data.get("weather", {}))
	add_child(weather)
	enemies = built.enemies
	reinforcement_points = built.reinforcements
	lights = built.lights
	boss = built.boss
	switches = built.switches
	upgrade_pickups = built.upgrades
	darkness = Power.DarknessLayer.new()
	darkness.level = self
	add_child(darkness)
	darkness.build(b)
	# paint every enemy look now instead of mid-fight (see SpriteForge.prewarm)
	var looks := {}
	for e in enemies:
		if e.visual:
			looks[e.look] = true
	for base in ["guard", "gunner"]:   # reinforcements can arrive in any variant
		for v in 4:
			looks["%s#%d" % [base, v]] = true
	var warm_ms := SpriteForge.prewarm(looks.keys())
	if OS.is_debug_build() and warm_ms > 1.0:
		print("[level] prewarmed %d looks in %.0f ms" % [looks.size(), warm_ms])
	for e in enemies:
		e.died.connect(_on_enemy_died)
		if Game.modifiers.get("hard", false):
			e.data = e.data.duplicate()
			e.data.reaction_time *= 0.7
			e.data.aim_error_deg *= 0.6
			e.data.view_distance *= 1.15
	Score.finisher.connect(_on_finisher)
	Score.on_beat.connect(_on_beat_kill)
	if boss:
		boss.defeated.connect(_on_boss_defeated)
	# player
	player = Player.new()
	player.level = self
	actors_root.add_child(player)
	player.setup(Game.current_character)
	var spawn: Vector2 = built.spawn
	_mission_start = built.spawn
	if not st.is_empty():
		spawn = st.get("spawn", spawn)
		player.restore_weapons(st.get("weapons", []))
		player.equipment_left = int(st.get("equipment", player.equipment_left))
		_checkpoints_hit = st.get("checkpoints", {}).duplicate()
		_hints_shown = st.get("hints", {}).duplicate()
		phase = st.get("phase", Phase.INFILTRATE)
		Score.restore(st.get("score", {}), Game.attempts)
	else:
		Score.reset()
	player.global_position = spawn
	_build_checkpoint_markers.call_deferred()
	_build_cameras()
	_scatter_smashables()
	player.died.connect(_on_player_died)
	if not st.is_empty():
		player.restore_upgrades(st.get("upgrades", {}))
		for z in st.get("dead_zones", []):
			set_zone_lights(str(z), false, "fuse")
	_assign_upgrades()
	player_light = PointLight2D.new()
	player_light.texture = SpriteLib.light_texture(128)
	player_light.texture_scale = 0.9
	player_light.energy = 0.35
	player_light.color = Color(1, 0.8, 0.9)
	player_light.range_item_cull_mask = 1 | 2
	player.add_child(player_light)
	# camera
	camera = CameraController.new()
	camera.target = player
	add_child(camera)
	camera.snap_to_target()
	# HUD / pause
	hud = HUD.new()
	hud.level = self
	hud.player = player
	add_child(hud)
	var barks := BarkLayer.new()
	barks.name = "Barks"
	add_child(barks)
	pause_menu = PauseMenu.new()
	pause_menu.level = self
	add_child(pause_menu)
	dark_modulate = CanvasModulate.new()
	dark_modulate.color = b.ambient
	add_child(dark_modulate)
	ambient = b.ambient
	var boost := Color(b.boost, b.boost, b.boost)
	walls_root.modulate = Color.WHITE
	doors_root.modulate = boost
	actors_root.modulate = boost
	pickups_root.modulate = boost
	props_root.modulate = Color.WHITE.lerp(boost, 0.55)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Dialogue.event.connect(_on_dialogue_event)
	Dialogue.finished.connect(_on_dialogue_finished)
	# music / intro
	Music.play(mission.music_track)
	PostFX.set_desaturate(0.0)
	PostFX.set_tint(Color(1, 1, 1, 0))
	Audio.set_music_muffled(false)
	Score.running = true
	if phase == Phase.BOSS and boss and is_instance_valid(boss):
		_start_boss(false)
	elif phase >= Phase.PHONE:
		_begin_phone()
	if Game.attempts <= 1 and st.is_empty():
		hud.show_title_card(tr(mission.title), "%s\n%s  ·  %s" % [tr(mission.location).to_upper(), tr(mission.date_text), tr(str(data.get("time_text", "11:48 PM")))])
		PostFX.vhs_glitch(0.8)
		Events.objective_changed.emit(_obj("infiltrate", "GET INSIDE THE SUNSET PALMS"))
	else:
		_update_objective()
	player.ability._emit()
	player._emit_weapon()

func _load_level(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Level file missing " + path)
		return {"map": ["#####", "#P..#", "#####"]}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func _make_roots() -> void:
	floor_root = _root("Floor")
	fx = Effects.new()
	fx.name = "Effects"
	add_child(fx)
	walls_root = _root("Walls")
	props_root = _root("Props")
	pickups_root = _root("Pickups")
	doors_root = _root("Doors")
	actors_root = _root("Actors")
	lights_root = _root("Lights")
	bullets = BulletSystem.new()
	bullets.name = "Bullets"
	add_child(bullets)
	crowd = Crowd.new()
	crowd.name = "Crowd"
	crowd.level = self
	add_child(crowd)

func _root(n: String) -> Node2D:
	var r := Node2D.new()
	r.name = n
	add_child(r)
	return r

func pickup_root() -> Node:
	return pickups_root

# ======================================================================= queries for AI
func get_nav_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if nav == null:
		return PackedVector2Array([to])
	var a := Vector2i(int(from.x / 16.0), int(from.y / 16.0))
	var b := Vector2i(int(to.x / 16.0), int(to.y / 16.0))
	if not nav.is_in_boundsv(a) or not nav.is_in_boundsv(b):
		return PackedVector2Array([to])
	b = _nearest_open(b)
	a = _nearest_open(a)
	var path := nav.get_point_path(a, b, true)
	if path.size() > 0:
		path.remove_at(0)
	path.append(to)
	return path

## Closest walkable point to p (cell centre), or fallback if p is deep in a
## wall or outside the map. Used to keep investigation/search spots reachable.
func nearest_open_point(p: Vector2, fallback: Vector2) -> Vector2:
	if nav == null:
		return p
	var c := Vector2i(int(p.x / 16.0), int(p.y / 16.0))
	if not nav.is_in_boundsv(c):
		return fallback
	if not nav.is_point_solid(c):
		return p
	var o := _nearest_open(c)
	if nav.is_point_solid(o):
		return fallback
	return Vector2(o.x * 16 + 8, o.y * 16 + 8)

func _nearest_open(c: Vector2i) -> Vector2i:
	if not nav.is_point_solid(c):
		return c
	for r in range(1, 3):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var q := c + Vector2i(dx, dy)
				if nav.is_in_boundsv(q) and not nav.is_point_solid(q):
					return q
	return c

func zone_at(p: Vector2) -> String:
	if builder == null:
		return ""
	return builder.zone_at_cell(int(p.x / 16.0), int(p.y / 16.0))

func is_zone_dark(zone: String) -> bool:
	return zone_power.get(zone, true) == false

## 0 = lit, 1 = shadow (dim), 2 = pitch dark (blacked-out zone, or an
## interior spot whose only light just died). Pitch dark makes unaware
## enemies practically blind.
func darkness_at(p: Vector2) -> int:
	var z := zone_at(p)
	var lv := light_level_at(p)
	if is_zone_dark(z) and lv < 0.35:
		return 2
	if lv < 0.08 and z != "exterior":
		return 2
	return 1 if lv < 0.35 else 0

func light_level_at(p: Vector2) -> float:
	var v := 0.15 if dark_modulate.color.r >= ambient.r * 0.9 and not is_zone_dark(zone_at(p)) else 0.0
	for l in lights:
		if is_instance_valid(l):
			v += l.level_at(p)
	for f in get_tree().get_nodes_in_group("flares"):
		v += f.light_level_at(p)
	return v

## Cut or restore a zone's power. cause: "switch" (guards may come and flip
## it back), "fuse" (smashed box: dark for good), "enemy", "boss".
func set_zone_lights(zone: String, on: bool, cause := "") -> void:
	if on and dead_zones.has(zone):
		return
	var was_on: bool = not is_zone_dark(zone)
	for l in lights:
		if is_instance_valid(l) and l.zone == zone:
			l.set_on(on)
	zone_power[zone] = on
	if cause == "fuse" and not on:
		dead_zones[zone] = true
	if darkness and cause != "boss":
		darkness.set_dark(zone, not on)
	if was_on == on:
		return
	Events.lights_changed.emit(StringName(zone), on)
	if cause != "boss" and player and is_instance_valid(player) and hud:
		Audio.play("power_down" if not on else "power_up", -6.0 if zone_at(player.global_position) == zone else -14.0)
		if not on and zone_at(player.global_position) == zone and _hints_shown.get("dark_tip", false) == false:
			_hints_shown["dark_tip"] = true
			hud.show_hint("LIGHTS OUT — unaware guards can't see you in the dark. Get close and TAKE THEM DOWN.", 4.0)
		elif on and cause == "enemy":
			hud.show_hint("SOMEONE TURNED THE LIGHTS BACK ON", 2.0)
	if not on and cause == "switch":
		_send_fixer(zone)

func _send_fixer(zone: String) -> void:
	await get_tree().create_timer(randf_range(3.0, 5.0), false).timeout
	if not is_inside_tree() or not is_zone_dark(zone) or dead_zones.has(zone):
		return
	var sw: Node2D = null
	for s2 in switches:
		if is_instance_valid(s2) and s2.zone == zone:
			sw = s2
			break
	if sw == null:
		return
	var best: Enemy = null
	var bd := 520.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.has_method("can_fix_lights") or not e.can_fix_lights():
			continue
		var d := (e as Node2D).global_position.distance_to(sw.global_position)
		if d < bd:
			bd = d
			best = e
	if best:
		best.go_fix(sw)

func _assign_upgrades() -> void:
	var owned: Array = player.upgrades.keys()
	var taken: Array = []
	for up in upgrade_pickups:
		if not is_instance_valid(up):
			continue
		if up.upgrade_id == &"" or owned.has(up.upgrade_id) or taken.has(up.upgrade_id):
			up.upgrade_id = Upgrades.roll(owned, taken)
		taken.append(up.upgrade_id)
		if up.upgrade_id == &"":
			up.queue_free()
			continue
		var glow := up.get_node_or_null("Glow") as PointLight2D
		if glow:
			glow.color = Upgrades.def(up.upgrade_id).color
		up.collected.connect(func(p): collected[p.item_id] = true)

func _obj(k: String, fallback: String) -> String:
	return tr(str(data.get("objectives", {}).get(k, fallback)))

func remaining_enemies() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.required and e != boss:
			out.append(e)
	return out

# ======================================================================= loop
func _process(delta: float) -> void:
	_t += delta
	if player == null:
		return
	if not player.alive:
		if _restart_ready and (Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("fire")):
			Game.restart_level()
		return
	var cell := Vector2i(int(player.global_position.x / 16.0), int(player.global_position.y / 16.0))
	_check_hints(cell)
	_check_checkpoints(cell)
	if not _boss_triggered and boss and is_instance_valid(boss):
		var br: Array = data.get("boss_trigger", [])
		if br.size() == 4 and Rect2i(br[0], br[1], br[2], br[3]).has_point(cell):
			_start_boss(true)
	var inside: Array = data.get("inside_rect", [4, 0, 200, 42])
	if phase == Phase.INFILTRATE and Rect2i(inside[0], inside[1], inside[2], inside[3]).has_point(cell):
		phase = Phase.CLEAR
		_update_objective()
	# music intensity
	# alerted enemies drive the score: anyone hunting nearby brings in the
	# drums, several with eyes on you at once is danger; the combo climbs it
	# further (the pulse is in every layer, so the beat never drops out)
	var intensity := 0
	var spotting := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.is_aware() and e.global_position.distance_to(player.global_position) < 400.0:
			intensity = 1
			if e._sees_player:
				spotting += 1
	if Score.combo >= 3 or spotting >= 2:
		intensity = 2
	if Score.combo >= 6 or spotting >= 4:
		intensity = 3
	if phase == Phase.BOSS and boss and boss.phase == 2:
		intensity = 2
	if phase >= Phase.PHONE:
		intensity = 0
	Music.set_intensity(intensity)

## FINAL TAKE: the world drops to slow motion for a moment (real time),
## unless the player's own slow-mo is already running.
func _on_finisher(_pos: Vector2) -> void:
	Events.camera_punch.emit(1.2, 0.5)
	PostFX.flash(UIStyle.PINK, 0.25)
	Game.timed_slowmo(0.3, 0.9)

func _on_beat_kill(streak: int, _pos: Vector2) -> void:
	PostFX.flash(UIStyle.GOLD, 0.06 + minf(streak, 5) * 0.015)
	Events.camera_punch.emit(1.03 + minf(streak, 5) * 0.008, 0.12)

func _check_hints(cell: Vector2i) -> void:
	for hdef in data.get("hints", []):
		var id := str(hdef.id)
		if _hints_shown.has(id) or SaveManager.get_flag("hint_" + id, false):
			continue
		var r: Array = hdef.rect
		if Rect2i(r[0], r[1], r[2], r[3]).has_point(cell):
			_hints_shown[id] = true
			SaveManager.data.story.flags["hint_" + id] = true
			hud.show_hint(tr(str(hdef.text)), 5.0)

## Checkpoints: each area has one, marked on the floor at the entrance you
## come in by. It saves when you're in the area AND it's fair to: nobody
## alerted near you or watching you, and you're not mid-dodge. You come back
## at the marker, not wherever you happened to be standing.
var _cp_markers: Array = []
var _mission_start := Vector2.ZERO

## Smashable scenery along the walls of rooms, chosen by floor type so it
## suits the place (vases and chairs in motel rooms, crates and drums in the
## yard). Deterministic, spaced out, clear of doors and the start.
const SMASH_BY_FLOOR := {
	".": ["vase", "chair", "box"], ",": ["box", "vase", "crate"], "_": ["crate", "box"], "=": ["vase"],
	"+": ["crate", "box", "crate"], ";": ["drum", "crate"], "\"": ["chair", "vase"],
}
func _scatter_smashables() -> void:
	if builder == null:
		return
	var placed: Array[Vector2i] = []
	var start := Vector2i(_mission_start / 16.0)
	var budget := 20
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(data.get("id", "lvl")))
	var cells: Array[Vector2i] = []
	for y in range(1, builder.h - 1):
		for x in range(1, builder.w - 1):
			cells.append(Vector2i(x, y))
	# shuffle deterministically
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	for c in cells:
		if budget <= 0:
			break
		var f := builder.ch(c.x, c.y)
		if not SMASH_BY_FLOOR.has(f) or nav.is_point_solid(c) or c.distance_to(start) < 7.0:
			continue
		var walls := 0
		var near_door := false
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n := builder.ch(c.x + dx, c.y + dy)
				if n == "D" or n == "L" or n == "W":
					near_door = true
				if absi(dx) + absi(dy) == 1 and n == "#":
					walls += 1
		if walls == 0 or near_door:
			continue
		var clear := true
		for q in placed:
			if q.distance_to(c) < 4.0:
				clear = false
				break
		if not clear:
			continue
		var kinds: Array = SMASH_BY_FLOOR[f]
		var sm := Smashable.new()
		sm.setup(str(kinds[rng.randi() % kinds.size()]), c, self, rng.randi() % 1000)
		props_root.add_child(sm)
		placed.append(c)
		budget -= 1

## Security cameras from the level's "cameras" list: {"cell": [x, y],
## "angle": degrees (0 right, 90 down)}. Mounted against the wall behind
## them. Checkpoint restarts bring broken ones back (they're cheap to dodge).
func _build_cameras() -> void:
	for c in data.get("cameras", []):
		var cam := SecurityCamera.new()
		cam.base_angle = deg_to_rad(float(c.get("angle", 90)))
		cam.position = Vector2(float(c.cell[0]), float(c.cell[1])) * 16.0 + Vector2(8, 8) - Vector2.from_angle(cam.base_angle) * 4.0
		props_root.add_child(cam)
	for c in data.get("film_cameras", []):
		var fc := FilmCamera.new()
		fc.facing = Vector2.from_angle(deg_to_rad(float(c.get("angle", 90))))
		fc.position = Vector2(float(c.cell[0]), float(c.cell[1])) * 16.0 + Vector2(8, 8) - fc.facing * 5.0
		props_root.add_child(fc)

func _build_checkpoint_markers() -> void:
	var cps: Array = data.get("checkpoints", [])
	var from := _mission_start
	for i in cps.size():
		var r: Array = cps[i].rect
		var rect := Rect2i(r[0], r[1], r[2], r[3])
		var cell := _entrance_cell(rect, from)
		var m := CheckpointMarker.new()
		m.position = Vector2(cell) * 16.0 + Vector2(8, 8)
		floor_root.add_child(m)
		if _checkpoints_hit.has(str(i)):
			m.activate(true)
		_cp_markers.append(m)

## The walkable cell just inside the area next to a way in (a door or an
## open gap), preferring the one nearest the mission start: the way you'll
## actually arrive.
func _entrance_cell(rect: Rect2i, from: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	var fallback := Vector2i(-1, -1)
	var fb_d := INF
	var centre := Vector2(rect.get_center()) * 16.0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if not nav.is_in_boundsv(c) or nav.is_point_solid(c):
				continue
			var dc := Vector2(c) * 16.0
			if dc.distance_to(centre) < fb_d:
				fb_d = dc.distance_to(centre)
				fallback = c
			var edge := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + o
				if rect.has_point(n) or not nav.is_in_boundsv(n):
					continue
				var chr: String = builder.ch(n.x, n.y) if builder else ""
				if chr == "D" or chr == "L" or not nav.is_point_solid(n):
					edge = true
			if edge:
				# one step further in, so the marker isn't in the doorway
				var d := dc.distance_to(from)
				if d < best_d:
					best_d = d
					best = c
	return best if best.x >= 0 else fallback

func _checkpoint_safe() -> bool:
	if player.is_dashing():
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.is_aware() and (e._sees_player or e.global_position.distance_to(player.global_position) < 260.0):
			return false
	return true

func _check_checkpoints(cell: Vector2i) -> void:
	var cps: Array = data.get("checkpoints", [])
	for i in cps.size():
		if _checkpoints_hit.has(str(i)):
			continue
		var r: Array = cps[i].rect
		if Rect2i(r[0], r[1], r[2], r[3]).has_point(cell) and _checkpoint_safe():
			_checkpoints_hit[str(i)] = true
			var spawn := player.global_position
			if i < _cp_markers.size():
				(_cp_markers[i] as CheckpointMarker).activate()
				spawn = (_cp_markers[i] as Node2D).global_position
			_save_checkpoint(str(cps[i].get("name", "CHECKPOINT")), spawn)

func _save_checkpoint(cp_name: String, spawn: Vector2) -> void:
	Game.checkpoint_state = {
		"spawn": spawn,
		"killed": killed_ids.keys(),
		"collected": collected.keys(),
		"weapons": player.weapon_state(),
		"equipment": player.equipment_left,
		"checkpoints": _checkpoints_hit.duplicate(),
		"hints": _hints_shown.duplicate(),
		"phase": phase,
		"score": Score.snapshot(),
		"upgrades": player.upgrade_state(),
		"dead_zones": dead_zones.keys(),
	}
	Events.checkpoint_reached.emit(_checkpoints_hit.size())
	hud.show_checkpoint(tr(cp_name))

func _update_objective() -> void:
	match phase:
		Phase.INFILTRATE:
			Events.objective_changed.emit(_obj("infiltrate", "GET INSIDE THE SUNSET PALMS"))
		Phase.CLEAR:
			var n := remaining_enemies().size()
			if boss and is_instance_valid(boss) and boss.is_alive():
				Events.objective_changed.emit(tr("%s  ·  %d LEFT  ·  FIND THE NIGHT MANAGER") % [_obj("clear", "CLEAR THE MOTEL"), n])
			else:
				Events.objective_changed.emit(tr("%s  ·  %d LEFT") % [_obj("clear", "CLEAR THE MOTEL"), n])
		Phase.BOSS:
			Events.objective_changed.emit(tr("DEAL WITH HARCOURT"))
		Phase.BOSS_DOWN:
			Events.objective_changed.emit("")
		Phase.PHONE:
			var left := remaining_enemies().size()
			if left > 0:
				Events.objective_changed.emit(tr("FINISH THE JOB  ·  %d LEFT") % left)
			else:
				Events.objective_changed.emit(tr("THE PHONE IS RINGING"))
		Phase.ESCAPE:
			Events.objective_changed.emit(_obj("escape", "GET BACK TO THE CAR"))

func objectives_text() -> String:
	var lines := PackedStringArray()
	lines.append("%s — %s" % [tr(mission.title), tr(mission.location)])
	lines.append(tr(mission.date_text))
	lines.append("")
	lines.append(tr("OBJECTIVE: ") + hud.objective_label.text)
	lines.append(tr("ENEMIES LEFT: %d") % remaining_enemies().size())
	lines.append(tr("SCORE: %d    MAX COMBO: %d") % [Score.score, Score.max_combo])
	lines.append(tr("TIME: %s") % _fmt_time(Score.elapsed))
	var found := 0
	for k in data.get("collectibles", {}).keys():
		if collected.has(data.collectibles[k].id) or data.collectibles[k].id in SaveManager.data.collectibles:
			found += 1
	lines.append(tr("TAPES & EVIDENCE: %d / %d") % [found, data.get("collectibles", {}).size()])
	lines.append(tr("SECRETS: %d") % secrets_found.size())
	lines.append("")
	lines.append("\"%s\"" % tr(mission.briefing))
	return "\n".join(lines)

static func _fmt_time(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]

# ======================================================================= combat events
func _on_enemy_died(e: Enemy, _info: DamageInfo) -> void:
	killed_ids[e.enemy_id] = true
	enemies.erase(e)
	_update_objective()
	if phase == Phase.CLEAR or phase == Phase.PHONE:
		_maybe_ring_phone()
	# missions without a boss or phone: clearing the floor opens the way out
	if (phase == Phase.CLEAR or phase == Phase.INFILTRATE) and boss == null and phone == null and remaining_enemies().is_empty():
		await get_tree().create_timer(0.8, false).timeout
		if phase != Phase.ESCAPE and phase != Phase.DONE:
			Music.play("aftermath")
			hud.show_banner(_obj("cleared", "CLEARED"), 2.0, UIStyle.GOLD)
			_begin_escape()

func _on_player_died(_info: Dictionary) -> void:
	Score.running = false
	PostFX.set_desaturate(0.6)
	Audio.set_music_muffled(true)
	Music.duck(0.5)
	SaveManager.add_stat("deaths")
	_restart_ready = false
	await get_tree().create_timer(0.45, true, false, true).timeout
	_restart_ready = true

func on_alarm(pos: Vector2, budget := 3) -> void:
	if _alarm_spawned:
		return
	_alarm_spawned = true
	if budget > 0:
		spawn_reinforcements(budget, pos)

func spawn_reinforcements(n: int, _near := Vector2.ZERO) -> void:
	if reinforcement_points.is_empty():
		return
	for i in n:
		var p: Vector2 = reinforcement_points[randi() % reinforcement_points.size()]
		var e := Enemy.new()
		e.enemy_id = "reinf_%d_%d" % [Time.get_ticks_msec(), i]
		e.required = false
		e.position = p + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		actors_root.add_child(e)
		e.setup(DB.enemy(&"guard" if randf() > 0.4 else &"gunner"), self, Vector2.DOWN)
		e.died.connect(_on_enemy_died)
		# called in over the radio: they know the area, not the exact spot
		var err := Tuning.get_t().position_error_max
		e._last_known = player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(err * 0.3, err)
		e._enter_combat()

func on_secret_found(id: String) -> void:
	if id in secrets_found:
		return
	secrets_found.append(id)
	if not id in SaveManager.data.secrets:
		SaveManager.data.secrets.append(id)
		SaveManager.save_game()
	Audio.play("collect")
	Score.add_bonus("SECRET", 1500, player.global_position)
	hud.show_hint("SECRET FOUND", 2.0)

func _on_collectible(it: Interactable, _by: Node) -> void:
	collected[it.item_id] = true
	var fresh := SaveManager.add_collectible(it.item_id)
	Audio.play("collect")
	Score.add_bonus("EVIDENCE", 1000 if fresh else 250, it.global_position)
	Events.collectible_found.emit(StringName(it.item_id))
	hud.show_banner(tr(str(it.get_meta("title", ""))), 2.0, UIStyle.GOLD)
	await get_tree().create_timer(0.4).timeout
	var tmp := {"start": "a", "nodes": {"a": {"speaker": "narration", "text": str(it.get_meta("text", ""))}}}
	_run_inline_dialogue(tmp)

func _run_inline_dialogue(d: Dictionary) -> void:
	Dialogue._data = d
	Dialogue._id = "inline"
	Dialogue._pause_game = true
	Dialogue.active = true
	Dialogue.root.visible = true
	get_tree().paused = true
	Dialogue._input_block = 0.3
	Dialogue._goto("a")

# ======================================================================= boss
func _start_boss(with_intro: bool) -> void:
	_boss_triggered = true
	phase = Phase.BOSS
	_update_objective()
	Music.play(mission.boss_track)
	if Game.checkpoint_state.get("boss_seen", false):
		with_intro = false
	if not Game.checkpoint_state.is_empty():
		Game.checkpoint_state["boss_seen"] = true
	if with_intro:
		Dialogue.start("m01_boss_intro")
	else:
		boss.activate()

func boss_lights_out() -> void:
	set_zone_lights("lobby", false, "boss")
	var tw := create_tween()
	tw.tween_property(dark_modulate, "color", ambient * 0.28, 0.6)
	player_light.energy = 0.9
	hud.show_hint("HE CUT THE POWER. WATCH FOR HIS FLASHLIGHT.", 3.0)
	PostFX.vhs_glitch(0.7)
	Music.set_intensity(2)

func _on_boss_defeated(_b: BossNightManager) -> void:
	phase = Phase.BOSS_DOWN
	_update_objective()
	Music.stop(1.5)
	await get_tree().create_timer(0.9).timeout
	Dialogue.start("m01_boss_down")

func _on_dialogue_event(ev: String) -> void:
	match ev:
		"boss_start":
			if boss and is_instance_valid(boss):
				boss.activate()
				spawn_reinforcements(2)
		"boss_execute":
			if boss and is_instance_valid(boss):
				player.visual.swing(true)
				Audio.play_at("execute", boss.global_position)
				Events.hit_stop.emit(0.15)
				boss.resolve(true, player)
		"boss_spare":
			if boss and is_instance_valid(boss):
				boss.resolve(false, player)
		"phone_done":
			_begin_escape()

func _on_dialogue_finished(id: String) -> void:
	if id == "m01_boss_down":
		var tw := create_tween()
		tw.tween_property(dark_modulate, "color", ambient, 1.5)
		phase = Phase.PHONE
		_begin_phone()

func _begin_phone() -> void:
	phase = Phase.PHONE
	Music.play("aftermath")
	_update_objective()
	_maybe_ring_phone()

func _maybe_ring_phone() -> void:
	if phase != Phase.PHONE or phone == null:
		return
	if remaining_enemies().is_empty():
		phone.enabled = true
		phone.ringing = true
		Events.objective_changed.emit(tr("THE PHONE IS RINGING"))
		hud.show_hint("THE FRONT DESK PHONE IS RINGING", 3.0)

func _on_phone(_it: Interactable, _by: Node) -> void:
	Dialogue.start("m01_phone")

func _begin_escape() -> void:
	phase = Phase.ESCAPE
	for d in locked_doors:
		if is_instance_valid(d):
			d.unlock()
	if exit_car:
		exit_car.enabled = true
	_update_objective()
	PostFX.set_desaturate(0.35)
	hud.show_hint(_obj("escape_hint", "THE FRONT DOORS ARE OPEN"), 2.5)

func _on_exit(_it: Interactable, _by: Node) -> void:
	if phase != Phase.ESCAPE:
		return
	phase = Phase.DONE
	player.input_enabled = false
	Audio.play("door_slam")
	await get_tree().create_timer(0.5).timeout
	_complete()

func _complete() -> void:
	var result := Score.finish()
	var rank := Score.compute_rank(result, mission.par_score, mission.par_time)
	result.merge(rank, true)
	result["mission_id"] = String(mission.id)
	result["character"] = String(player.data.id)
	result["collectibles"] = collected.size()
	result["secrets"] = secrets_found.size()
	result["harcourt"] = "spared" if SaveManager.get_flag("harcourt_spared") else "killed"
	var rec := SaveManager.record_mission(String(mission.id), {"score": rank.total, "rank": rank.rank, "time": result.time, "character": result.character})
	result.merge(rec, true)
	SaveManager.add_stat("play_time", result.time)
	SaveManager.save_game()
	Game.checkpoint_state = {}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Events.level_completed.emit(result)
	Game.mission_complete(result)

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.set_slowmo(1.0)
	if Dialogue.event.is_connected(_on_dialogue_event):
		Dialogue.event.disconnect(_on_dialogue_event)
	if Dialogue.finished.is_connected(_on_dialogue_finished):
		Dialogue.finished.disconnect(_on_dialogue_finished)
