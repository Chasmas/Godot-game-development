extends Node
class FixtureLevel extends Node:
	var weather: WeatherSystem
class TreeProbe extends Node2D:
	var strikes := 0
	func start_lightning_fire() -> void: strikes += 1
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	for mode in ["missing", "clear", "rain", "dry_storm", "storm"]:
		var level := FixtureLevel.new()
		add_child(level)
		if mode != "missing":
			level.weather = WeatherSystem.new()
			level.weather.thunder = mode in ["dry_storm", "storm"]
			level.weather.rain = 1.0 if mode in ["rain", "storm"] else 0.0
		var decor := Node2D.new()
		level.add_child(decor)
		var tree := TreeProbe.new()
		decor.add_child(tree)
		var director := AmbientEventDirector.new()
		decor.add_child(director)
		director._rng.seed = 1
		for attempt in 100: director._try_tree_strike()
		check(tree.strikes == (1 if mode == "storm" else 0), "tree strike obeys weather and remains one-off: " + mode)
		if mode == "storm":
			var bolt := tree.get_child(0) as Node2D
			check(bolt.to_global(Vector2(7,0)).is_equal_approx(tree.global_position), "lightning terminal point hits the crown centre")
			bolt.set_process(false)
			check(bolt._points[-1].is_equal_approx(Vector2(7,0)), "generated discharge keeps its authored impact point")
			bolt._age = 0.06
			bolt._update_flash()
			var gap: float = bolt._light.energy
			bolt._age = 0.085
			bolt._update_flash()
			check(bolt._light.energy > gap * 5.0, "return stroke brightens after the dark gap")
			bolt._age = 0.39
			bolt._update_flash()
			check(bolt._light.energy < 0.001, "discharge light fades before cleanup")
			bolt._process(0.02)
			check(bolt.is_queued_for_deletion(), "discharge and attached light are released")
		if mode == "clear":
			level.weather.thunder = true
			level.weather.rain = 1.0
			for attempt in 100: director._try_tree_strike()
			check(tree.strikes == 1, "clear weather does not consume the later storm surprise")
		if level.weather: level.weather.free()
		level.queue_free()
		await get_tree().process_frame
	for frame in 2: await get_tree().process_frame
	print("TREE STRIKE WEATHER REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
