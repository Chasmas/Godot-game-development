extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func _ready() -> void:
	var player := Player.new()
	add_child(player)
	player.setup(CharacterData.new())
	player.set_physics_process(false)
	var ability := player.ability
	ability.set_process(false)
	ability.charge = 1.0
	player.input_enabled = false
	check(not ability.can_activate(), "No activation during dialogue/input lock")
	player.input_enabled = true
	player._locked_t = 0.5
	check(not ability.can_activate(), "No activation during execution")
	player._locked_t = 0.0
	player.alive = false
	check(not ability.can_activate(), "No activation after death")
	player.alive = true
	check(ability.activate(), "Full charge activates Spotlight")
	check(is_equal_approx(Game.get_slowmo(), 0.3), "World slows to thirty percent")
	ability._process(0.3)
	check(is_equal_approx(ability.time_left, 5.0), "One real second drains one second at slow motion")
	ability._on_kill_in_light(null, {})
	check(is_equal_approx(ability.time_left, 5.5), "Kill rewards half a real second")
	ability._process(3.0)
	check(not ability.active and ability.time_left == 0.0 and Game.get_slowmo() == 1.0, "Expiry restores normal time and clamps HUD meter")
	check(not Events.enemy_killed.is_connected(ability._on_kill_in_light), "Expiry disconnects kill callback")
	ability.charge = 1.0
	ability.activate()
	ability.force_end()
	check(Game.get_slowmo() == 1.0 and not ability.active, "Forced end restores normal time")
	print("SPOTLIGHT REVIEW: ", failures, " failures")
	for frame in 2: await get_tree().process_frame
	Game.request_quit(1 if failures else 0)
