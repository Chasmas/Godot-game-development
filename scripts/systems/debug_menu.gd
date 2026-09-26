extends CanvasLayer
## Developer menu (F1). Only active in debug builds / the editor.
## Hotkeys while open: T teleport to cursor, K kill all, N spawn enemy at cursor.

var enabled := false
var panel: PanelContainer
var box: VBoxContainer
var info: Label
var _weapon_i := 0
var ai_debug := false
var god := false

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = OS.is_debug_build()
	if not enabled:
		return
	panel = PanelContainer.new()
	panel.theme = UIStyle.theme()
	panel.position = Vector2(8, 120)
	panel.visible = false
	add_child(panel)
	box = VBoxContainer.new()
	panel.add_child(box)
	box.add_child(UIStyle.label("DEBUG  (F1)", 14, UIStyle.GOLD, true))
	info = UIStyle.label("", 11, UIStyle.DIM)
	box.add_child(info)
	_b("God mode", func():
		god = not god
		var p := _player()
		if p:
			p.god_mode = god)
	_b("Spawn next weapon", _spawn_weapon)
	_b("Spawn enemy at cursor [N]", _spawn_enemy)
	_b("Teleport to cursor [T]", _teleport)
	_b("Kill all enemies [K]", _kill_all)
	_b("Refill ability", func():
		var p := _player()
		if p:
			p.ability.charge = 1.0
			p.ability._emit())
	_b("Toggle AI inspector", func():
		ai_debug = not ai_debug
		for e in get_tree().get_nodes_in_group("enemies"):
			e.debug_draw = ai_debug)
	_b("Toggle FPS", func(): SaveManager.set_setting("show_fps", not SaveManager.get_setting("show_fps", false)))
	_b("Toggle collision shapes (reload)", func():
		get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
		get_tree().reload_current_scene())
	_b("Restart level", func(): Game.restart_level())
	_b("Unlock everything", func():
		for c in Game.characters.keys():
			if not String(c) in SaveManager.data.unlocked_characters:
				SaveManager.data.unlocked_characters.append(String(c))
		SaveManager.data.missions["m01_checkout"] = SaveManager.data.missions.get("m01_checkout", {"completed": true, "best_score": 0, "best_rank": "", "best_time": 0.0})
		SaveManager.save_game())
	_b("Jump to mission 1", func(): Game.replay_mission("m01_checkout"))
	_b("Jump to mission 2 (Dog Days)", func(): Game.replay_mission("m02_dog_days"))
	_b("Give all upgrades", func():
		var p := _player()
		if p:
			for id in Upgrades.all_ids():
				p.add_upgrade(id, true))
	_b("Kill the lights here", func():
		var p := _player()
		var lvl := get_tree().get_first_node_in_group("level")
		if p and lvl:
			lvl.set_zone_lights(lvl.zone_at(p.global_position), false, "switch"))

func _b(t: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	box.add_child(b)

func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func _input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).keycode:
			KEY_F1:
				panel.visible = not panel.visible
				if panel.visible:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_T:
				if panel.visible: _teleport()
			KEY_K:
				if panel.visible: _kill_all()
			KEY_N:
				if panel.visible: _spawn_enemy()

func _process(_d: float) -> void:
	if not enabled or not panel.visible:
		return
	var p := _player()
	var n := get_tree().get_nodes_in_group("enemies").size()
	info.text = "FPS %d  enemies %d  bullets %d\n%s" % [Engine.get_frames_per_second(), n,
		(get_tree().get_first_node_in_group("bullets") as BulletSystem).bullets.size() if get_tree().get_first_node_in_group("bullets") else 0,
		("pos %s" % str(p.global_position.round())) if p else "no player"]

func _world_mouse() -> Vector2:
	var p := _player()
	return p.get_global_mouse_position() if p else Vector2.ZERO

func _teleport() -> void:
	var p := _player()
	if p:
		p.global_position = _world_mouse()

func _kill_all() -> void:
	var p := _player()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive() and not e is BossNightManager:
			var info2 := DamageInfo.make(DamageInfo.Type.BALLISTIC, p, e.global_position, Vector2.RIGHT, &"pistol", &"gun")
			e.take_damage(info2)

func _spawn_weapon() -> void:
	var p := _player()
	if p == null:
		return
	var all := DB.all_weapons()
	if all.is_empty():
		return
	var w: WeaponData = all[_weapon_i % all.size()]
	_weapon_i += 1
	WeaponPickup.spawn(p.level.pickup_root() if p.level else p.get_parent(), WeaponInstance.create(w), p.global_position + p.aim_dir * 14.0)

func _spawn_enemy() -> void:
	var lvl := get_tree().get_first_node_in_group("level")
	if lvl == null:
		return
	var e := Enemy.new()
	e.enemy_id = "debug_%d" % Time.get_ticks_msec()
	e.required = false
	e.position = _world_mouse()
	lvl.actors_root.add_child(e)
	e.setup(DB.enemy([&"guard", &"gunner", &"hunter", &"heavy", &"riot", &"scout"][randi() % 6]), lvl, Vector2.DOWN)
	e.debug_draw = ai_debug
