extends Node
## Autoplay: a bot that plays the whole campaign on Normal, in a window,
## through the same input actions a player uses (gamepad-style: move and
## aim sticks, fire, dash, reload, interact, execute). Built for playtesting:
## it logs every death (where, to what, which checkpoint), stuck spots,
## retries and time per mission to user://autoplay_log.txt, and saves a
## screenshot every SHOT_EVERY seconds to user://autoplay_shots/.
##   godot --path . res://tools/autoplay.tscn
## Env: AUTOPLAY_FROM=<campaign step>  AUTOPLAY_MISSION=<id> (one mission)
##      AUTOPLAY_ASSIST_AFTER=<deaths at one checkpoint before the bot gets
##      a guard hit, default 10>  AUTOPLAY_SHOTS=0 to skip screenshots

const SHOT_EVERY := 12.0
const REPATH := 0.35

var log_lines: PackedStringArray = []
var _t := 0.0
var _shot_t := 3.0
var _path: PackedVector2Array = []
var _path_t := 0.0
var _goal := Vector2.ZERO
var _stuck_t := 0.0
var _last_pos := Vector2.ZERO
var _fire_toggle := false
var _mission_t := 0.0
var _deaths: Dictionary = {}         ## "mission|checkpoint" -> count
var _mission := ""
var _dead_logged := false
var _results_t := 0.0
var _wander := Vector2.ZERO
var _wander_t := 0.0
var _shot_n := 0

func _ready() -> void:
	Engine.set_meta("autoplay", true)
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var ph := Node.new()
	ph.name = "Placeholder"
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://autoplay_shots"))
	InputSetup.using_gamepad = true
	SaveManager.set_setting("difficulty", 1)
	SaveManager.set_setting("aim_assist", 0.8)
	_log("autoplay start: Normal difficulty")
	var only := OS.get_environment("AUTOPLAY_MISSION")
	if only != "":
		Game.replay_mission(only)
	else:
		Game.new_game()
		var from := OS.get_environment("AUTOPLAY_FROM")
		if from != "":
			Game.advance_to(int(from))

func _log(s: String) -> void:
	var line := "[%6.1f] %s" % [_t, s]
	print(line)
	log_lines.append(line)
	var f := FileAccess.open("user://autoplay_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))

func _physics_process(delta: float) -> void:
	_t += delta
	var scene := get_tree().current_scene
	_release_all_soft()
	if Dialogue.active:
		_drive_dialogue()
	elif scene and scene.name == "Results":
		_results_t += delta
		if _results_t > 5.0:
			_results_t = 0.0
			_log("results: %s rank %s, %d pts, %s" % [_mission, str(Game.last_result.get("rank", "?")), int(Game.last_result.get("total", 0)), Level._fmt_time(float(Game.last_result.get("time", 0.0)))])
			if OS.get_environment("AUTOPLAY_MISSION") != "":
				get_tree().quit()
			else:
				Game.story_beat_finished()
	elif scene and scene.name == "TitleScreen":
		_log("back at the title: campaign over")
		_write_summary()
		get_tree().quit()
	var lvl := get_tree().get_first_node_in_group("level") as Level
	if lvl and not Dialogue.active:
		_play(lvl, delta)
	_shots(delta)

func _shots(delta: float) -> void:
	if OS.get_environment("AUTOPLAY_SHOTS") == "0":
		return
	_shot_t -= delta
	if _shot_t <= 0.0:
		_shot_t = SHOT_EVERY
		_shot_n += 1
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://autoplay_shots/%04d_%s.png" % [_shot_n, _mission if _mission != "" else "scene"])

# ------------------------------------------------------------------ dialogue
var _dlg_wait := 0.0
func _drive_dialogue() -> void:
	if not Dialogue._pause_game:
		return   # calls and barks play themselves
	_dlg_wait -= get_physics_process_delta_time()
	if _dlg_wait > 0.0:
		return
	_dlg_wait = 0.25
	if Dialogue.is_typing():
		return
	if not Dialogue._choices.is_empty():
		var i := randi() % Dialogue._choices.size()
		_log("choice in %s: '%s'" % [Dialogue._id, str(Dialogue._choices[i].get("text", ""))])
		Dialogue._pick(i)
		_dlg_wait = 0.8
	else:
		# give the line a moment on screen, like someone reading it
		_dlg_wait = 0.6 + Dialogue._full.length() / 60.0
		Dialogue._advance()

# ------------------------------------------------------------------ input
const AXES := ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down"]
func _release_all_soft() -> void:
	for a in ["fire", "dash", "reload", "interact", "execute", "secondary", "sprint", "swap"]:
		if Input.is_action_pressed(a) and not (a == "fire" and _holding_fire):
			Input.action_release(a)

func _stick(prefix: String, v: Vector2) -> void:
	var l := v.limit_length(1.0)
	for pair in [["left", -l.x], ["right", l.x], ["up", -l.y], ["down", l.y]]:
		var act: String = prefix + "_" + pair[0]
		var k: float = pair[1]
		if k > 0.05:
			Input.action_press(act, k)
		else:
			Input.action_release(act)

func _tap(a: String) -> void:
	Input.action_press(a)

var _holding_fire := false
func _fire(auto: bool) -> void:
	if auto:
		_holding_fire = true
		Input.action_press("fire")
	else:
		_holding_fire = false
		_fire_toggle = not _fire_toggle
		if _fire_toggle:
			Input.action_press("fire")
		else:
			Input.action_release("fire")

func _stop_fire() -> void:
	_holding_fire = false
	Input.action_release("fire")

# ------------------------------------------------------------------ playing a level
func _play(lvl: Level, delta: float) -> void:
	var p := lvl.player
	if p == null:
		return
	if _mission != String(lvl.mission.id):
		_mission = String(lvl.mission.id)
		_mission_t = 0.0
		_log("mission start: %s (attempt %d)" % [_mission, Game.attempts])
	_mission_t += delta
	if not p.alive:
		_stick("move", Vector2.ZERO)
		_stick("aim", Vector2.ZERO)
		_stop_fire()
		if not _dead_logged:
			_dead_logged = true
			var cp := _checkpoint_name(lvl)
			var key := "%s|%s" % [_mission, cp]
			_deaths[key] = int(_deaths.get(key, 0)) + 1
			_log("DIED in %s at cell %s (zone %s, after %s) - nearest threat: %s. deaths here: %d" % [_mission, str(Vector2i(p.global_position / 16.0)), lvl.zone_at(p.global_position), cp, _nearest_threat(lvl, p), _deaths[key]])
			var assist_after := int(OS.get_environment("AUTOPLAY_ASSIST_AFTER")) if OS.get_environment("AUTOPLAY_ASSIST_AFTER") != "" else 6
			if int(_deaths[key]) >= assist_after:
				_log("  (assist: the bot gets armour for this section)")
		if lvl._restart_ready:
			_tap("restart")
		return
	if _dead_logged:
		_dead_logged = false
		var key2 := "%s|%s" % [_mission, _checkpoint_name(lvl)]
		var aa := int(OS.get_environment("AUTOPLAY_ASSIST_AFTER")) if OS.get_environment("AUTOPLAY_ASSIST_AFTER") != "" else 6
		if int(_deaths.get(key2, 0)) >= aa:
			p.armor_hits = maxi(p.armor_hits, 2)
	var w: WeaponInstance = p.slots[p.slot]
	var has_gun := w != null and w.data.is_firearm() and (w.ammo > 0 or (w.dual and w.ammo2 > 0) or w.reserve > 0)
	# --- threats
	var target: Enemy = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive() or e.state == Enemy.State.EXECUTED or _unreachable.has(e.get_instance_id()):
			continue
		var d := (e as Node2D).global_position.distance_to(p.global_position)
		var weight := d * (0.6 if e.is_aware() else 1.0)
		if weight < best:
			best = weight
			target = e
	var visible_target: Enemy = null
	if target and target.global_position.distance_to(p.global_position) < (300.0 if has_gun else 140.0) and _los(p, target):
		visible_target = target
	# --- dodge a telegraphed swing or a flame
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.is_winding_up() and (e as Node2D).global_position.distance_to(p.global_position) < 40.0 and not p.is_dashing():
			_stick("move", (p.global_position - e.global_position).normalized())
			_tap("dash")
			return
	for f in get_tree().get_nodes_in_group("fires"):
		if (f as Node2D).global_position.distance_to(p.global_position) < f.radius + 8.0 and not f.friendly:
			_stick("move", (p.global_position - (f as Node2D).global_position).normalized())
			_tap("dash")
			return
	# --- what to walk to
	var goal := p.global_position
	var why := ""
	if lvl.phase == Level.Phase.ESCAPE and lvl.exit_car:
		goal = lvl.exit_car.global_position
		why = "car"
	elif lvl.breach and not lvl.breach.done and lvl.remaining_enemies().size() <= _breach_after(lvl):
		# blow the lobby: fetch the charges, plant them, then back off
		if lvl.breach.planted:
			goal = lvl.breach._plant_it.global_position + Vector2(0, 90)
			why = "clear of the blast"
		elif lvl.breach.has_charge:
			goal = lvl.breach._plant_it.global_position
			why = "plant"
			if goal.distance_to(p.global_position) < 20.0:
				lvl.breach._plant_it.interact(p)
		elif lvl.breach._charge_it:
			goal = lvl.breach._charge_it.global_position
			why = "charges"
			if goal.distance_to(p.global_position) < 16.0:
				lvl.breach._charge_it.interact(p)
	elif lvl.phone and lvl.phone.enabled and lvl.phone.ringing:
		goal = lvl.phone.global_position
		why = "phone"
	elif not has_gun and (w == null or not w.data.is_firearm()) and _nearest_gun(p) != null and _nearest_gun(p).global_position.distance_to(p.global_position) < 360.0:
		goal = _nearest_gun(p).global_position
		why = "gun"
	elif target:
		goal = target.global_position
		why = "enemy"
		_check_reachable(lvl, p, target)
	elif lvl.boss and is_instance_valid(lvl.boss) and lvl.boss.is_alive():
		goal = lvl.boss.global_position
		why = "boss"
	else:
		var r: Array = lvl.data.get("boss_trigger", [])
		if r.size() == 4:
			goal = Vector2(r[0] + r[2] * 0.5, r[1] + r[3] * 0.5) * 16.0
			why = "boss room"
	# interactables in reach
	if why == "car" and goal.distance_to(p.global_position) < 26.0:
		lvl.exit_car.interact(p)
	if why == "phone" and goal.distance_to(p.global_position) < 24.0:
		lvl.phone.interact(p)
	if why == "gun" and goal.distance_to(p.global_position) < 14.0:
		_tap("interact")
	# --- Spotlight when the room turns on her
	var aware_near := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and e.is_aware() and (e as Node2D).global_position.distance_to(p.global_position) < 220.0:
			aware_near += 1
	if aware_near >= 3 and p.ability and p.ability.can_activate():
		_tap("ability")
	# --- combat
	if visible_target:
		var to := visible_target.global_position - p.global_position
		_stick("aim", to.normalized())
		var dist := to.length()
		if visible_target.is_downed() and dist < 22.0:
			_tap("execute")
		elif has_gun:
			if w.ammo <= 0 and (not w.dual or w.ammo2 <= 0):
				_tap("reload")
			else:
				_fire(w.data.automatic)
			# keep some distance from melee rushers
			if visible_target.data.combat == EnemyData.Combat.MELEE_RUSHER and dist < 70.0:
				goal = p.global_position - to.normalized() * 60.0
				why = "kite"
			elif dist < 60.0 and visible_target.data.combat == EnemyData.Combat.SHOOTER:
				goal = p.global_position - to.normalized() * 50.0   # don't trade shots point blank
				why = "kite"
			elif dist < 180.0:
				goal = p.global_position   # hold and shoot
				why = "hold"
		else:
			if w and w.data.is_firearm() and dist < 90.0:
				_tap("secondary")   # empty gun: throw it
			elif dist < 26.0:
				_fire(false)
			goal = visible_target.global_position
			why = "melee"
	else:
		_stop_fire()
		if w and w.data.is_firearm() and w.ammo < w.data.magazine and w.reserve > 0:
			_tap("reload")
		_stick("aim", Vector2.ZERO)
	_walk(lvl, p, goal, delta, why)

func _walk(lvl: Level, p: Player, goal: Vector2, delta: float, why: String) -> void:
	_path_t -= delta
	if _path_t <= 0.0 or goal.distance_to(_goal) > 24.0:
		_path_t = REPATH
		_goal = goal
		_path = lvl.get_nav_path(p.global_position, goal)
	while _path.size() > 0 and _path[0].distance_to(p.global_position) < 9.0:
		_path.remove_at(0)
	var dir := Vector2.ZERO
	if why != "hold" and _path.size() > 0:
		dir = (_path[0] - p.global_position).normalized()
	# stuck: jiggle sideways and dash
	if dir != Vector2.ZERO and p.global_position.distance_to(_last_pos) < 0.4:
		_stuck_t += delta
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta * 2.0)
	_last_pos = p.global_position
	if _stuck_t > 1.2:
		if _wander_t <= 0.0:
			_wander = dir.rotated(PI * 0.5 * (1 if randf() < 0.5 else -1))
			_wander_t = 0.6
			_log("stuck near cell %s heading for %s" % [str(Vector2i(p.global_position / 16.0)), why])
		_wander_t -= delta
		dir = _wander
		if _stuck_t > 2.5:
			_tap("dash")
			_stuck_t = 0.0
	_stick("move", dir)

## An enemy the nav grid can't lead to is a level bug: log it, skip it,
## and if only unreachable ones are left, clear them so the run goes on.
var _unreachable: Dictionary = {}
var _reach_t := 0.0
func _check_reachable(lvl: Level, p: Player, e: Enemy) -> void:
	_reach_t -= get_physics_process_delta_time()
	if _reach_t > 0.0:
		return
	_reach_t = 1.0
	var path := lvl.get_nav_path(p.global_position, e.global_position)
	var end: Vector2 = path[path.size() - 2] if path.size() >= 2 else p.global_position
	if end.distance_to(e.global_position) > 40.0 and p.global_position.distance_to(e.global_position) > 40.0:
		_unreachable[e.get_instance_id()] = true
		_log("UNREACHABLE %s at cell %s (%s) - path ends at cell %s" % [String(e.data.id), str(Vector2i(e.global_position / 16.0)), lvl.zone_at(e.global_position), str(Vector2i(end / 16.0))])
		var left := lvl.remaining_enemies().filter(func(x): return not _unreachable.has(x.get_instance_id()))
		if left.is_empty():
			for x in lvl.remaining_enemies():
				_log("  clearing unreachable %s so the run can continue" % String(x.data.id))
				x.take_damage(DamageInfo.make(DamageInfo.Type.EXPLOSIVE, p, x.global_position, Vector2.RIGHT, &"explosion", &"explosion"))

## Go for the breach once most of the floor is clear (like a player would).
func _breach_after(lvl: Level) -> int:
	return 8

func _los(p: Player, e: Node2D) -> bool:
	var space := p.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(p.global_position, e.global_position, Layers.WORLD | Layers.DOOR, [p.get_rid()])
	return space.intersect_ray(q).is_empty()

func _nearest_gun(p: Player) -> WeaponPickup:
	var best: WeaponPickup = null
	var bd := INF
	for pk in get_tree().get_nodes_in_group("pickups"):
		if pk is WeaponPickup and pk.weapon and pk.weapon.data.is_firearm() and pk.weapon.loaded() + pk.weapon.reserve > 0:
			var d := (pk as Node2D).global_position.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = pk
	return best

func _nearest_threat(lvl: Level, p: Player) -> String:
	var best := ""
	var bd := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive():
			var d := (e as Node2D).global_position.distance_to(p.global_position)
			if d < bd:
				bd = d
				best = "%s %s at %d px (%s)" % [String(e.data.id), e.state_name(), int(d), "aware" if e.is_aware() else "unaware"]
	return best

func _checkpoint_name(lvl: Level) -> String:
	var cps: Array = lvl.data.get("checkpoints", [])
	var last := "START"
	for i in cps.size():
		if lvl._checkpoints_hit.has(str(i)):
			last = str(cps[i].get("name", i))
	return last

func _write_summary() -> void:
	_log("---- summary ----")
	var keys := _deaths.keys()
	keys.sort_custom(func(a, b): return int(_deaths[a]) > int(_deaths[b]))
	for k in keys:
		_log("deaths %3d  %s" % [int(_deaths[k]), k])
