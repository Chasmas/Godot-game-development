extends Node
## Dev tool: render a screenshot of a game state.
## SHOT_MODE=title|level|cutscene|results SHOT_POS=x,y (tiles) SHOT_OUT=/path.png SHOT_FRAMES=n
## xvfb-run godot --path . res://tools/screenshot.tscn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var ph := Node.new()
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	if OS.get_environment("SHOT_LANG") != "":
		Loc.apply(OS.get_environment("SHOT_LANG"), false)
	var mode := OS.get_environment("SHOT_MODE")
	var out := OS.get_environment("SHOT_OUT")
	var n := int(OS.get_environment("SHOT_FRAMES")) if OS.get_environment("SHOT_FRAMES") != "" else 90
	match mode:
		"title":
			Game.goto_title()
			await _frames(n)
			var ev := InputEventKey.new()
			ev.pressed = true
			ev.keycode = KEY_ENTER
			if OS.get_environment("SHOT_MENU") == "1":
				Input.parse_input_event(ev)
				await _frames(30)
		"options":
			Game.goto_title()
			await _frames(20)
			var om := OptionsMenu.new()
			get_tree().current_scene.add_child(om)
			await _frames(10)
			if OS.get_environment("SHOT_TAB") != "":
				om.tabs.current_tab = int(OS.get_environment("SHOT_TAB"))
			await _frames(n)
		"splash":
			Game.change_scene("res://scenes/ui/splash_screen.tscn", false)
			await _frames(n)
		"results":
			Game.current_mission = load("res://data/missions/m01_checkout.tres")
			Game.last_result = {"score": 38200, "time": 212.4, "max_combo": 9, "stats": {"kills": 23, "executions": 5, "silent_kills": 4, "attempts": 6}, "variety": 5, "methods": 6, "accuracy": 0.61, "time_bonus": 2900, "flow_bonus": 5400, "variety_bonus": 5000, "accuracy_bonus": 1830, "total": 53330, "rank": "S+", "new_best": true, "place": 1}
			Game.change_scene(Game.RESULTS_SCENE)
			await _frames(n)
		"boss":
			Game.start_mission("m01_checkout")
			await _frames(20)
			var lvl := get_tree().get_first_node_in_group("level") as Level
			var p2 := get_tree().get_first_node_in_group("player") as Player
			p2.god_mode = true
			p2.global_position = Vector2(59 * 16, 35 * 16)
			lvl.camera.snap_to_target()
			await _frames(10)
			while Dialogue.active:
				Dialogue._advance()
				await _frames(2)
			for i in 3:
				lvl.boss.take_damage(DamageInfo.make(DamageInfo.Type.BALLISTIC, p2, lvl.boss.global_position, Vector2.RIGHT, &"pistol"))
			await _frames(n)
		"closeup":
			# SHOT_MISSION, SHOT_ZOOM (camera zoom bias), SHOT_WHAT=dog|guards|dual
			Game.start_mission(OS.get_environment("SHOT_MISSION") if OS.get_environment("SHOT_MISSION") != "" else "m02_dog_days")
			await _frames(30)
			var lvl2 := get_tree().get_first_node_in_group("level") as Level
			var p3 := get_tree().get_first_node_in_group("player") as Player
			p3.god_mode = true
			lvl2.camera.zoom_bias = float(OS.get_environment("SHOT_ZOOM")) if OS.get_environment("SHOT_ZOOM") != "" else 3.0
			var what := OS.get_environment("SHOT_WHAT")
			if what == "dog":
				var dog: Dog = null
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Dog and not e.sleeping:
						dog = e
						break
				if dog == null:
					for e in get_tree().get_nodes_in_group("enemies"):
						if e is Dog:
							dog = e
							break
				dog.sleeping = false
				p3.global_position = dog.global_position + Vector2(26, 6)
				dog._last_known = p3.global_position
				if OS.get_environment("SHOT_ALERT") == "1":
					dog._enter_combat()
				dog.set_physics_process(OS.get_environment("SHOT_ALERT") == "1")
				p3.input_enabled = false
				p3.set_physics_process(false)
				lvl2.camera.target = dog
			elif what == "dual":
				p3.give_weapon(&"pistol")
				p3.current().dual = true
				p3.current().ammo2 = 12
				p3._refresh_weapon()
				p3.aim_dir = Vector2.RIGHT
			elif what == "guards":
				# line up one of each archetype next to the player
				var kinds := [&"guard", &"gunner", &"hunter", &"heavy", &"scout", &"riot"]
				for i in kinds.size():
					var e2 := Enemy.new()
					e2.enemy_id = "shot_%d" % i
					e2.position = p3.global_position + Vector2(-60 + i * 24, -28)
					lvl2.actors_root.add_child(e2)
					e2.setup(DB.enemy(kinds[i]), lvl2, Vector2.DOWN)
					e2.set_physics_process(false)
				for i in 4:
					var e3 := Enemy.new()
					e3.enemy_id = "shot_v_%d" % i
					e3.position = p3.global_position + Vector2(-36 + i * 24, 26)
					lvl2.actors_root.add_child(e3)
					e3.setup(DB.enemy(&"guard"), lvl2, Vector2.UP)
					e3.set_physics_process(false)
			lvl2.camera.snap_to_target()
			print("closeup: player ", p3.global_position, " cam ", lvl2.camera.global_position, " zoom ", lvl2.camera.zoom, " visible ", p3.visual.visible)
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Dog:
					print("  dog ", e.global_position, " sleeping ", e.sleeping, " state ", e.state_name(), " vis ", e.visible)
			lvl2.hud._banner_t = 0.0
			lvl2.hud._card_t = 0.0
			lvl2.hud.banner.modulate.a = 0.0
			lvl2.hud.card_sub.modulate.a = 0.0
			await _frames(n)
		"cutscene":
			Game.current_cutscene = OS.get_environment("SHOT_CUT")
			Game.change_scene(Game.CUTSCENE_SCENE)
			await _frames(n)
		_:
			Game.start_mission(OS.get_environment("SHOT_MISSION") if OS.get_environment("SHOT_MISSION") != "" else "m01_checkout")
			await _frames(20)
			var p := get_tree().get_first_node_in_group("player") as Player
			var pos := OS.get_environment("SHOT_POS")
			if p and pos != "":
				var xy := pos.split(",")
				p.global_position = Vector2(float(xy[0]) * 16 + 8, float(xy[1]) * 16 + 8)
				p.god_mode = OS.get_environment("SHOT_GOD") == "1"
				var cam := get_tree().get_first_node_in_group("level").camera as CameraController
				cam.snap_to_target()
			var lvh := get_tree().get_first_node_in_group("level") as Level
			if lvh and lvh.hud:
				lvh.hud._banner_t = 0.0
				lvh.hud._card_t = 0.0
				lvh.hud.banner.modulate.a = 0.0
				lvh.hud.card_sub.modulate.a = 0.0
			if OS.get_environment("SHOT_GUN") != "" and p:
				p.give_weapon(StringName(OS.get_environment("SHOT_GUN")))
			var wx = get_tree().get_first_node_in_group("weather")
			if wx and OS.get_environment("SHOT_WEATHER") != "":
				wx._target_rain = 1.0
				wx.rain = 1.0
				wx._target_wind = 0.8
				wx.wind = 0.8
				wx.thunder = true
			await _frames(n)
			if OS.get_environment("SHOT_BOLT") == "1" and wx:
				wx._strike()
				await _frames(2)
			var lv := get_tree().get_first_node_in_group("level") as Level
			if OS.get_environment("SHOT_UPG") == "1" and p:
				for id in [&"laser", &"armor", &"night_vision" if OS.get_environment("SHOT_NV") == "1" else &"silencer", &"soft_soles"]:
					p.add_upgrade(id, true)
			if OS.get_environment("SHOT_DARK") != "" and lv:
				lv.set_zone_lights(OS.get_environment("SHOT_DARK"), false, "fuse")
				await _frames(20)
			if OS.get_environment("SHOT_LOCK") == "1" and p:
				var c := p._lock_candidates()
				if not c.is_empty():
					p.set_lock(c[0])
				await _frames(3)
			if OS.get_environment("SHOT_EXEC") != "" and p:
				# grab the nearest enemy and execute it; capture mid-move
				var best: Enemy = null
				var bd := 99999.0
				for e in get_tree().get_nodes_in_group("enemies"):
					if e.is_alive() and not e is BossNightManager and e.global_position.distance_to(p.global_position) < bd:
						bd = e.global_position.distance_to(p.global_position)
						best = e
				if best:
					if OS.get_environment("SHOT_GUN2") != "":
						p.give_weapon(StringName(OS.get_environment("SHOT_GUN2")))
					p.global_position = best.global_position - best.facing * 12.0
					var info := DamageInfo.make(DamageInfo.Type.PUNCH, p, best.global_position, best.facing, &"fists", &"punch")
					info.lethal = false
					if OS.get_environment("SHOT_EXEC") == "down":
						best.take_damage(info)
						await _frames(4)
						p._begin_execution(best, false)
					else:
						p._begin_execution(best, true)
					await _frames(int(OS.get_environment("SHOT_EXEC_F")) if OS.get_environment("SHOT_EXEC_F") != "" else 40)
			if OS.get_environment("SHOT_SLASH") == "1" and p:
				InputSetup.using_gamepad = true
				p.aim_dir = Vector2.RIGHT
				p._melee_attack(false)
				await _frames(1)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	get_tree().quit()

func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
