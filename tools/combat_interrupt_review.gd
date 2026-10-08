extends Node2D
var failures := 0
class DamageProbe extends Node2D:
	var hits := 0
	var hit_radius := 6.0
	func take_damage(_info: DamageInfo) -> String:
		hits += 1
		return "pass"
func check(ok: bool, text: String) -> void:
	print("PASS " if ok else "FAIL ", text)
	if not ok: failures += 1
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var player := Player.new()
	add_child(player)
	player.setup(CharacterData.new())
	player.set_physics_process(false)
	player.visual.set_process(false)
	player.ability.set_process(false)
	player.input_enabled = false
	player.position = Vector2(100,100)
	player.aim_dir = Vector2.RIGHT
	player.slots[0] = WeaponInstance.create(DB.weapon(&"knife"))
	player._refresh_weapon()
	var target := DamageProbe.new()
	add_child(target)
	target.add_to_group("damageable")
	target.position = player.position + Vector2.RIGHT * 14.0
	for frame in 2: await get_tree().physics_frame
	player._melee_attack(false)
	check(player._pending_melee > 0.0, "knife starts with pending windup contact")
	player._execute_or_kick()
	player._tick_timers(0.3)
	check(target.hits == 0, "kick cancels the unlanded knife contact")
	check(player.visual._swing_t < 0.0, "kick clears superseded knife animation")
	player.visual._process_cast(0.0)
	check(player.visual.cast_sprite.clip == "kick", "kick owns the current body pose")
	player._melee_cd = 0.0
	player._melee_attack(false)
	player.visual._process_cast(0.0)
	check(player.visual._kick_leg_t <= 0.0 and player.visual.cast_sprite.clip == "stab", "new knife strike replaces the kick pose")
	player._cancel_melee()
	player._kick_cd = 0.0
	player._execute_or_kick()
	player._dash_cd = 0.0
	player.stamina = Player.STAMINA_MAX
	player._start_dash()
	player.visual._process_cast(player.visual._roll_dur + 0.01)
	player.visual._process_cast(0.0)
	check(player.visual._kick_leg_t <= 0.0 and player.visual.cast_sprite.clip != "kick", "old kick does not resume after the roll")
	player.visual.kick_leg()
	player.visual.punch()
	player.visual._process_cast(0.0)
	check(player.visual.cast_sprite.clip in ["punch", "punch_left"] and player.visual._kick_leg_t <= 0.0, "punch replaces the kick pose")
	player.visual.kick_leg()
	player.visual.cancel_attack()
	check(player.visual._kick_leg_t <= 0.0, "shared cancellation also clears kick timer")
	var fallback := CharacterVisual.new()
	add_child(fallback)
	fallback.setup("guard")
	fallback.set_process(false)
	fallback.cast_sprite.free()
	fallback.cast_sprite = null
	fallback.set_mount(true)
	fallback.ground_punch(false)
	check(fallback._leg.visible and fallback._mount, "fallback ground execution retains its mounted leg pose")
	fallback.set_mount(false)
	fallback.cancel_attack()
	check(not fallback._leg.visible, "ordinary fallback cancellation removes kick overlay")
	fallback.queue_free()
	player.visual.finish_roll()
	player._dash_t = 0.0
	for defense in ["nonlethal", "armor", "guard", "dodge"]:
		player._stagger = 0.0
		player._melee_cd = 0.0
		player._iframes = 0.45 if defense == "dodge" else 0.0
		player.armor_hits = 1 if defense == "armor" else 0
		player.guard_hits = 1 if defense == "guard" else 0
		player._melee_attack(false)
		var serial_before := player.visual.attack_serial
		var hit := DamageInfo.make(DamageInfo.Type.MELEE, target, player.global_position, Vector2.LEFT, &"knife", &"melee")
		hit.lethal = defense != "nonlethal"
		player.take_damage(hit)
		if defense == "dodge":
			check(player._pending_melee > 0.0 and player.visual.attack_serial == serial_before, "invulnerability preserves committed attack")
			player._cancel_melee()
		else:
			check(player._pending_melee < 0.0 and player.visual._swing_t < 0.0 and player.visual.attack_serial > serial_before, defense + " stagger cancels contact, pose and trail")
			var hits_before := target.hits
			player._tick_timers(0.3)
			check(target.hits == hits_before, defense + " stagger cannot deal delayed damage")
	player._iframes = 0.0
	player._heavy_ready = true
	player._hold_t = 1.0
	player._cancel_melee()
	check(not player._heavy_ready and player._hold_t == 0.0, "attack interruption clears charged release")
	player._stagger = 0.3
	player._melee_cd = 0.0
	player._cancel_melee()
	player._melee_attack(false)
	check(player._pending_melee < 0.0, "stagger blocks a new knife strike")
	var held_weapon := player.current()
	player._throw_current()
	check(player.current() == held_weapon, "stagger prevents throwing the held weapon")
	player._punch()
	check(player._pending_melee < 0.0 and player.visual._punch_t < 0.0, "stagger blocks a new punch")
	player._chainsaw_attack(WeaponInstance.create(DB.weapon(&"chainsaw")))
	check(player._pending_melee < 0.0, "stagger blocks powered cutting contact")
	var pistol := WeaponInstance.create(DB.weapon(&"pistol"))
	var ammo_before := pistol.ammo
	player._fire_cd = 0.0
	player._try_shoot(pistol)
	check(pistol.ammo == ammo_before and player._fire_cd == 0.0, "stagger blocks shooting without spending ammo")
	player._kick_cd = 0.0
	player._execute_or_kick()
	check(player.visual._kick_leg_t <= 0.0, "stagger blocks a new kick")
	player._dash_cd = 0.0
	player.stamina = Player.STAMINA_MAX
	player._start_dash()
	check(player.is_dashing(), "roll remains available during stagger")
	player._end_dash()
	player._tick_timers(0.31)
	player._melee_cd = 0.0
	player._melee_attack(false)
	check(player._pending_melee > 0.0, "knife control returns after stagger recovery")
	player._cancel_melee()
	var execution_target := Enemy.new()
	execution_target.idle_action = "watch"
	add_child(execution_target)
	execution_target.setup(DB.enemy(&"guard"), self, Vector2.RIGHT)
	execution_target.set_physics_process(false)
	execution_target.visual.set_process(false)
	execution_target.position = player.position + Vector2.RIGHT * 12.0
	player._begin_execution(execution_target, true)
	execution_target._die(DamageInfo.make(DamageInfo.Type.EXPLOSIVE, target, execution_target.global_position, Vector2.RIGHT, &"grenade", &"explosion"))
	player._process_execution(0.0)
	check(player._exec_target == null and player._locked_t == 0.0, "external target death immediately releases execution control")
	check(player.visual.pose_override == "" and not player.visual._mount, "external target death clears paired pose")
	player.visual.finish_roll()
	player._dash_t = 0.0
	player._melee_cd = 0.0
	player._melee_attack(false)
	var serial := player.visual.attack_serial
	player._die(DamageInfo.make(DamageInfo.Type.MELEE, target, player.global_position, Vector2.RIGHT, &"knife", &"melee"))
	check(player._pending_melee < 0.0 and player.visual._swing_t < 0.0, "death cancels pending contact and attack animation")
	check(player.visual.attack_serial > serial, "death invalidates attached attack effects")
	var rolling_player := Player.new()
	add_child(rolling_player)
	rolling_player.setup(CharacterData.new())
	rolling_player.set_physics_process(false)
	rolling_player.visual.set_process(false)
	rolling_player._start_dash()
	check(rolling_player.visual.is_rolling(), "second actor starts a real controller roll")
	rolling_player._die(DamageInfo.make(DamageInfo.Type.EXPLOSIVE, target, rolling_player.global_position, Vector2.RIGHT, &"grenade", &"explosion"))
	check(not rolling_player.visual.is_rolling() and rolling_player._dash_t <= 0.0, "death stops roll pose and further roll ghosts")
	await get_tree().create_timer(0.22, true, false, true).timeout
	for frame in 2: await get_tree().process_frame
	print("COMBAT INTERRUPT REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
