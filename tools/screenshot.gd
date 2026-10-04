extends Node
## Dev tool: render a screenshot of a game state.
## SHOT_MODE=title|level|cutscene|results SHOT_POS=x,y (tiles) SHOT_OUT=/path.png SHOT_FRAMES=n
## xvfb-run godot --path . res://tools/screenshot.tscn

func _ready() -> void:
	Engine.set_meta("autoplay", true)   # no mask picker over the shots
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var ph := Node.new()
	get_tree().root.add_child(ph)
	get_tree().current_scene = ph
	if OS.get_environment("SHOT_TRAILER") == "1":
		# trailer footage: no HUD, no tips, no calls, no chapter card
		Engine.set_meta("trailer", true)
		SaveManager.set_setting("tips", false, false)
		Game.force_intro_calls = false
	if OS.get_environment("SHOT_LANG") != "":
		Loc.apply(OS.get_environment("SHOT_LANG"), false)
	var mode := OS.get_environment("SHOT_MODE")
	if OS.get_environment("SHOT_COLLECT") == "1":
		for cid in ["tape_roll7", "photo_harcourt", "tape_vance", "tape_pilot", "photo_casting"]:
			if not cid in SaveManager.data.collectibles:
				SaveManager.data.collectibles.append(cid)
	if OS.get_environment("SHOT_ALLMASKS") == "1":
		# every mask on the shelf (in memory only; nothing is saved)
		SaveManager.data["masks"] = Masks.ORDER.map(func(m): return String(m))
		SaveManager.data["missions"]["m01_checkout"] = {"completed": true, "best_score": 1, "best_rank": "A", "best_time": 1.0}
	if OS.get_environment("SHOT_PROGRESS") == "1":
		# a save that has played a bit (in memory only)
		SaveManager.data["missions"]["m01_checkout"] = {"completed": true, "best_score": 48210, "best_rank": "S", "best_time": 412.0}
		SaveManager.data["missions"]["m02_dog_days"] = {"completed": true, "best_score": 36900, "best_rank": "A+", "best_time": 530.0}
		SaveManager.data["sections"] = {"m01_checkout": {"0": 40.0, "1": 131.0, "2": 250.0}}
		SaveManager.data["story"]["chapter"] = 5
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
			if OS.get_environment("SHOT_PANEL") != "":
				get_tree().current_scene.call("_show_" + OS.get_environment("SHOT_PANEL"))
				await _frames(int(OS.get_environment("SHOT_PANEL_F")) if OS.get_environment("SHOT_PANEL_F") != "" else 40)
				if OS.get_environment("SHOT_VCR_TAB") == "posters":
					SaveManager.data["posters"] = ["psychoe_motel", "die_hardly", "beware_of_dogg", "top_gum"]
					for ch in get_tree().current_scene.get_children():
						if ch is VcrScreen:
							ch._tab = "posters"
							ch._psel = 1
					await _frames(20)
				if OS.get_environment("SHOT_CYCLE") != "":
					# browse along the shelf / list, a beat per step
					for k in int(OS.get_environment("SHOT_CYCLE")):
						var ev2 := InputEventAction.new()
						ev2.action = "ui_right" if OS.get_environment("SHOT_PANEL") == "masks" else "ui_down"
						ev2.pressed = true
						Input.parse_input_event(ev2)
						await _frames(2)
						var ev3 := ev2.duplicate()
						ev3.pressed = false
						Input.parse_input_event(ev3)
						await _frames(16)
				if OS.get_environment("SHOT_VCR_PLAY") != "":
					for ch in get_tree().current_scene.get_children():
						if ch is VcrScreen:
							ch._sel = int(OS.get_environment("SHOT_VCR_PLAY"))
							ch._play_selected()
					await _frames(int(OS.get_environment("SHOT_VCR_F")) if OS.get_environment("SHOT_VCR_F") != "" else 200)
		"backdrop":
			# title backdrop for promo/installer art. SHOT_HIDE: comma list of
			# logo, osd, press, version
			Game.goto_title()
			await _frames(20)
			var ts := get_tree().current_scene
			var hide := OS.get_environment("SHOT_HIDE").split(",")
			if "logo" in hide:
				ts.logo_top.visible = false
				ts.logo_bottom.visible = false
			if "osd" in hide:
				ts.osd.visible = false
			if "press" in hide:
				ts.press_label.visible = false
			if "version" in hide:
				for c in ts.get_children():
					if c is Label and str(c.text).contains("v"):
						if c != ts.logo_top and c != ts.logo_bottom and c != ts.osd and c != ts.press_label:
							c.visible = false
			await _frames(n)
		"options":
			Game.goto_title()
			await _frames(20)
			var om := OptionsMenu.new()
			get_tree().current_scene.add_child(om)
			await _frames(10)
			if OS.get_environment("SHOT_TAB") != "":
				om.tabs.current_tab = int(OS.get_environment("SHOT_TAB"))
			await _frames(n)
		"intro":
			Game.change_scene("res://scenes/ui/intro.tscn", false)
			await _frames(n)
		"splash":
			Game.change_scene("res://scenes/ui/splash_screen.tscn", false)
			await _frames(n)
		"hub":
			SaveManager.data.missions["m01_checkout"] = {"completed": true, "best_score": 1, "best_rank": "A", "best_time": 1.0}
			Game.change_scene(Game.HUB_SCENE)
			await _frames(n)
			if OS.get_environment("SHOT_BOARD") == "1":
				get_tree().current_scene._use("BOARD")
				await _frames(20)
		"results":
			Game.current_mission = load("res://data/missions/m01_checkout.tres")
			if OS.get_environment("SHOT_HL") == "1":
				for i in 3:
					var im := Image.create(384, 216, false, Image.FORMAT_RGB8)
					im.fill(Color(0.3 + i * 0.2, 0.1, 0.3))
					Game.highlights.append({"img": im, "combo": 3 + i, "t": 30.0 + i * 20.0, "weapon": "pistol"})
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
			if OS.get_environment("SHOT_CELL") != "" and OS.get_environment("SHOT_WHAT") != "cell":
				Game.attempts = 2    # no car arrival: the shot is staged elsewhere
			Game.start_mission(OS.get_environment("SHOT_MISSION") if OS.get_environment("SHOT_MISSION") != "" else "m02_dog_days")
			await _frames(30)
			while get_tree().get_first_node_in_group("player") == null:
				await _frames(5)
			var lvl2 := get_tree().get_first_node_in_group("level") as Level
			var p3 := get_tree().get_first_node_in_group("player") as Player
			if Engine.has_meta("trailer") and lvl2.hud:
				lvl2.hud.visible = false
			p3.god_mode = true
			lvl2.camera.zoom_bias = float(OS.get_environment("SHOT_ZOOM")) if OS.get_environment("SHOT_ZOOM") != "" else 3.0
			if OS.get_environment("SHOT_STAMP") != "":
				lvl2.hud.show_checkpoint("WAREHOUSE")
				await _frames(75)
			if OS.get_environment("SHOT_UPGRADE") != "":
				p3.add_upgrade(StringName(OS.get_environment("SHOT_UPGRADE")), true)
			if OS.get_environment("SHOT_STAMINA") != "":
				p3.stamina = float(OS.get_environment("SHOT_STAMINA"))
				p3._stamina_rest = 99.0
			var what := OS.get_environment("SHOT_WHAT")
			if what != "cell" and OS.get_environment("SHOT_CELL") != "":
				# stage the shot somewhere else (away from the car arrival)
				var cxy := OS.get_environment("SHOT_CELL").split(",")
				p3.global_position = Vector2(float(cxy[0]) * 16 + 8, float(cxy[1]) * 16 + 8)
				p3.visible = true
				lvl2.camera.target = p3
				lvl2.camera.snap_to_target()
				while Dialogue.active:
					Dialogue._end()
					await _frames(2)
			if OS.get_environment("SHOT_DODGE") != "":
				# a string of dodge rolls through the room, gun out
				p3.set_physics_process(true)
				p3.input_enabled = false
				p3.give_weapon(&"smg")
				await _frames(20)
				var dirs := [Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.LEFT, Vector2(-1, -1).normalized(), Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
				for dv in dirs:
					p3._last_move = dv
					p3.aim_dir = dv.rotated(0.6)
					p3._dash_cd = 0.0
					p3.stamina = 100.0
					p3._start_dash()
					await _frames(22)
					p3.velocity = Vector2.ZERO
					await _frames(8)
			if what == "bone":
				await _frames(30)
				var bn := get_tree().get_first_node_in_group("meat_bone_pickups") as Node2D
				print("bone at ", bn.global_position / 16.0 if bn else Vector2(-1, -1))
				p3.global_position = bn.global_position + Vector2(-700, 0)
				p3.input_enabled = false
				p3.set_physics_process(false)
				lvl2.camera.target = bn
				while Dialogue.active:
					Dialogue._end()
					await _frames(2)
			elif what == "cell":
				# look at a map cell: SHOT_CELL=x,y
				var xy := OS.get_environment("SHOT_CELL").split(",")
				var mk := Node2D.new()
				mk.global_position = Vector2(float(xy[0]) * 16 + 8, float(xy[1]) * 16 + 8)
				lvl2.add_child(mk)
				p3.global_position = mk.global_position + Vector2(-700, 0)
				p3.input_enabled = false
				p3.set_physics_process(false)
				lvl2.camera.target = mk
				await _frames(10)
				while Dialogue.active:
					Dialogue._end()
					await _frames(2)
				if OS.get_environment("SHOT_BREACH") != "" and lvl2.breach:
					# walk up to the doors (LOCKED), take the charges, plant them
					p3.set_physics_process(true)
					p3.global_position = lvl2.breach._plant_it.global_position + Vector2(0, 14)
					await _frames(int(OS.get_environment("SHOT_BREACH_F0")) if OS.get_environment("SHOT_BREACH_F0") != "" else 20)
					if OS.get_environment("SHOT_BREACH") == "plant":
						lvl2.breach._on_take(null, p3)
						lvl2.breach._on_plant(null, p3)
					await _frames(int(OS.get_environment("SHOT_BREACH_F")) if OS.get_environment("SHOT_BREACH_F") != "" else 30)
			elif what == "handler":
				# a dog handler out walking his dog
				var hd: Node2D = null
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Handler:
						hd = e
						break
				p3.global_position = hd.global_position + Vector2(-700, 0)
				p3.input_enabled = false
				p3.set_physics_process(false)
				lvl2.camera.target = hd
				await _frames(10)
				while Dialogue.active:
					Dialogue._end()
					await _frames(2)
			elif what == "boss":
				# the boss waiting in his room, before the fight
				var bs: Node2D = lvl2.boss
				p3.global_position = bs.global_position + Vector2(-500, 0)
				p3.input_enabled = false
				p3.set_physics_process(false)
				lvl2.camera.target = bs
				await _frames(10)
				while Dialogue.active:
					Dialogue._end()
					await _frames(2)
			elif what == "dog":
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
			elif what == "sleepdog":
				var sd: Dog = null
				for e in get_tree().get_nodes_in_group("enemies"):
					if e is Dog and e.sleeping:
						sd = e
						break
				p3.global_position = sd.global_position + Vector2(-400, 0)
				p3.input_enabled = false
				p3.set_physics_process(false)
				lvl2.camera.target = sd
			elif what.begins_with("idle"):
				# idle0 / idle1 / idle2: the Nth calm guard busy with something
				var want := int(what.substr(4)) if what.length() > 4 else 0
				var found := 0
				var tgt2: Enemy = null
				for e in get_tree().get_nodes_in_group("enemies"):
					if e.idle_activity and not e.is_snoozing():
						if found == want:
							tgt2 = e
							break
						found += 1
				print("closeup idle target ", tgt2, " kind ", tgt2.idle_activity.kind if tgt2 else -1)
				p3.global_position = tgt2.global_position + Vector2(-400, 0)
				p3.input_enabled = false
				p3.set_physics_process(false)
				lvl2.camera.target = tgt2
			elif what == "snooze" or what == "handler":
				var tgt: Enemy = null
				for e in get_tree().get_nodes_in_group("enemies"):
					if (what == "snooze" and e.is_snoozing()) or (what == "handler" and e is Handler):
						tgt = e
						break
				if tgt == null:
					# force one: first plain guard dozes off / nothing to show
					for e in get_tree().get_nodes_in_group("enemies"):
						if not e is Dog and e.idle_activity:
							e.idle_activity.queue_free()
							e.idle_activity = IdleActivity.new()
							e.visual.rig.add_child(e.idle_activity)
							e.idle_activity.setup(e.visual, IdleActivity.Kind.SNOOZE, "x")
							tgt = e
							break
				print("closeup target ", tgt, " at ", tgt.global_position)
				p3.global_position = tgt.global_position + Vector2(-400, 0)
				p3.input_enabled = false
				p3.set_physics_process(false)
				lvl2.camera.target = tgt
			elif what == "dual":
				p3.give_weapon(&"pistol")
				p3.current().dual = true
				p3.current().ammo2 = 12
				p3._refresh_weapon()
				p3.aim_dir = Vector2.RIGHT
			elif what == "guards":
				# line up one of each archetype next to the player
				var kinds := [&"guard", &"gunner", &"hunter", &"heavy", &"scout", &"riot"] if OS.get_environment("SHOT_KINDS") == "" else Array(OS.get_environment("SHOT_KINDS").split(","))
				for i in kinds.size():
					var e2 := Enemy.new()
					e2.enemy_id = "shot_%d" % i
					e2.position = p3.global_position + Vector2(-60 + i * 24, -28)
					lvl2.actors_root.add_child(e2)
					e2.setup(DB.enemy(StringName(kinds[i])), lvl2, Vector2.DOWN)
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
			if OS.get_environment("SHOT_NODE") != "":
				while not Dialogue.active:
					await _frames(5)
				await _frames(10)
				Dialogue._goto(OS.get_environment("SHOT_NODE"))
			await _frames(n)
			for ss in get_tree().current_scene.get_children():
				if ss is StoryShot:
					print("SHOT ", ss.shot_id)
					for ch in ss.get_children():
						print("  ", ch, " ", ch.get("texture").resource_path if ch.get("texture") else "", " a=", ch.modulate.a, " vis=", ch.visible)
		_:
			var mods := {}
			if OS.get_environment("SHOT_MODS") != "":
				mods = JSON.parse_string(OS.get_environment("SHOT_MODS"))
			if OS.get_environment("SHOT_WEATHER") != "":
				mods["weather"] = OS.get_environment("SHOT_WEATHER")
			Game.start_mission(OS.get_environment("SHOT_MISSION") if OS.get_environment("SHOT_MISSION") != "" else "m01_checkout", "", mods)
			await _frames(20)
			while get_tree().get_first_node_in_group("player") == null:
				await _frames(5)
			var p := get_tree().get_first_node_in_group("player") as Player
			var pos := OS.get_environment("SHOT_POS")
			if p and pos != "":
				var xy := pos.split(",")
				p.global_position = Vector2(float(xy[0]) * 16 + 8, float(xy[1]) * 16 + 8)
				p.god_mode = OS.get_environment("SHOT_GOD") == "1"
				var cam := get_tree().get_first_node_in_group("level").camera as CameraController
				cam.snap_to_target()
			if OS.get_environment("SHOT_KILL") != "":
				# kill everyone near with a mix of weapons, for gore/corpse shots
				var wpns := [&"pistol", &"shotgun", &"rifle", &"smg"]
				var i := 0
				for e in get_tree().get_nodes_in_group("enemies"):
					if e.is_alive() and (e as Node2D).global_position.distance_to(p.global_position) < 260.0:
						var di := DamageInfo.make(DamageInfo.Type.EXPLOSIVE if i % 5 == 4 else DamageInfo.Type.BALLISTIC, p, (e as Node2D).global_position, ((e as Node2D).global_position - p.global_position).normalized(), wpns[i % 4])
						di.lethal = true
						e.take_damage(di)
						i += 1
				await _frames(int(OS.get_environment("SHOT_KILL_F")) if OS.get_environment("SHOT_KILL_F") != "" else 60)
			if OS.get_environment("SHOT_CP") != "":
				var lvc := get_tree().get_first_node_in_group("level") as Level
				lvc.hud._banner_t = 0.0
				lvc.hud.banner.modulate.a = 0.0
				lvc.hud.show_checkpoint("COURTYARD", OS.get_environment("SHOT_CP") == "rewind")
				await _frames(int(OS.get_environment("SHOT_CP_F")) if OS.get_environment("SHOT_CP_F") != "" else 70)
			if OS.get_environment("SHOT_BREACH") != "":
				var lvb := get_tree().get_first_node_in_group("level") as Level
				lvb.breach._on_take(null, p)
				p.global_position = lvb.breach._plant_it.global_position + Vector2(-60, 40)
				lvb.camera.snap_to_target()
				if OS.get_environment("SHOT_BREACH") == "blow":
					lvb.breach.detonate()
				else:
					lvb.breach._on_plant(null, p)
				await _frames(int(OS.get_environment("SHOT_BREACH_F")) if OS.get_environment("SHOT_BREACH_F") != "" else 6)
			var lvh := get_tree().get_first_node_in_group("level") as Level
			if lvh and lvh.hud:
				lvh.hud._banner_t = 0.0
				lvh.hud._card_t = 0.0
				lvh.hud.banner.modulate.a = 0.0
				lvh.hud.card_sub.modulate.a = 0.0
			if OS.get_environment("SHOT_TUT") != "":
				for tid in OS.get_environment("SHOT_TUT").split(","):
					SaveManager.data.story.flags.erase("tut_" + tid)
					Events.tutorial.emit(tid)
			if OS.get_environment("SHOT_CHARGE") != "" and p:
				p.ability.charge = float(OS.get_environment("SHOT_CHARGE"))
				p.ability._emit()
			if OS.get_environment("SHOT_GUN") != "" and p:
				p.give_weapon(StringName(OS.get_environment("SHOT_GUN")))
			var wx = get_tree().get_first_node_in_group("weather")
			if wx and OS.get_environment("SHOT_STORM") == "1":
				wx.rain = 1.0
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
			if OS.get_environment("SHOT_UPGRADE") != "" and p:
				p.add_upgrade(StringName(OS.get_environment("SHOT_UPGRADE")))
				p.add_upgrade(&"night_vision")
				await _frames(int(OS.get_environment("SHOT_UPGRADE_F")) if OS.get_environment("SHOT_UPGRADE_F") != "" else 30)
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
