extends Node
## Enemy stress test (runs with autoloads):
##   godot --headless --path . res://tools/stress_test.tscn
## Loads mission 1, spawns growing crowds of armed enemies around the player,
## puts them all in combat, fires weapons, blows things up and kills them in
## bulk, and reports per-tick cost so scaling problems show up as numbers:
##   n, avg physics ms, worst physics ms, nodes, objects, orphans.
## STRESS_COUNTS="5,10,20" limits the tiers. Exit code 1 on a failed check.

const TIERS := [5, 10, 20, 30, 50, 80]
const SAMPLE_FRAMES := 240   # 2 s of physics at 120 Hz

var failures: Array[String] = []
var _tick_start := 0
var _tick_us := 0

## Brackets every physics tick: runs first and last among physics callbacks.
class Probe extends Node:
	var owner_test: Node
	var first := true
	func _physics_process(_d: float) -> void:
		if first:
			owner_test._tick_start = Time.get_ticks_usec()
		else:
			owner_test._tick_us = Time.get_ticks_usec() - owner_test._tick_start

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var ph := Node.new()
	ph.name = "Placeholder"
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	Game.campaign_mode = false
	InputSetup.using_gamepad = true
	for first in [true, false]:
		var pr := Probe.new()
		pr.owner_test = self
		pr.first = first
		pr.process_mode = Node.PROCESS_MODE_ALWAYS
		pr.process_physics_priority = -100000 if first else 100000
		get_tree().root.add_child.call_deferred(pr)
	var tiers: Array = TIERS
	if OS.has_environment("STRESS_COUNTS"):
		tiers = []
		for s in OS.get_environment("STRESS_COUNTS").split(","):
			tiers.append(int(s))
	print("  n    avg_ms  worst_ms  nodes  objects  orphans")
	for n in tiers:
		await _tier(n)
	print("=== STRESS TEST DONE: %d failures ===" % failures.size())
	for f in failures:
		print("  FAIL: ", f)
	get_tree().quit(1 if not failures.is_empty() else 0)

func check(cond: bool, what: String) -> void:
	if not cond:
		print("  FAIL ", what)
		failures.append(what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _tier(n: int) -> void:
	Game.checkpoint_state = {}
	Game.start_mission("m01_checkout")
	await frames(60)
	var lvl := get_tree().get_first_node_in_group("level") as Level
	var p := get_tree().get_first_node_in_group("player") as Player
	if lvl == null or p == null:
		check(false, "level loads for tier %d" % n)
		return
	p.god_mode = true
	# clear the level's own cast so the tier count is exact
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != lvl.boss:
			e.queue_free()
	lvl.enemies.clear()
	await frames(2)
	var cells := _open_cells(lvl, p.global_position, 14)
	var crowd: Array = []
	for i in n:
		var c: Vector2 = cells[i % cells.size()] + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		var e := Enemy.new()
		e.enemy_id = "stress_%d" % i
		e.position = c
		lvl.actors_root.add_child(e)
		var kind: StringName = [&"guard", &"gunner", &"hunter", &"heavy", &"riot"][i % 5]
		e.setup(DB.enemy(kind), lvl, Vector2.RIGHT)
		e.died.connect(lvl._on_enemy_died)
		lvl.enemies.append(e)
		crowd.append(e)
	# everybody knows where the player is
	for e in crowd:
		e._last_known = p.global_position
		e._enter_combat()
	var worst := 0.0
	var total := 0.0
	for f in SAMPLE_FRAMES:
		# the player keeps shooting, which is the "gunfire in a crowd" case
		if p.current() == null or not p.current().data.is_firearm():
			p.give_weapon(&"smg")
		if f % 6 == 0 and p.current():
			p.current().ammo = p.current().data.magazine
			p._fire_cd = 0.0
			p._reload_t = 0.0
			p.aim_dir = Vector2.from_angle(f * 0.3)
			p._try_shoot(p.current())
		await get_tree().physics_frame
		var ms := _tick_us / 1000.0
		total += ms
		worst = maxf(worst, ms)
		if ms > 8.0 and OS.has_environment("STRESS_SPIKES"):
			print("    spike %.2f ms at sample %d" % [ms, f])
	print("  %-4d %6.2f  %8.2f  %5d  %7d  %7d" % [n, total / SAMPLE_FRAMES, worst,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	# mass death: a blast in the middle of the crowd, then everyone else at once
	ExplosiveTank.blast(p, p.global_position, 90.0, true)
	await frames(2)
	for e in crowd:
		if is_instance_valid(e) and e.is_alive():
			e.finish_execution(p, &"knife")
	await frames(30)
	var alive := 0
	for e in crowd:
		if is_instance_valid(e) and e.is_alive():
			alive += 1
	check(alive == 0, "tier %d: every enemy can be killed (%d left)" % [n, alive])
	check(p.alive, "tier %d: god-mode player survives" % n)

## Floor cells around a point that the nav grid says are walkable.
func _open_cells(lvl: Level, center: Vector2, radius_cells: int) -> Array:
	var out := []
	var c0 := Vector2i(int(center.x / 16.0), int(center.y / 16.0))
	for dy in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			var c := c0 + Vector2i(dx, dy)
			if absi(dx) + absi(dy) < 3:
				continue
			if lvl.nav.is_in_boundsv(c) and not lvl.nav.is_point_solid(c):
				out.append(Vector2(c.x * 16 + 8, c.y * 16 + 8))
	out.shuffle()
	return out
