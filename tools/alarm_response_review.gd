extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func _ready() -> void:
	var camera := SecurityCamera.new()
	add_child(camera)
	camera.set_physics_process(false)
	var player := Player.new()
	add_child(player)
	player.setup(CharacterData.new())
	player.position = Vector2(900,900)
	player.set_physics_process(false)
	var guard := Enemy.new()
	guard.idle_action = "watch"
	add_child(guard)
	guard.setup(DB.enemy(&"guard"), self, Vector2.RIGHT)
	guard.set_physics_process(false)
	var reported := Vector2(70,0)
	guard._on_alarm(reported)
	check(guard._goal.distance_to(reported) <= Tuning.get_t().position_error_max + 1.0, "Alarm investigates reported position, not current player position")
	guard._set_state(Enemy.State.IDLE)
	guard.alert_level = 0
	check(camera._alarm_responders(reported).has(guard), "Nearby available guard can respond")
	guard.position = Vector2(800,0)
	check(not camera._alarm_responders(reported).has(guard), "Distant guard is not summoned")
	guard.position = Vector2.ZERO
	guard._held = true
	check(not camera._alarm_responders(reported).has(guard), "Held guard cannot respond")
	guard._held = false
	var navigation := Level.new()
	navigation.nav = AStarGrid2D.new()
	navigation.nav.region = Rect2i(0,0,8,5)
	navigation.nav.cell_size = Vector2(16,16)
	navigation.nav.offset = Vector2(8,8)
	navigation.nav.update()
	for y in 5: navigation.nav.set_point_solid(Vector2i(2,y), true)
	guard.level = navigation
	check(not camera._alarm_responders(reported).has(guard), "Isolated guard is not summoned through walls")
	navigation.nav.set_point_solid(Vector2i(2,0), false)
	check(camera._alarm_responders(reported).has(guard), "Opening passage permits security response")
	guard._set_state(Enemy.State.IDLE)
	guard.alert_level = 0
	camera.base_angle = 0.0
	camera._poly = PackedVector2Array([Vector2.ZERO, Vector2.ONE, Vector2(4,0)])
	camera._meter = 0.7
	camera.take_damage(DamageInfo.new())
	check(guard.state == Enemy.State.INVESTIGATE, "Broken camera summons an available guard")
	check(guard._last_known.distance_to(Vector2(20,0)) < 1.0 and guard._goal.distance_to(Vector2(20,0)) <= 12.1, "Break response investigates floor in front of mount")
	check(camera._poly.is_empty() and camera._meter == 0.0, "Destroying camera immediately clears cone and detection")
	guard._set_state(Enemy.State.IDLE)
	camera.take_damage(DamageInfo.new())
	check(guard.state == Enemy.State.IDLE, "Repeated damage does not summon guards again")
	navigation.free()
	guard.level = null
	print("ALARM RESPONSE REVIEW: ", failures, " failures")
	Audio.shutdown()
	get_tree().quit(1 if failures else 0)
