extends Control
## Title screen + front-end: continue, new game, chapters, arcade/challenges
## with local leaderboards, cast, extras (gallery, stats, credits), options.

var backdrop: TitleBackdrop
var logo_top: Label
var logo_bottom: Label
var press_label: Label
var osd: Label
var menu: VBoxContainer
var panel: PanelContainer
var panel_body: VBoxContainer
var _started := false
var _t := 0.0
var _options: OptionsMenu

func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	backdrop = TitleBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	# logo
	logo_top = Label.new()
	logo_top.text = "HOTSHOT"
	logo_top.add_theme_font_override("font", UIStyle.font_display())
	logo_top.add_theme_font_size_override("font_size", 128)
	logo_top.add_theme_color_override("font_shadow_color", Color(0.05, 0.0, 0.12, 0.9))
	logo_top.add_theme_constant_override("shadow_offset_x", 6)
	logo_top.add_theme_constant_override("shadow_offset_y", 6)
	logo_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.place(logo_top, Control.PRESET_CENTER_TOP, Vector2(-460, 36), Vector2(920, 150))
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/logo_gradient.gdshader")
	m.set_shader_parameter("height", 150.0)
	logo_top.material = m
	add_child(logo_top)
	logo_bottom = Label.new()
	logo_bottom.text = "California"
	logo_bottom.add_theme_font_override("font", UIStyle.font_script())
	logo_bottom.add_theme_font_size_override("font_size", 64)
	logo_bottom.add_theme_color_override("font_color", Color(1, 0.35, 0.75))
	logo_bottom.add_theme_color_override("font_outline_color", Color(1, 0.2, 0.6, 0.35))
	logo_bottom.add_theme_constant_override("outline_size", 14)
	logo_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_bottom.rotation = -0.06
	UIStyle.place(logo_bottom, Control.PRESET_CENTER_TOP, Vector2(-250, 178), Vector2(700, 90))
	add_child(logo_bottom)
	osd = UIStyle.label("PLAY ▶", 22, UIStyle.PAPER, true)
	osd.position = Vector2(28, 20)
	add_child(osd)
	press_label = UIStyle.label("PRESS ANY BUTTON", 22, UIStyle.GOLD, true)
	press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.place(press_label, Control.PRESET_CENTER_BOTTOM, Vector2(-300, -130), Vector2(600, 30))
	add_child(press_label)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 2)
	menu.visible = false
	UIStyle.place(menu, Control.PRESET_CENTER_BOTTOM, Vector2(-140, -250), Vector2(280, 230))
	add_child(menu)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 420)
	panel.visible = false
	UIStyle.place(panel, Control.PRESET_CENTER, Vector2(-380, -190), Vector2(760, 420))
	add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(730, 390)
	panel.add_child(sc)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", 6)
	sc.add_child(panel_body)
	Music.play("title")
	PostFX.set_desaturate(0.0)
	PostFX.set_tint(Color(1, 1, 1, 0))
	Audio.set_music_muffled(false)
	PostFX.vhs_glitch(1.0)
	Audio.play("vhs_static", -8.0)

func _process(delta: float) -> void:
	_t += delta
	press_label.modulate.a = 0.5 + 0.5 * sin(_t * 4.0)
	var flick := 1.0
	if fmod(_t, 5.1) < 0.08 or fmod(_t, 3.3) < 0.04:
		flick = 0.35
	logo_bottom.modulate = Color(1, 1, 1, flick)
	var secs := int(_t)
	osd.text = "PLAY ▶   SP   %d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
	logo_top.position.y = 36 + sin(_t * 1.3) * 3.0

## The "press any button" gate listens in _input: the full-screen title
## Control would otherwise swallow a mouse click before _unhandled_input.
func _input(e: InputEvent) -> void:
	if not _started and UIStyle.is_any_press(e):
		get_viewport().set_input_as_handled()
		_start_menu()

func _unhandled_input(e: InputEvent) -> void:
	if panel.visible and (e.is_action_pressed("ui_cancel") or e.is_action_pressed("ui_cancel_alt")):
		_close_panel()
		get_viewport().set_input_as_handled()

func _start_menu() -> void:
	_started = true
	press_label.visible = false
	Audio.play("ui_select")
	PostFX.vhs_glitch(0.5)
	_build_menu()

func _build_menu() -> void:
	for c in menu.get_children():
		c.queue_free()
	menu.visible = true
	var has_save := SaveManager.has_progress()
	if has_save:
		_add("CONTINUE", Game.continue_game)
	_add("NEW GAME", _confirm_new_game if has_save else _choose_difficulty)
	_add("CHAPTERS", _show_chapters)
	var arcade_unlocked: bool = SaveManager.data.missions.has("m01_checkout")
	_add("ARCADE" if arcade_unlocked else "ARCADE  [LOCKED]", _show_arcade, not arcade_unlocked)
	_add("CAST", _show_cast)
	_add("EXTRAS", _show_extras)
	_add("OPTIONS", _show_options)
	_add("QUIT", func(): get_tree().quit())
	UIStyle.reveal(menu)
	await get_tree().process_frame
	if menu.get_child_count() > 0:
		(menu.get_child(0) as Button).grab_focus()

func _add(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(func():
		Audio.play("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", -8.0))
	UIStyle.menu_fx(b)
	menu.add_child(b)
	return b

# ------------------------------------------------------------ panels
func _open_panel(title: String) -> void:
	for c in panel_body.get_children():
		c.queue_free()
	panel.visible = true
	menu.visible = false
	panel_body.add_child(UIStyle.title_label(title, 34))
	# panels drop in rather than pop
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.14)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_reveal_panel.call_deferred()

func _reveal_panel() -> void:
	UIStyle.reveal(panel_body, 0.02)

func _close_panel() -> void:
	panel.visible = false
	menu.visible = true
	Audio.play("ui_back")
	if menu.get_child_count() > 0:
		(menu.get_child(0) as Button).grab_focus()

func _panel_button(text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = disabled
	b.pressed.connect(func():
		Audio.play("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", -10.0))
	UIStyle.menu_fx(b)
	panel_body.add_child(b)
	return b

func _back_button() -> void:
	var b := _panel_button("◀ BACK", _close_panel)
	b.grab_focus()

func _confirm_new_game() -> void:
	_open_panel("NEW GAME")
	panel_body.add_child(UIStyle.label("This will overwrite your story progress.\nScores, collectibles and unlocks are kept.", 16))
	var b := _panel_button("START OVER", _choose_difficulty)
	_panel_button("◀ BACK", _close_panel)
	b.grab_focus()

## Pick a difficulty before a new game. Can be changed any time in OPTIONS.
func _choose_difficulty() -> void:
	_open_panel("DIFFICULTY")
	var first: Button = null
	for i in Difficulty.NAMES.size():
		var lv: int = i
		var b := _panel_button(Difficulty.NAMES[i], func():
			SaveManager.set_setting("difficulty", lv)
			Game.new_game())
		var d := UIStyle.label(Difficulty.DESCRIPTIONS[i], 14, UIStyle.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(700, 0)
		panel_body.add_child(d)
		if i == Difficulty.current():
			first = b
	panel_body.add_child(UIStyle.label("You can change this at any time in OPTIONS.", 13, UIStyle.CYAN))
	_back_button()
	if first:
		first.grab_focus()

func _show_chapters() -> void:
	_open_panel("CHAPTERS")
	var done: bool = SaveManager.data.missions.has("m01_checkout")
	var reached: bool = int(SaveManager.data.story.chapter) >= 2 or done
	var first := _panel_button("1988  ·  CHAPTER I  ·  CHECKOUT TIME  —  Sunset Palms Motel", func():
		if reached:
			Game.replay_mission("m01_checkout")
		else:
			Game.new_game())
	var m2_open: bool = done or SaveManager.data.missions.has("m02_dog_days")
	_panel_button("1988  ·  CHAPTER I-B  ·  DOG DAYS  —  Yermo Salvage & K-9" if m2_open else "1988  ·  CHAPTER I-B  ·  ████████  —  FINISH CHAPTER I", func():
		Game.replay_mission("m02_dog_days"), not m2_open)
	first.grab_focus()
	_panel_button("1990  ·  CHAPTER II  ·  ████████  —  TAPE DAMAGED", func(): pass, true)
	_panel_button("1991  ·  CHAPTER III  ·  ████████  —  TAPE DAMAGED", func(): pass, true)
	_panel_button("1992  ·  CHAPTER IV  ·  ████████  —  TAPE DAMAGED", func(): pass, true)
	_back_button()
	first.grab_focus()

func _show_arcade() -> void:
	_open_panel("ARCADE  ·  SCORE ATTACK")
	panel_body.add_child(UIStyle.label("Pick a mission and a rule set. Best runs go on the local board.", 15, UIStyle.DIM))
	var modes := [
		["STANDARD", {}],
		["MELEE ONLY", {"melee_only": true}],
		["NO ABILITY", {"no_ability": true}],
		["HARD", {"hard": true}],
	]
	var first: Button = null
	for mid in ["m01_checkout", "m02_dog_days"]:
		var md: MissionData = Game.missions.get(mid)
		if md == null:
			continue
		var unlocked: bool = mid == "m01_checkout" or SaveManager.data.missions.has("m01_checkout")
		panel_body.add_child(UIStyle.label("\n" + tr(md.title) + ("" if unlocked else tr("  [LOCKED]")), 18, UIStyle.PINK if unlocked else UIStyle.DIM, true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel_body.add_child(row)
		for m in modes:
			var mods: Dictionary = m[1]
			var id: String = mid
			var b := Button.new()
			b.text = str(m[0])
			b.disabled = not unlocked
			b.pressed.connect(func():
				Audio.play("ui_select")
				Game.replay_mission(id, "cass", mods))
			row.add_child(b)
			if first == null and unlocked:
				first = b
		var board: Array = SaveManager.data.leaderboards.get(mid, [])
		for i in mini(board.size(), 5):
			var r: Dictionary = board[i]
			panel_body.add_child(UIStyle.label("%2d.  %-4s  %8d   %s   %s" % [i + 1, r.rank, int(r.score), Level._fmt_time(float(r.time)), r.date], 14))
	_back_button()
	if first:
		first.grab_focus()

func _show_cast() -> void:
	_open_panel("CAST")
	var ids := ["cass", "deacon", "luz", "tilly", "dana", "nadia", "marv", "wes", "bobby", "director"]
	for id in ids:
		var c: CharacterData = Game.characters.get(StringName(id))
		if c == null:
			continue
		var unlocked: bool = String(c.id) in SaveManager.data.unlocked_characters
		var head := "%s  —  %s  (%d)" % [tr(c.display_name) if unlocked else "???", tr(c.archetype), c.year_first_seen]
		panel_body.add_child(UIStyle.label(head, 17, UIStyle.PINK if unlocked else UIStyle.DIM, true))
		var bio := tr(c.bio) if unlocked else tr("Not yet on tape.")
		var l := UIStyle.label(bio + ("\n+ %s   − %s" % [tr(c.strengths), tr(c.weaknesses)] if unlocked else ""), 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(700, 0)
		panel_body.add_child(l)
	_back_button()

func _show_extras() -> void:
	_open_panel("EXTRAS")
	panel_body.add_child(UIStyle.label("EVIDENCE LOCKER", 18, UIStyle.GOLD, true))
	for lf in [["res://levels/m01_sunset_palms.json", "Sunset Palms Motel"], ["res://levels/m02_yermo_salvage.json", "Yermo Salvage"]]:
		var lvl: Variant = JSON.parse_string(FileAccess.get_file_as_string(lf[0]))
		var all: Dictionary = lvl.get("collectibles", {}) if lvl is Dictionary else {}
		for k in all.keys():
			var cd: Dictionary = all[k]
			var got: bool = cd.id in SaveManager.data.collectibles
			panel_body.add_child(UIStyle.label(("■ " if got else "□ ") + (tr(str(cd.title)) if got else "??? — " + tr(str(lf[1]))), 15, UIStyle.PAPER if got else UIStyle.DIM))
			if got:
				var l := UIStyle.label(tr(str(cd.text)), 13, UIStyle.DIM)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(700, 0)
				panel_body.add_child(l)
	panel_body.add_child(UIStyle.label("\nSTATISTICS", 18, UIStyle.GOLD, true))
	var st: Dictionary = SaveManager.data.stats
	panel_body.add_child(UIStyle.label(tr("Kills %d    Deaths %d    Executions %d    Secrets %d    Play time %s") % [int(st.get("kills", 0)), int(st.get("deaths", 0)), int(st.get("executions", 0)), SaveManager.data.secrets.size(), Level._fmt_time(float(st.get("play_time", 0.0)))], 14))
	for mid in ["m01_checkout", "m02_dog_days"]:
		var best: Dictionary = SaveManager.data.missions.get(mid, {})
		var md: MissionData = Game.missions.get(mid)
		if not best.is_empty() and md:
			panel_body.add_child(UIStyle.label(tr("%s — best %d (%s)") % [tr(md.title), int(best.get("best_score", 0)), best.get("best_rank", "")], 14))
	panel_body.add_child(UIStyle.label("\nCREDITS", 18, UIStyle.GOLD, true))
	var cr := UIStyle.label("HOTSHOT CALIFORNIA — an original game.\nDesign, code, pixels, synthesized music and sound: made procedurally for this vertical slice.\nFonts: DejaVu Sans Mono (Bitstream Vera license), Poppins & Lora (SIL OFL).\nBe kind. Rewind.", 13, UIStyle.DIM)
	cr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cr.custom_minimum_size = Vector2(700, 0)
	panel_body.add_child(cr)
	_panel_button("RESET ALL PROGRESS", func():
		SaveManager.reset_progress()
		_close_panel()
		_build_menu())
	_back_button()

func _show_options() -> void:
	menu.visible = false
	_options = OptionsMenu.new()
	add_child(_options)
	_options.closed.connect(func():
		_options = null
		menu.visible = true
		(menu.get_child(0) as Button).grab_focus())
