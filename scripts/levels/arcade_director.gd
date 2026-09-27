class_name ArcadeDirector
extends Node
## Arcade WAVES / ENDLESS runs on a mission map. The placed cast is cleared
## out; waves of enemies come in rows from the far side of the map, each wave
## bigger and meaner than the last. Between waves a supply drop lands near
## you. Modifiers (Game.modifiers) stack on top:
##   infinite_ammo  magazines never empty (handled in Player._try_shoot)
##   roulette       every ROULETTE_EVERY seconds your gun turns into another
##   turbo          everyone moves faster (Player speed + Engine time scale)
##   melee_only / no_ability / hard  as in score attack
## The run ends when you die or clear the last wave; either way it goes to
## the results screen and the local board for "<mission>@<mode>".

const ROULETTE_EVERY := 14.0
const BREAK_TIME := 5.0
const ROW_GAP := 2.6
## [first wave it appears, archetype, weight]
const ROSTER := [
	[1, &"guard", 5.0], [1, &"gunner", 3.0], [2, &"hunter", 3.0], [3, &"heavy", 1.5],
	[3, &"scrapper", 2.0], [4, &"riot", 1.2], [4, &"dog", 1.5], [5, &"biker", 2.0],
	[5, &"welder", 1.5], [6, &"dog_rott", 1.2], [7, &"bellhop", 1.0],
]
const DROP_GUNS := [&"pistol", &"smg", &"shotgun", &"revolver", &"rifle", &"whisper"]
const DROP_MELEE := [&"bat", &"machete", &"knife", &"pipe"]

var level: Level
var mode := "waves"            ## waves | endless
var total_waves := 8
var wave := 0
var alive: Array = []
var _queue: Array = []          ## [[kind, delay], ...] still to spawn this wave
var _spawn_t := 0.0
var _break_t := 0.0
var _roulette_t := 0.6        ## roulette deals the first gun almost at once
var _over := false
var _spawn_cells: Array[Vector2i] = []

func setup(p_level: Level) -> void:
	level = p_level
	mode = str(Game.modifiers.get("mode", "waves"))
	total_waves = int(Game.modifiers.get("waves", 8))
	# clear the placed cast: this map is an arena now
	for e in level.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	level.enemies.clear()
	level.boss = null
	if level.phone:
		level.phone.enabled = false
		level.phone = null
	if level.exit_car:
		level.exit_car.enabled = false
	level.phase = Level.Phase.CLEAR
	_collect_spawn_cells()
	_break_t = 2.5

func title() -> String:
	return tr("ENDLESS") if mode == "endless" else tr("WAVES")

## Walkable cells far enough apart to hide a spawn; picked each time by
## distance from the player.
func _collect_spawn_cells() -> void:
	var b := level.builder
	for y in range(1, b.h - 1, 2):
		for x in range(1, b.w - 1, 2):
			var c := Vector2i(x, y)
			if level.nav.is_point_solid(c) or b.floor_grid[y][x] == "" or b.floor_grid[y][x] == "~":
				continue
			_spawn_cells.append(c)

func _pick_spawn() -> Vector2:
	var pp := level.player.global_position
	var best := Vector2.ZERO
	var tries := 0
	while tries < 40:
		tries += 1
		var c: Vector2i = _spawn_cells[randi() % _spawn_cells.size()]
		var p := Vector2(c) * 16.0 + Vector2(8, 8)
		var d := p.distance_to(pp)
		if d > 320.0 and d < 900.0:
			return p
		if best == Vector2.ZERO or absf(d - 500.0) < absf(best.distance_to(pp) - 500.0):
			best = p
	if not level.reinforcement_points.is_empty():
		return level.reinforcement_points[randi() % level.reinforcement_points.size()]
	return best

func _process(delta: float) -> void:
	if _over or level == null or level.player == null or not level.player.alive:
		return
	var rd := delta / maxf(Engine.time_scale, 0.05)
	if Game.modifiers.get("roulette", false):
		_roulette_t -= rd
		if _roulette_t <= 0.0:
			_roulette_t = ROULETTE_EVERY
			_spin_roulette()
		elif _roulette_t < 3.0 and int(_roulette_t * 4.0) != int((_roulette_t + rd) * 4.0):
			Audio.play("ui_move", -10.0, 1.4)
	if _break_t > 0.0:
		_break_t -= rd
		if _break_t <= 0.0:
			_start_wave()
		return
	if not _queue.is_empty():
		_spawn_t -= rd
		while _spawn_t <= 0.0 and not _queue.is_empty():
			var it: Array = _queue.pop_front()
			_spawn(it[0])
			_spawn_t += float(it[1])
	_objective()

func _start_wave() -> void:
	wave += 1
	var n := mini(3 + wave * 2, 24)
	var rows := clampi(1 + wave / 2, 1, 4)
	var per_row := ceili(float(n) / rows)
	_queue.clear()
	for r in rows:
		for i in per_row:
			if _queue.size() >= n:
				break
			var last := i == per_row - 1
			_queue.append([_roll_kind(), ROW_GAP if last else 0.15])
	_spawn_t = 0.0
	level.hud.show_banner(tr("WAVE %d") % wave if mode == "endless" else tr("WAVE %d / %d") % [wave, total_waves], 1.6, UIStyle.PINK)
	Audio.play("on_air_buzz", -4.0)
	PostFX.vhs_glitch(0.4)
	Music.set_intensity(2)

func _roll_kind() -> StringName:
	var pool: Array = []
	var total := 0.0
	var roster: Array = level.data.get("arcade_roster", ROSTER)
	for r in roster:
		if wave >= int(r[0]) and DB.enemy(StringName(r[1])) != null:
			pool.append(r)
			total += float(r[2])
	var k := randf() * total
	for r in pool:
		k -= float(r[2])
		if k <= 0.0:
			return StringName(r[1])
	return StringName(roster[0][1]) if not roster.is_empty() else &"guard"

func _spawn(kind: StringName) -> void:
	var data := DB.enemy(kind)
	if data == null:
		return
	var e: Enemy
	if kind == &"dog" or kind == &"dog_rott" or kind == &"hellhound":
		e = Dog.new()
	else:
		e = Enemy.new()
	e.enemy_id = "arc_%d_%d" % [wave, Time.get_ticks_usec()]
	e.required = true
	e.position = _pick_spawn()
	level.actors_root.add_child(e)
	e.setup(data, level, Vector2.from_angle(randf() * TAU))
	if Game.modifiers.get("hard", false) or wave >= 6:
		e.data = e.data.duplicate()
		var k := 1.0 - minf(0.35, 0.04 * wave) if not Game.modifiers.get("hard", false) else 0.65
		e.data.reaction_time *= k
	if e is Dog:
		(e as Dog).sleeping = false
	e.died.connect(level._on_enemy_died)
	var err := Tuning.get_t().position_error_max
	e._last_known = level.player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(err * 0.2, err * 0.7)
	e._enter_combat()
	alive.append(e)
	Effects.dust(e.global_position, Vector2.ZERO, 1.5)

func on_enemy_died(e: Enemy) -> void:
	alive.erase(e)
	alive = alive.filter(func(x): return is_instance_valid(x) and x.is_alive())
	if _queue.is_empty() and alive.is_empty() and _break_t <= 0.0 and not _over:
		_wave_cleared()

func _wave_cleared() -> void:
	Score.add_bonus(tr("WAVE %d CLEAR") % wave, 1000 * wave, level.player.global_position)
	Audio.play("applause", -6.0)
	Music.set_intensity(0)
	if mode != "endless" and wave >= total_waves:
		_over = true
		level.hud.show_banner(tr("ALL WAVES CLEARED"), 2.5, UIStyle.GOLD)
		await get_tree().create_timer(2.2, false).timeout
		finish(true)
		return
	level.hud.show_banner(tr("WAVE %d CLEAR") % wave, 1.8, UIStyle.GOLD)
	_break_t = BREAK_TIME
	_supply_drop()

## A couple of weapons land near the player between waves.
func _supply_drop() -> void:
	var pp := level.player.global_position
	for i in 2:
		var pool: Array = DROP_GUNS if not Game.modifiers.get("melee_only", false) else DROP_MELEE
		if i == 1 and randf() < 0.4:
			pool = DROP_MELEE
		var id: StringName = pool[randi() % pool.size()]
		var d := DB.weapon(id)
		if d == null:
			continue
		var at := level.nearest_open_point(pp + Vector2.from_angle(randf() * TAU) * randf_range(40, 80), pp)
		WeaponPickup.spawn(level.pickup_root(), WeaponInstance.create(d), at)
	Audio.play("pickup", -4.0)
	level.hud.show_hint(tr("SUPPLY DROP"), 1.5)

func _spin_roulette() -> void:
	var p := level.player
	var pool: Array = DROP_MELEE.duplicate() if Game.modifiers.get("melee_only", false) else DROP_GUNS + DROP_MELEE
	var id: StringName = pool[randi() % pool.size()]
	if DB.weapon(id) == null:
		return
	p.give_weapon(id)
	Audio.play("slide_rack", -2.0)
	PostFX.flash(UIStyle.GOLD, 0.15)
	level.hud.show_banner(tr("ROULETTE: %s") % tr(DB.weapon(id).display_name).to_upper(), 1.2, UIStyle.CYAN)

func _objective() -> void:
	var left := alive.size() + _queue.size()
	var head := tr("WAVE %d") % wave if mode == "endless" else tr("WAVE %d / %d") % [wave, total_waves]
	var txt := "%s  ·  %s" % [head, tr("%d LEFT") % left]
	if level.hud.objective_label.text != txt:
		Events.objective_changed.emit(txt)

func player_died() -> void:
	if _over:
		return
	_over = true
	await get_tree().create_timer(1.8, true, false, true).timeout
	finish(false)

func finish(won: bool) -> void:
	var result := Score.finish()
	# no time bonus in a survival run (dying early must not pay); the par
	# grows with the number of waves asked for
	var timeless := result.duplicate()
	timeless.time = 1.0
	var par := int(level.mission.par_score * (float(total_waves) / 6.0 if mode == "waves" else 1.2))
	var rank := Score.compute_rank(timeless, par, 1.0)
	result.merge(rank, true)
	var key := "%s@%s" % [String(level.mission.id), mode]
	result["mission_id"] = String(level.mission.id)
	result["character"] = String(level.player.data.id)
	result["arcade"] = {"mode": mode, "wave": wave, "won": won}
	var rec := SaveManager.record_mission(key, {"score": rank.total, "rank": rank.rank, "time": result.time, "character": result.character})
	result.merge(rec, true)
	SaveManager.add_stat("play_time", result.time)
	SaveManager.save_game()
	Game.checkpoint_state = {}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.mission_complete(result)
