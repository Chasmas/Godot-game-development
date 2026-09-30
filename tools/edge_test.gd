extends Node
## Edge-case tests for AI, hearing, doors and the dodge (runs with autoloads):
##   godot --headless --path . res://tools/edge_test.tscn
## Each case builds its own situation in mission 1 and checks the outcome,
## so a regression names exactly what broke. Exit code 1 on any failure.

var failures: Array[String] = []

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
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
			"double_death", "shout_is_local", "difficulty_scales", "enemies_miss", "dual_wield", "language_switch_mid_dialogue",
			"long_text_fits", "bark_stays_on_screen", "language_persists", "hud_in_portuguese",
			"alarm_caps_responders", "camera_blind_spot", "m02_all_killable_gun", "m02_all_killable_melee", "m02_all_killable_fists", "aim_forgiveness", "checkpoint_respawn", "snooze_chair_still"]:
		if only != "" and case_name != only:
			continue
		_mission = "m02_dog_days" if case_name.begins_with("m02") else "m01_checkout"
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

var _auto_dismiss := false
func frames(n: int) -> void:
	for i in n:
		# teleporting around can walk into a scene trigger (Buck, a tape):
		# the scene would pause the game, so close it and carry on
		if _auto_dismiss and Dialogue.active:
			Dialogue._end()
		if _auto_dismiss and get_tree().paused and not Dialogue.active and _p() and _p().alive:
			get_tree().paused = false
		await get_tree().physics_frame

var _mission := "m01_checkout"
func _load() -> void:
	Game.checkpoint_state = {}
	Game.start_mission(_mission)
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
## Stand somewhere open with a clear line to `e`, `dist` px away.
func _clear_spot(e: Node2D, dist: float) -> Vector2:
	var p := _p()
	var space := p.get_world_2d().direct_space_state
	for i in 32:
		var a := TAU * i / 32.0
		var at := e.global_position + Vector2.from_angle(a) * dist
		var c := Vector2i(int(at.x / 16), int(at.y / 16))
		var lvl := _lvl()
		if not lvl.nav.is_in_boundsv(c) or lvl.nav.is_point_solid(c):
			continue
		var q := PhysicsRayQueryParameters2D.create(at, e.global_position, Layers.WORLD | Layers.PROP | Layers.DOOR | Layers.LOW)
		q.exclude = [e.get_rid()]
		if space.intersect_ray(q).is_empty():
			return at
	return e.global_position + Vector2(dist, 0)

func _kill_all(melee: bool, fists := false) -> void:
	_auto_dismiss = true
	var p := _p()
	p.god_mode = true
	var all := _enemies()
	check(all.size() >= 15, "m02 has its enemies (%d)" % all.size())
	var survivors := []
	for e in all:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var tag := "%s %s (%s)" % [e.enemy_id, e.data.id, e.state_name()]
		for attempt in 12:
			if not is_instance_valid(e) or not e.is_alive():
				break
			p.global_position = _clear_spot(e, 14.0 if melee else 56.0)
			p.velocity = Vector2.ZERO
			p.aim_dir = (e.global_position - p.global_position).normalized()
			await frames(1)
			if fists:
				# no weapon, no execute button: just keep swinging
				p.slots[p.slot] = null
				p._refresh_weapon()
				for s in 4:
					if not is_instance_valid(e):
						break
					p.global_position = _clear_spot(e, 12.0)
					p.aim_dir = (e.global_position - p.global_position).normalized()
					p._melee_cd = 0.0
					p._punch()
					await frames(12)
			elif melee:
				p.slots[p.slot] = WeaponInstance.create(DB.weapon(&"machete"))
				p._refresh_weapon()
				p._melee_cd = 0.0
				p.aim_dir = (e.global_position - p.global_position).normalized()
				p._melee_attack(attempt % 2 == 1)
				await frames(20)
				if is_instance_valid(e) and e.is_alive() and e.state == Enemy.State.DOWNED:
					p.global_position = e.global_position + Vector2(10, 0)
					await frames(1)
					p._execute_or_kick()
					await frames(200)
			else:
				var w := WeaponInstance.create(DB.weapon(&"pistol"))
				p.slots[p.slot] = w
				p._refresh_weapon()
				for s in 3:
					p.aim_dir = (e.global_position - p.global_position).normalized() if is_instance_valid(e) else p.aim_dir
					p._fire_cd = 0.0
					p._bloom = 0.0
					w.ammo = 10
					p._try_shoot(w)
					await frames(6)
		if is_instance_valid(e) and e.is_alive():
			survivors.append(tag)
			print("    survived: ", tag, " at ", e.global_position, " layer ", e.collision_layer, " hp-armor ", e.armor_left)
	_auto_dismiss = false
	check(survivors.is_empty(), ("every m02 enemy dies to %s" % ("fists" if fists else ("melee" if melee else "bullets"))) + ("" if survivors.is_empty() else " - survivors: " + ", ".join(survivors)))

## A dozing guard and his chair stay put: no look-around, no drift.
func snooze_chair_still() -> void:
	var e: Enemy = null
	for o in _enemies():
		if not o is Dog and o.idle_activity:
			e = o
			break
	e.idle_activity.queue_free()
	e.idle_activity = IdleActivity.new()
	e.visual.rig.add_child(e.idle_activity)
	e.idle_activity.setup(e.visual, IdleActivity.Kind.SNOOZE, "test")
	await frames(4)
	var chair: Node2D = e.idle_activity._chair
	check(chair != null and chair.get_parent() == e, "the chair sits on the body, not the aiming rig")
	var p0 := chair.global_position
	var r0 := chair.global_rotation
	var f0 := e.facing
	var moved := 0.0
	for i in 16:
		await frames(int(Engine.physics_ticks_per_second * 0.5))
		if not e.is_snoozing():
			break
		moved = maxf(moved, chair.global_position.distance_to(p0) + absf(angle_difference(chair.global_rotation, r0)) * 10.0)
	check(e.is_snoozing(), "still asleep after 8 s")
	check(moved < 0.5 and e.facing.dot(f0) > 0.999, "chair and sleeper stay still (moved %.2f)" % moved)

## Die after a checkpoint: enemies are back at their posts, facing the way
## they were placed, and nobody opens fire the moment you reappear.
func checkpoint_respawn() -> void:
	var lvl := _lvl()
	var p := _p()
	var e: Enemy = null
	for o in _enemies():
		if not o is Dog and o.patrol_points.is_empty() and not o.is_snoozing() and not o is Sniper:
			e = o
			break
	var home := e.global_position
	var face := e.facing
	var eid := e.enemy_id
	# respawn point: right in front of the guard, in plain view
	var spawn := home + face * 40.0
	lvl.player.global_position = spawn
	lvl._save_checkpoint("TEST", spawn)
	# the world moves on: the guard wanders off and turns round
	e.global_position = home + Vector2(60, 30)
	e.facing = -face
	e._enter_combat()
	await frames(10)
	Game.restart_level()
	await frames(8)
	var lvl2 := _lvl()
	var e2: Enemy = null
	for o in get_tree().get_nodes_in_group("enemies"):
		if o.enemy_id == eid:
			e2 = o
	check(e2 != null and e2.global_position.distance_to(home) < 2.0, "guard back at his post after respawn")
	check(e2 != null and e2.facing.dot(face) > 0.99, "guard faces the way he was placed")
	check(lvl2.player.global_position.distance_to(spawn) < 2.0 and lvl2.player.respawn_grace > 0.0, "player respawns at the checkpoint with a grace period")
	lvl2.player.god_mode = false
	var aware_early := false
	var tps := float(Engine.physics_ticks_per_second)
	for i in 8:
		await frames(int(tps * 0.25))
		for o in get_tree().get_nodes_in_group("enemies"):
			if o.is_alive() and o.is_aware():
				aware_early = true
	check(not aware_early and lvl2.player.alive, "nobody opens fire in the first two seconds")
	lvl2.player.god_mode = true
	await frames(int(tps * 2.0))
	check(e2 != null and is_instance_valid(e2) and (e2.is_aware() or e2.state == Enemy.State.SUSPICIOUS), "the guard does notice after the grace (%s)" % (e2.state_name() if e2 and is_instance_valid(e2) else "?"))
	Game.checkpoint_state = {}

## Crosshair = direction: near misses connect, clear misses don't.
func aim_forgiveness() -> void:
	var p := _p()
	p.god_mode = true
	# an ordinary guard: armour and shields have their own rules
	var e: Enemy = null
	for o in _enemies():
		if not o is Dog and o.data.armor == 0 and o.data.shield_arc_deg == 0.0 and not o.data.immune_to_punch:
			e = o
			break
	for o in _enemies():
		if o != e:
			o.global_position += Vector2(5000, 5000)
	e.set_physics_process(false)
	var cases := [[60.0, 7.0, true], [60.0, 35.0, false], [140.0, 4.0, true], [140.0, 16.0, false]]
	for c in cases:
		var d: float = c[0]
		var off: float = c[1]
		p.global_position = _clear_spot(e, d)
		p.velocity = Vector2.ZERO
		if not p._has_los(p.global_position, e.global_position, e, Layers.WORLD | Layers.PROP | Layers.DOOR):
			# find open ground in a straight line: move the target instead
			e.global_position = _open_cell(p.global_position, 2)
			p.global_position = e.global_position + Vector2(d, 0)
		var to := (e.global_position - p.global_position).normalized()
		var dir := to.rotated(deg_to_rad(off))
		var shot := p._forgiving_shot(dir)
		var hits := absf(angle_difference(shot.angle(), to.angle())) < 0.01
		check(hits == c[2], "shot %.0f deg off at %.0f px %s" % [off, d, "connects" if c[2] else "still misses"])
	# melee: a bat swing 70 deg off the enemy still lands; behind you doesn't
	for c2 in [[70.0, true], [160.0, false]]:
		if not is_instance_valid(e) or not e.is_alive():
			break
		p.global_position = _clear_spot(e, 18.0)
		var to2 := (e.global_position - p.global_position).normalized()
		p.aim_dir = to2.rotated(deg_to_rad(c2[0]))
		p.slots[p.slot] = WeaponInstance.create(DB.weapon(&"bat"))
		p._refresh_weapon()
		p._melee_cd = 0.0
		p._melee_attack(false)
		await frames(20)
		var landed := not is_instance_valid(e) or not e.is_alive() or e.state == Enemy.State.DOWNED
		check(landed == c2[1], "bat swing %.0f deg off %s" % [c2[0], "lands" if c2[1] else "misses"])

func m02_all_killable_gun() -> void:
	await _kill_all(false)

func m02_all_killable_melee() -> void:
	await _kill_all(true)

func m02_all_killable_fists() -> void:
	await _kill_all(true, true)

func alarm_caps_responders() -> void:
	var p := _p()
	p.god_mode = true
	var alarms := get_tree().get_nodes_in_group("alarm")
	check(not alarms.is_empty(), "level has an alarm panel")
	if alarms.is_empty():
		return
	var before := {}
	for e in _enemies():
		before[e] = e.is_aware() or e.state == Enemy.State.INVESTIGATE
	var n_before := _enemies().size()
	alarms[0].trigger(null)
	await frames(10)
	var answered := 0
	for e in _enemies():
		if before.has(e) and not before[e] and (e.is_aware() or e.state == Enemy.State.INVESTIGATE):
			answered += 1
	var spawned := _enemies().size() - n_before
	check(answered + spawned <= 3 and answered + spawned >= 1, "alarm sends at most 3 (answered %d + reinforcements %d)" % [answered, spawned])

func camera_blind_spot() -> void:
	var p := _p()
	p.god_mode = true
	var lvl := _lvl()
	# a spot with open floor 80 px straight down, so the cone has room
	var at := _open_cell(p.global_position, 3)
	var space := p.get_world_2d().direct_space_state
	for i in 200:
		var q := PhysicsRayQueryParameters2D.create(at, at + Vector2(0, 80), Layers.SIGHT_MASK | Layers.LOW | Layers.GLASS)
		if space.intersect_ray(q).is_empty():
			break
		at = _open_cell(p.global_position, 10)
	var cam := SecurityCamera.new()
	cam.base_angle = PI * 0.5
	cam.position = at
	lvl.props_root.add_child(cam)
	await frames(2) # let the deferred room-fitting finish
	# This fixture deliberately uses the verified downward sight line.
	cam.base_angle = PI * 0.5
	cam._aim = cam.base_angle
	p.respawn_grace = 0.0
	for e in _enemies():
		e.global_position += Vector2(4000, 4000)   # nobody else in the way
	p.global_position = at + Vector2(0, 14)       # right under the lens
	p.set_physics_process(false)
	await frames(60)
	check(cam._meter <= 0.0, "hugging the wall under the camera is not seen (meter %.2f)" % cam._meter)
	p.global_position = at + Vector2(0, 70)       # out in the cone
	# the lens sweeps: give it one full pass to come round to you
	var seen := false
	for i in int(ceil(SecurityCamera.SWEEP_TIME * Engine.physics_ticks_per_second / 15.0)) + 2:
		await frames(15)
		if cam._meter > 0.0 or cam._cool > 0.0:
			seen = true
			break
	check(seen, "standing in the cone is seen within one sweep")
	cam.queue_free()

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

## Enemies are dangerous but not laser-accurate: well under every other shot
## connects at mid range, and less on the move, when rolling or right after
## they spot you.
func enemies_miss() -> void:
	var e: Enemy = _enemies()[0]
	var p := _p()
	p.velocity = Vector2.ZERO
	e._move_vel = Vector2.ZERO
	e._burst_left = e.data.burst
	e._seen_time = 5.0
	var settled := e._hit_chance(p, 150.0)
	check(settled > 0.25 and settled < 0.65, "settled aim at 150px hits some, misses some (%.2f)" % settled)
	check(e._hit_chance(p, 380.0) < settled, "long range misses more (%.2f)" % e._hit_chance(p, 380.0))
	p.velocity = Vector2(160, 0)
	check(e._hit_chance(p, 150.0) < settled, "a running target is harder to hit (%.2f)" % e._hit_chance(p, 150.0))
	p.velocity = Vector2.ZERO
	e._seen_time = 0.0
	check(e._hit_chance(p, 150.0) < settled * 0.5, "the first shots after spotting you rarely land (%.2f)" % e._hit_chance(p, 150.0))
	e._seen_time = 5.0
	SaveManager.settings["difficulty"] = 0
	Difficulty._values_level = -1
	var easy := e._hit_chance(p, 150.0)
	SaveManager.settings["difficulty"] = 2
	Difficulty._values_level = -1
	var hard := e._hit_chance(p, 150.0)
	SaveManager.settings["difficulty"] = 1
	Difficulty._values_level = -1
	check(easy < settled and settled < hard, "difficulty sets accuracy (%.2f / %.2f / %.2f)" % [easy, settled, hard])
	var hits := 0
	for i in 400:
		if randf() <= e._hit_chance(p, 150.0):
			hits += 1
	check(hits > 80 and hits < 280, "about a third to two thirds of 400 settled shots land (%d)" % hits)

func dual_wield() -> void:
	var p := _p()
	var lvl := _lvl()
	p.god_mode = true
	p.slots = [null, null]
	p.slot = 0
	p.give_weapon(&"pistol")
	var pk := WeaponPickup.spawn(lvl.pickup_root(), WeaponInstance.create(DB.weapon(&"pistol")), p.global_position + Vector2(4, 0))
	await frames(3)
	check(p.can_dual_with(pk), "a second pistol offers dual wielding")
	p._pick_up(pk)
	await frames(2)
	var w := p.current()
	check(w.dual and w.ammo2 == 12 and p.visual.dual, "picking it up pairs the guns (both magazines full)")
	var start := w.loaded()
	var used_left := false
	var used_right := false
	for i in 6:
		p._fire_cd = 0.0
		var before_l := w.ammo2
		var before_r := w.ammo
		p._try_shoot(w)
		used_left = used_left or w.ammo2 < before_l
		used_right = used_right or w.ammo < before_r
		await frames(2)
	check(used_left and used_right and w.loaded() == start - 6, "the guns take turns (%d left)" % w.loaded())
	# empty one side: the other keeps firing
	w.ammo = 0
	p._fire_cd = 0.0
	var l0 := w.ammo2
	p._try_shoot(w)
	check(w.ammo2 == l0 - 1, "a dry gun hands off to the other")
	# reload fills both, costs more time than one gun
	w.ammo2 = 0
	w.reserve = 40
	p._start_reload()
	var t_dual := p._reload_t
	await frames(int(t_dual * 120) + 20)
	check(w.ammo == 12 and w.ammo2 == 12, "reload fills both magazines (%d | %d)" % [w.ammo2, w.ammo])
	check(t_dual > DB.weapon(&"pistol").reload_time * 1.2, "and takes longer than one gun")
	# switching during a reload cancels it cleanly
	w.ammo = 0
	p._start_reload()
	await frames(5)
	p._swap()
	await frames(5)
	p._swap()
	await frames(int(t_dual * 120) + 20)
	check(w.ammo == 0 and not p.is_reloading(), "swapping away mid-reload cancels it (no free ammo)")
	# throw: the off-hand gun flies, the other stays
	var n_before := get_tree().get_nodes_in_group("pickups").size()
	p._throw_current()
	await frames(3)
	check(p.current() != null and not p.current().dual and get_tree().get_nodes_in_group("pickups").size() == n_before + 1, "throwing tosses the off-hand gun only")
	# checkpoint round trip keeps the pair
	p.current().dual = true
	p.current().ammo2 = 7
	var st := p.weapon_state()
	p.slots = [null, null]
	p.restore_weapons(st)
	check(p.current().dual and p.current().ammo2 == 7, "checkpoints keep the pair and its ammo")
	# only dual-wieldable guns pair
	p.give_weapon(&"shotgun")
	var pk2 := WeaponPickup.spawn(lvl.pickup_root(), WeaponInstance.create(DB.weapon(&"shotgun")), p.global_position)
	await frames(3)
	check(not p.can_dual_with(pk2), "shotguns don't pair")

func language_switch_mid_dialogue() -> void:
	var before := Loc.current()
	Loc.apply("en", false)
	Dialogue.start("m01_boss_intro", true)
	await frames(10)
	var en_line := Dialogue._full
	Loc.apply("pt_PT", false)
	Dialogue._advance()   # finish the line
	Dialogue._advance()   # next line, now in Portuguese
	await frames(5)
	check(Dialogue._full != "" and Dialogue._full != tr_en(Dialogue._node.get("text", "")), "the next line after switching is Portuguese (%s)" % Dialogue._full.left(40))
	check(Dialogue.name_label.text == TranslationServer.translate(str(Dialogue.speakers.get(str(Dialogue._node.get("speaker", "")), {}).get("name", ""))), "speaker name follows the language")
	while Dialogue.active:
		if not Dialogue._choices.is_empty():
			Dialogue._pick(0)
		else:
			Dialogue._advance()
		await frames(2)
	Loc.apply(before, false)
	check(en_line != "", "dialogue ran in English before the switch")

func tr_en(s: Variant) -> String:
	return str(s)

func long_text_fits() -> void:
	var before := Loc.current()
	Loc.apply("pt_PT", false)
	SaveManager.settings["subtitle_size"] = 2
	# the longest line in the game, in Portuguese, at the largest size
	var longest := ""
	for f in DirAccess.get_files_at("res://data/dialogue"):
		if not f.ends_with(".json") or f == "speakers.json":
			continue
		var d: Dictionary = Dialogue.load_dialogue(f.trim_suffix(".json"))
		for n in (d.get("nodes", {}) as Dictionary).values():
			var t := tr(str(n.get("text", "")))
			if t.length() > longest.length():
				longest = t
	for lf in ["res://levels/m01_sunset_palms.json", "res://levels/m02_yermo_salvage.json"]:
		var ld: Variant = JSON.parse_string(FileAccess.get_file_as_string(lf))
		for c in (ld.get("collectibles", {}) as Dictionary).values():
			var t2 := tr(str(c.get("text", "")))
			if t2.length() > longest.length():
				longest = t2
	Dialogue._data = {"start": "a", "nodes": {"a": {"speaker": "cass", "text": longest}}}
	Dialogue._id = "long"
	Dialogue._pause_game = true
	Dialogue.active = true
	Dialogue.root.visible = true
	Dialogue._apply_reading_settings()
	Dialogue._goto("a")
	await frames(10)
	var box := Dialogue.box.get_global_rect()
	var vp := Dialogue.root.get_viewport_rect()
	var text_h := Dialogue.text_label.get_content_height()
	check(vp.encloses(box), "dialogue box stays on screen with the longest Portuguese line (%d chars)" % longest.length())
	check(Dialogue.text_label.get_global_rect().end.y <= box.end.y + 1.0 and text_h > 0, "and the text fits inside the box")
	Dialogue._end()
	get_tree().paused = false
	SaveManager.settings["subtitle_size"] = 1
	Loc.apply(before, false)

func bark_stays_on_screen() -> void:
	var p := _p()
	var lvl := _lvl()
	var npc := NPC.new()
	npc.npc_id = "edge_npc"
	lvl.actors_root.add_child(npc)
	var vr := p.get_viewport().get_canvas_transform().affine_inverse() * p.get_viewport_rect()
	# right at the top-left corner of the view, then off screen entirely
	var bl := BarkLayer.find(get_tree())
	var ok_all := true
	for pos in [vr.position + Vector2(4, 4), vr.end - Vector2(4, 4), vr.position - Vector2(200, 200)]:
		npc.global_position = pos
		Loc.apply("pt_PT", false)
		bl.say(npc, "The manager keeps a room nobody rents. East side. Walls are thin.", 2.0)
		await frames(4)
		var screen := p.get_viewport_rect()
		for b in bl._barks:
			if b.speaker == npc and not screen.encloses(b.rect):
				ok_all = false
	check(ok_all, "speech bubbles stay fully on screen at the corners and for off-screen speakers")
	# tiny room: the bubble is screen space, so walls can't cover it
	check(bl.layer > 10, "bubbles render above the world (layer %d)" % bl.layer)
	Loc.apply("en", false)
	npc.queue_free()

func language_persists() -> void:
	var before := Loc.current()
	Loc.apply("pt_PT")
	var f := FileAccess.get_file_as_string(SaveManager.settings_path)
	var parsed: Variant = JSON.parse_string(f)
	check(parsed is Dictionary and str(parsed.get("language", "")) == "pt_PT", "choosing Português is written to settings.json")
	check(TranslationServer.translate("OPTIONS") == "OPÇÕES", "and the game is in Portuguese (%s)" % TranslationServer.translate("OPTIONS"))
	check(Loc.count("pt_PT") > 500, "translation table loaded (%d entries)" % Loc.count("pt_PT"))
	Loc.apply(before)

func hud_in_portuguese() -> void:
	Loc.apply("pt_PT", false)
	var lvl := _lvl()
	var p := _p()
	lvl._update_objective()
	p.give_weapon(&"pistol")
	await frames(3)
	var h := lvl.hud
	check(h.score_label.text.ends_with("PTS"), "score label ok (%s)" % h.score_label.text)
	check(h.weapon_label.text == "9MM DE SERVIÇO", "weapon name translated (%s)" % h.weapon_label.text)
	check(h.objective_label.text.begins_with("ENTRA") or h.objective_label.text.begins_with("LIMPA"), "objective translated (%s)" % h.objective_label.text)
	Loc.apply("en", false)
