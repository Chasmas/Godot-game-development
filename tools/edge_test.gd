extends Node
## Edge-case tests for AI, hearing, doors and the dodge (runs with autoloads):
##   godot --headless --path . res://tools/edge_test.tscn
## Each case builds its own situation in mission 1 and checks the outcome,
## so a regression names exactly what broke. Exit code 1 on any failure.

var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var ph := Node.new()
	ph.name = "Placeholder"
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	Game.campaign_mode = false
	InputSetup.using_gamepad = true
	seed(4242)
	var only := OS.get_environment("EDGE_ONLY")
	for case_name in ["gunshot_is_local", "walls_muffle", "kill_mid_investigation", "rapid_fire",
			"spawn_while_shooting", "door_kick_hits_enemy", "doorway_traffic", "dodge_into_wall",
			"double_death", "shout_is_local", "difficulty_scales"]:
		if only != "" and case_name != only:
			continue
		await _load()
		print("-- ", case_name)
		await call(case_name)
	print("=== EDGE TEST DONE: %d failures ===" % failures.size())
	for f in failures:
		print("  FAIL: ", f)
	get_tree().quit(1 if not failures.is_empty() else 0)

func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		failures.append(what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _load() -> void:
	Game.checkpoint_state = {}
	Game.start_mission("m01_checkout")
	await frames(60)
	var p := _p()
	if p:
		p.god_mode = true

func _lvl() -> Level:
	return get_tree().get_first_node_in_group("level") as Level

func _p() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func _enemies() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.is_alive() and not e is BossNightManager:
			out.append(e)
	return out

func _open_cell(near: Vector2, r_cells: int) -> Vector2:
	var lvl := _lvl()
	for i in 400:
		var c := Vector2i(int(near.x / 16) + randi_range(-r_cells, r_cells), int(near.y / 16) + randi_range(-r_cells, r_cells))
		if lvl.nav.is_in_boundsv(c) and not lvl.nav.is_point_solid(c):
			return Vector2(c.x * 16 + 8, c.y * 16 + 8)
	return near

func _spawn(kind: StringName, pos: Vector2) -> Enemy:
	var lvl := _lvl()
	var e := Enemy.new()
	e.enemy_id = "edge_%d" % randi()
	e.position = pos
	lvl.actors_root.add_child(e)
	e.setup(DB.enemy(kind), lvl, Vector2.RIGHT)
	e.died.connect(lvl._on_enemy_died)
	return e

# ------------------------------------------------------------------ cases
func gunshot_is_local() -> void:
	var p := _p()
	var all := _enemies()
	p.give_weapon(&"pistol")
	for i in 3:
		p._fire_cd = 0.0
		p.aim_dir = Vector2.UP
		p._try_shoot(p.current())
		await frames(12)
	await frames(60)
	var reacted := 0
	var exact := 0
	for e in all:
		if not is_instance_valid(e):
			continue
		if e.state != Enemy.State.IDLE and e.state != Enemy.State.PATROL or e.alert_level > 0:
			reacted += 1
			if e._last_known.distance_to(p.global_position) < 0.5 and not e._sees_player:
				exact += 1
	check(reacted < all.size() * 0.5, "three pistol shots outside don't wake the map (%d / %d reacted)" % [reacted, all.size()])
	check(exact == 0, "nobody learns the player's exact position from a sound (%d did)" % exact)

func walls_muffle() -> void:
	var e: Enemy = _enemies()[0]
	var space := e.get_world_2d().direct_space_state
	var blocked := Vector2.INF
	var open := Vector2.INF
	for i in 3000:
		var q := _open_cell(e.global_position, 22)
		var d := q.distance_to(e.global_position)
		if d < 250.0 or d > 330.0:
			continue
		var r := Hearing.Result.new()
		Hearing._count_occluders(e, q, r, 3)
		if r.walls >= 2 and blocked == Vector2.INF:
			blocked = q
		elif r.walls == 0 and r.doors == 0 and open == Vector2.INF:
			open = q
		if blocked != Vector2.INF and open != Vector2.INF:
			break
	if blocked == Vector2.INF or open == Vector2.INF:
		check(false, "found test points for wall muffling")
		return
	var heard_blocked := 0
	var heard_open := 0
	for i in 60:
		if Hearing.perceive(e, blocked, 520.0, &"gunshot", 1.0).heard:
			heard_blocked += 1
		if Hearing.perceive(e, open, 520.0, &"gunshot", 1.0).heard:
			heard_open += 1
	check(heard_blocked == 0, "a pistol shot ~290px away behind two walls is not heard (%d/60)" % heard_blocked)
	check(heard_open > 20, "the same shot in the open usually is (%d/60)" % heard_open)
	var est := Hearing.perceive(e, e.global_position + Vector2(40, 0), 520.0, &"gunshot", 1.0)
	check(est.heard and est.estimate.distance_to(e.global_position + Vector2(40, 0)) >= Tuning.get_t().position_error_min * 0.3, "a heard sound gives an estimate, not the exact spot")

func kill_mid_investigation() -> void:
	var p := _p()
	var es := _enemies().filter(func(x): return x.data.id in [&"guard", &"gunner"])
	var a: Enemy = es[0]
	var b: Enemy = es[1]
	a._begin_investigate(a.global_position + Vector2(60, 0))
	b._begin_search(b.global_position)
	await frames(10)
	check(a.state == Enemy.State.INVESTIGATE, "enemy A investigating (%s)" % a.state_name())
	check(b.state == Enemy.State.SEARCH, "enemy B searching (%s)" % b.state_name())
	for e in [a, b]:
		var info := DamageInfo.make(DamageInfo.Type.MELEE, p, e.global_position, Vector2.RIGHT, &"knife", &"melee")
		info.lethal = true
		e.take_damage(info)
	await frames(30)
	check(not is_instance_valid(a) and not is_instance_valid(b), "both die cleanly mid-behaviour")

func rapid_fire() -> void:
	var p := _p()
	var group: Array = []
	for i in 6:
		group.append(_spawn(&"guard", _open_cell(p.global_position, 5)))
	await frames(2)
	for i in 30:
		Events.noise.emit(p.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), 520.0, &"gunshot", p)
		await frames(1)
	await frames(30)
	var sane := true
	for e in group:
		if is_instance_valid(e) and e.is_alive() and e.state_name() == "":
			sane = false
	check(sane, "30 shots in 30 frames leave every listener in a valid state")

func spawn_while_shooting() -> void:
	var p := _p()
	var lvl := _lvl()
	p.give_weapon(&"smg")
	for i in 40:
		p._fire_cd = 0.0
		p.current().ammo = 30
		p.aim_dir = Vector2.from_angle(i * 0.4)
		p._try_shoot(p.current())
		if i % 8 == 0:
			lvl.spawn_reinforcements(2)
		await frames(1)
	await frames(60)
	check(p.alive, "firing while reinforcements spawn")

func door_kick_hits_enemy() -> void:
	var p := _p()
	var door: Door = null
	for d in get_tree().get_nodes_in_group("door"):
		if d is Door and not d.locked and not d.broken:
			door = d
			break
	if door == null:
		check(false, "found an unlocked door")
		return
	var n := door.leaf_dir().orthogonal()
	var mid := door.global_position + door.leaf_dir() * door.length * 0.6
	p.global_position = mid + n * 11.0
	var e := _spawn(&"guard", mid - n * 7.0)
	e.facing = n
	await frames(2)
	var ok := door.kick(p.global_position, -n)
	await frames(20)
	check(ok, "kick accepted")
	check(is_instance_valid(e) and (e.is_downed() or e.state == Enemy.State.STUNNED or not e.is_alive()), "enemy behind the door is flattened (%s)" % (e.state_name() if is_instance_valid(e) else "freed"))
	var s0 := door.swing
	await frames(240)
	check(absf(door.omega) < 0.05, "door comes to rest (omega %.3f)" % door.omega)
	check(absf(door.swing) <= Door.MAX_SWING + 0.001, "door stays within its hinge limit")
	# kick from behind a wall: find a spot within reach but blocked
	var wall_side := door.global_position - door.leaf_dir() * 14.0
	var from_wall := door.kick(wall_side, door.leaf_dir())
	check(not from_wall or door.hit_point(wall_side).distance_to(wall_side) < 26.0, "no kicks through the wall")

func doorway_traffic() -> void:
	var door: Door = null
	for d in get_tree().get_nodes_in_group("door"):
		if d is Door and not d.locked and not d.broken:
			door = d
			break
	var n := door.leaf_dir().orthogonal()
	var mid := door.global_position + door.leaf_dir() * door.length * 0.5
	var a := _spawn(&"guard", _lvl().nearest_open_point(mid + n * 40.0, mid))
	var b := _spawn(&"guard", _lvl().nearest_open_point(mid + n * 40.0 + door.leaf_dir() * 8.0, mid))
	var goal := _lvl().nearest_open_point(mid - n * 48.0, mid)
	await frames(2)
	for e in [a, b]:
		e._begin_investigate(goal, 0.0)
	var t := 0
	var best_a := INF
	var best_b := INF
	var min_gap := INF
	while t < 900:
		await frames(5)
		t += 5
		best_a = minf(best_a, a.global_position.distance_to(goal))
		best_b = minf(best_b, b.global_position.distance_to(goal))
		if t > 60:
			min_gap = minf(min_gap, a.global_position.distance_to(b.global_position))
		if OS.has_environment("EDGE_DEBUG") and t % 60 == 0:
			print("    t=%d a=%s %s d=%.0f  b=%s %s d=%.0f  goal=%s door=%s swing=%.2f" % [t, a.state_name(), a.global_position, a.global_position.distance_to(goal), b.state_name(), b.global_position, b.global_position.distance_to(goal), goal, door.global_position, door.swing])
		if best_a < 24.0 and best_b < 24.0:
			break
	check(best_a < 30.0 and best_b < 30.0, "two enemies pass the same doorway (closest %.0f / %.0f px, %d ticks)" % [best_a, best_b, t])
	check(min_gap > 5.0, "and never stand inside each other (closest %.1f px)" % min_gap)

func dodge_into_wall() -> void:
	var p := _p()
	var lvl := _lvl()
	# find a floor cell with a wall right of it
	var spot := Vector2.INF
	var space := p.get_world_2d().direct_space_state
	for i in 2000:
		var c := _open_cell(p.global_position, 30)
		var ci := Vector2i(int(c.x / 16), int(c.y / 16))
		if not (lvl.nav.is_in_boundsv(ci + Vector2i(1, 0)) and lvl.nav.is_point_solid(ci + Vector2i(1, 0)) \
				and not lvl.nav.is_point_solid(ci - Vector2i(1, 0)) and not lvl.nav.is_point_solid(ci - Vector2i(2, 0))):
			continue
		# a real wall (the dodge vaults tables, so nav-solid isn't enough)
		var pq := PhysicsPointQueryParameters2D.new()
		pq.position = c + Vector2(16, 0)
		pq.collision_mask = Layers.WORLD
		if not space.intersect_point(pq, 1).is_empty():
			spot = c
			break
	if spot == Vector2.INF:
		check(false, "found a wall to dodge into")
		return
	p.global_position = spot
	p.velocity = Vector2.ZERO
	p._last_move = Vector2.RIGHT
	await frames(2)
	p._start_dash()
	await frames(40)
	check(not p._overlaps(Layers.WORLD), "dodging into a wall never ends inside it")
	check(p.global_position.distance_to(spot) < 20.0, "and doesn't slide off along it (%.1f px)" % p.global_position.distance_to(spot))
	# open-floor dodge distance: about a quarter shorter than before (64.5 px)
	var open_spot := Vector2.INF
	for i in 3000:
		var c := _open_cell(p.global_position, 40)
		var ok := true
		for dx in range(-1, 7):
			var ci := Vector2i(int(c.x / 16) + dx, int(c.y / 16))
			if not lvl.nav.is_in_boundsv(ci) or lvl.nav.is_point_solid(ci):
				ok = false
				break
		if ok:
			open_spot = c
			break
	p.global_position = open_spot
	p.velocity = Vector2.ZERO
	p._dash_cd = 0.0
	await frames(2)
	p._start_dash()
	var start := p.global_position
	while p.is_dashing():
		await frames(1)
	var dist := p.global_position.distance_to(start)
	check(dist > 38.0 and dist < 56.0, "dodge distance %.1f px (was ~64.5)" % dist)

func double_death() -> void:
	var p := _p()
	var e := _spawn(&"guard", _open_cell(p.global_position, 4))
	await frames(2)
	var died_count := [0]
	e.died.connect(func(_a, _b): died_count[0] += 1)
	var info := DamageInfo.make(DamageInfo.Type.BALLISTIC, p, e.global_position, Vector2.RIGHT, &"pistol", &"gun")
	info.lethal = true
	info.from_player = true
	e.take_damage(info)
	e.finish_execution(p, &"knife")   # the same frame: must be a no-op
	await frames(5)
	check(died_count[0] == 1, "an enemy killed twice in one frame dies once (%d)" % died_count[0])

func shout_is_local() -> void:
	var all := _enemies()
	var src: Enemy = all[0]
	var far := 0
	for e in all:
		if e != src and e.global_position.distance_to(src.global_position) > 400.0:
			far += 1
	var p := _p()
	p.global_position = _open_cell(src.global_position, 3)
	src._last_known = p.global_position
	src._enter_combat()
	await frames(30)
	var far_alerted := 0
	for e in all:
		if is_instance_valid(e) and e != src and e.global_position.distance_to(src.global_position) > 400.0 and e.alert_level > 0:
			far_alerted += 1
	check(far > 0 and far_alerted == 0, "one guard shouting doesn't alert guards >400px away (%d of %d)" % [far_alerted, far])

func difficulty_scales() -> void:
	var g := DB.enemy(&"guard")
	SaveManager.settings["difficulty"] = 0
	var easy := Difficulty.scaled_enemy(g)
	SaveManager.settings["difficulty"] = 2
	var hard := Difficulty.scaled_enemy(g)
	SaveManager.settings["difficulty"] = 1
	var normal := Difficulty.scaled_enemy(g)
	check(normal == g, "normal uses the archetype as authored")
	check(easy.reaction_time > g.reaction_time and hard.reaction_time < g.reaction_time, "reaction time scales (%.2f / %.2f / %.2f)" % [easy.reaction_time, g.reaction_time, hard.reaction_time])
	check(easy.aim_error_deg > hard.aim_error_deg, "aim error scales")
	check(g.reaction_time == DB.enemy(&"guard").reaction_time, "the source resource is never modified")
