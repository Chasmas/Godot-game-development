extends Control
## Title screen + front-end: continue, new game, chapters, arcade/challenges
## with local leaderboards, cast, extras (gallery, stats, credits), options.

var backdrop: TitleBackdrop
var key_art: TextureRect
var key_art_shade: ColorRect
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
	# Optional production key art. If the PNG is absent, the procedural backdrop remains.
	var title_tex := CinematicArt.title_texture()
	if title_tex:
		key_art = CinematicArt.make_fullscreen(title_tex)
		key_art.modulate = Color(1, 1, 1, 0.94)
		add_child(key_art)
		key_art_shade = ColorRect.new()
		key_art_shade.color = Color(0.015, 0.0, 0.04, 0.20)
		key_art_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		key_art_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(key_art_shade)
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
	if key_art:
		# The commissioned key art already contains the HOTSHOT wordmark.
		logo_top.visible = false
		logo_bottom.visible = false
	osd = UIStyle.label("PLAY ▶", 22, UIStyle.PAPER, true)
	osd.position = Vector2(28, 20)
	add_child(osd)
	press_label = UIStyle.label("PRESS ANY BUTTON", 22, UIStyle.GOLD, true)
	press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if key_art:
		press_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		UIStyle.place(press_label, Control.PRESET_BOTTOM_LEFT, Vector2(76, -82), Vector2(560, 30))
	else:
		UIStyle.place(press_label, Control.PRESET_CENTER_BOTTOM, Vector2(-300, -130), Vector2(600, 30))
	add_child(press_label)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 2)
	menu.visible = false
	if key_art:
		# Art-directed composition: menu sits in the quieter lower-left quadrant.
		menu.anchor_left = 0.0
		menu.anchor_right = 0.0
		menu.anchor_top = 1.0
		menu.anchor_bottom = 1.0
		menu.offset_left = 76
		menu.offset_right = 356
		menu.offset_top = -292
		menu.offset_bottom = -62
	else:
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
	if key_art:
		# Near-imperceptible Ken Burns drift keeps the painted title screen alive.
		key_art.pivot_offset = key_art.size * 0.5
		var breathe := 1.018 + sin(_t * 0.16) * 0.004
		key_art.scale = Vector2.ONE * breathe
		key_art.position = Vector2(sin(_t * 0.11) * 3.0, cos(_t * 0.09) * 2.0)

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
	var m2_open: bool = done or SaveManager.data.missions.has("m02_dog_days")
	var chapters := [
		{"mission": "m01_checkout", "year": "1988", "num": "I", "title": "CHECKOUT TIME", "place": "Sunset Palms Motel", "cover": "motel_night", "open": true},
		{"mission": "m02_dog_days", "year": "1988", "num": "I-B", "title": "DOG DAYS", "place": "Yermo Salvage & K-9", "cover": "salvage_yard", "open": m2_open},
		{"mission": "m03_prime_time", "year": "1988", "num": "I-C", "title": "PRIME TIME", "place": "KHSC Studios, Stage Nine", "cover": "burbank_night", "open": SaveManager.data.missions.has("m02_dog_days") or SaveManager.data.missions.has("m03_prime_time")},
		{"mission": "m04_sweet_dreams", "year": "1988", "num": "I-D", "title": "SWEET DREAMS", "place": "Villa Estrella", "cover": "villa_gate", "open": SaveManager.data.missions.has("m03_prime_time") or SaveManager.data.missions.has("m04_sweet_dreams")},
		{"mission": "", "year": "1990", "num": "II", "title": "THE GALAXY PALACE", "place": "TAPE DAMAGED", "cover": "galaxy_palace", "open": false},
		{"mission": "", "year": "1991", "num": "III", "title": "BARSTOW PD", "place": "TAPE DAMAGED", "cover": "barstow_pd", "open": false},
		{"mission": "", "year": "1992", "num": "IV", "title": "THE HILLS", "place": "TAPE DAMAGED", "cover": "hills_fire", "open": false},
	]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_body.add_child(row)
	var detail := ChapterDetail.new()
	detail.custom_minimum_size = Vector2(720, 96)
	var first: ChapterCard = null
	for ch in chapters:
		var card := ChapterCard.new()
		card.info = ch
		card.custom_minimum_size = Vector2(132, 214)
		var info: Dictionary = ch
		card.focus_entered.connect(func():
			Audio.play("ui_move", -8.0)
			detail.info = info)
		card.mouse_entered.connect(func(): card.grab_focus())
		card.pressed.connect(func():
			if not info.open:
				Audio.play("ui_back")
				PostFX.vhs_glitch(0.4)
				card.shake()
				return
			Audio.play("ui_select")
			PostFX.vhs_glitch(0.6)
			if info.mission == "m01_checkout" and not reached:
				Game.new_game()
			else:
				Game.replay_mission(str(info.mission)))
		row.add_child(card)
		if first == null:
			first = card
	panel_body.add_child(detail)
	_back_button()
	first.grab_focus()

## A chapter as a VHS tape box: painted cover (the chapter's story shot),
## year spine, title strip. Lifts and glows when focused; locked tapes show
## tracking noise and a DAMAGED sticker.
class ChapterCard extends Button:
	var info: Dictionary
	var _t := 0.0
	var _lift := 0.0
	var _shake := 0.0
	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	func shake() -> void:
		_shake = 1.0
	func _process(delta: float) -> void:
		_t += delta
		_lift = move_toward(_lift, 1.0 if has_focus() else 0.0, delta * 6.0)
		_shake = move_toward(_shake, 0.0, delta * 3.0)
		queue_redraw()
	func _draw() -> void:
		var open: bool = info.get("open", false)
		var e := _lift * _lift * (3.0 - 2.0 * _lift)
		var off := Vector2(sin(_t * 60.0) * 4.0 * _shake, -10.0 * e)
		var r := Rect2(Vector2(4, 12) + off, size - Vector2(8, 16))
		# shadow
		draw_rect(Rect2(r.position + Vector2(4, 8 + 6 * e), r.size), Color(0, 0, 0, 0.35 + 0.2 * e))
		# glow when focused
		if e > 0.01:
			for k in 3:
				draw_rect(r.grow(2.0 + k * 3.0), Color(UIStyle.PINK, (0.18 - k * 0.05) * e), false, 3.0)
		draw_rect(r, UIStyle.INK)
		# cover art: the chapter's story shot, cropped to the box
		var art := Rect2(r.position + Vector2(6, 22), Vector2(r.size.x - 12, r.size.y - 70))
		var cover := StoryShot.resolve(str(info.get("cover", "")))
		var painted := StoryShot.painted_tex(cover)
		if painted:
			var pw := float(painted.get_width())
			var ph := float(painted.get_height())
			var psw := ph * art.size.x / art.size.y
			var ppan := sin(_t * 0.4) * 30.0 * e
			draw_texture_rect_region(painted, art, Rect2((pw - psw) * 0.5 + ppan, 0, psw, ph), Color(1, 1, 1) if open else Color(0.45, 0.4, 0.5))
		for l in ([] if painted else ["bg", "mid", "sign", "fg", "eyes"]):
			var tx := StoryShot.tex(cover, l)
			if tx == null:
				continue
			var tw := float(tx.get_width())
			var th := float(tx.get_height())
			var src_w := th * art.size.x / art.size.y
			var pan := sin(_t * 0.4) * 10.0 * e
			var src := Rect2((tw - src_w) * 0.5 + pan, 0, src_w, th)
			var mod := Color(1, 1, 1) if open else Color(0.45, 0.4, 0.5)
			if l == "eyes":
				mod.a = 0.7 + 0.3 * sin(_t * 2.0)
			draw_texture_rect_region(tx, art, src, mod)
		if not open:
			# tracking noise and a damaged-tape sticker
			var rng := RandomNumberGenerator.new()
			rng.seed = int(_t * 12.0) + int(info.get("year", "0"))
			for i in 40:
				var y := art.position.y + rng.randf() * art.size.y
				draw_rect(Rect2(art.position.x, y, art.size.x, rng.randf_range(1, 3)), Color(1, 1, 1, rng.randf_range(0.03, 0.15)))
			var st := Rect2(art.position + Vector2(8, art.size.y * 0.4), Vector2(art.size.x - 16, 22))
			draw_set_transform(st.get_center(), -0.12, Vector2.ONE)
			draw_rect(Rect2(-st.size * 0.5, st.size), Color(0.9, 0.85, 0.7))
			draw_string(UIStyle.font_bold(), Vector2(-st.size.x * 0.5 + 6, 5), tr("DAMAGED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.6, 0.05, 0.1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# shine sweep across the box sleeve
		if e > 0.0:
			var sx := fmod(_t * 0.7, 1.6) * (art.size.x + 60.0) - 30.0
			draw_colored_polygon(PackedVector2Array([art.position + Vector2(sx, 0), art.position + Vector2(sx + 14, 0), art.position + Vector2(sx - 6, art.size.y), art.position + Vector2(sx - 20, art.size.y)]), Color(1, 1, 1, 0.07 * e))
		# frame, year band and title strip
		var col := UIStyle.PINK if open else UIStyle.DIM
		draw_rect(r, col.lerp(UIStyle.GOLD, e * 0.5) if open else col, false, 2.0)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 20)), col if open else Color(0.2, 0.18, 0.24))
		draw_string(UIStyle.font_bold(), r.position + Vector2(6, 15), str(info.get("year", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.INK if open else UIStyle.DIM)
		draw_string(UIStyle.font_bold(), r.position + Vector2(44, 15), tr("CH.") + " " + str(info.get("num", "")), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 50, 12, UIStyle.INK if open else UIStyle.DIM)
		var title := tr(str(info.get("title", ""))) if open else "████████"
		draw_multiline_string(UIStyle.font_display(), Vector2(r.position.x + 6, r.end.y - 30), title, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 14, 2, UIStyle.PAPER if open else UIStyle.DIM)
		if open and e > 0.3:
			var pr := Rect2(art.end - Vector2(62, 20), Vector2(58, 16))
			draw_rect(pr, Color(UIStyle.INK, 0.85 * e))
			draw_string(UIStyle.font_mono(), pr.position + Vector2(5, 12), tr("▶ PLAY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UIStyle.GOLD, e * (0.7 + 0.3 * sin(_t * 6.0))))


## Under the tapes: what the focused chapter is, and how you did.
class ChapterDetail extends Control:
	var info: Dictionary = {}
	var _t := 0.0
	var _shown := ""
	var _k := 0.0
	func _process(delta: float) -> void:
		_t += delta
		var key := str(info.get("title", ""))
		if key != _shown:
			_shown = key
			_k = 0.0
		_k = move_toward(_k, 1.0, delta * 5.0)
		queue_redraw()
	func _draw() -> void:
		if info.is_empty():
			return
		var open: bool = info.get("open", false)
		var x := 20.0 * (1.0 - _k)
		var a := _k
		var f := UIStyle.font_display()
		var head := "%s  ·  %s  ·  %s" % [str(info.year), tr("CHAPTER") + " " + str(info.num), tr(str(info.title)) if open else "████████"]
		draw_string(f, Vector2(8 + x, 30), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIStyle.PINK if open else UIStyle.DIM, a))
		draw_string(UIStyle.font_bold(), Vector2(8 + x, 54), tr(str(info.place)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UIStyle.CYAN if open else UIStyle.DIM, a))
		var line := ""
		var mid := str(info.get("mission", ""))
		if open and mid != "":
			var best: Dictionary = SaveManager.data.missions.get(mid, {})
			if best.is_empty():
				line = tr("Not yet played.")
			else:
				line = tr("Best rank %s   ·   Best score %d") % [str(best.get("best_rank", "-")), int(best.get("best_score", 0))]
		elif not open and mid != "":
			line = tr("Finish the chapter before to unlock this tape.")
		else:
			line = tr("The rest of this tape is damaged.")
		draw_string(UIStyle.font_mono(), Vector2(8 + x, 78), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UIStyle.PAPER, 0.8 * a))

## ARCADE: pick a map, a mode and any modifiers, then go. Every
## map + mode pair keeps its own local top 10.
const ARCADE_MAPS := ["m01_checkout", "m02_dog_days", "m03_prime_time", "m04_sweet_dreams"]
const ARCADE_MODES := [
	["SCORE ATTACK", {}, "The mission as written. Every kill counts; style counts double."],
	["WAVES ×5", {"mode": "waves", "waves": 5}, "Five waves. Each one arrives in rows from the far side of the map."],
	["WAVES ×10", {"mode": "waves", "waves": 10}, "Ten waves. Supply drops between them. Don't get comfortable."],
	["ENDLESS", {"mode": "endless"}, "They keep coming until you stop. You will stop."],
]
const ARCADE_MODS := [
	["INFINITE AMMO", "infinite_ammo"], ["WEAPON ROULETTE", "roulette"], ["MELEE ONLY", "melee_only"],
	["NO SPOTLIGHT", "no_ability"], ["HARD", "hard"], ["TURBO", "turbo"],
]
const ARCADE_WEATHER := [
	["MISSION DEFAULT", ""], ["RANDOM", "random"], ["NIGHT RAIN", "night_rain"], ["DESERT WIND", "desert_wind"],
	["SANTA ANA", "santa_ana"], ["SNOWFALL", "snowfall"], ["SUNNY DAY", "sunny"], ["FOG", "foggy"], ["CLEAR NIGHT", "clear_night"],
]
var _arc_map := "m01_checkout"
var _arc_mode := 0
var _arc_mods: Dictionary = {}
var _arc_weather := 0
var _arc_focus := ""             ## which toggle to refocus after the panel rebuilds

func _arcade_unlocked(mid: String) -> bool:
	var i := ARCADE_MAPS.find(mid)
	return i <= 0 or SaveManager.data.missions.has(ARCADE_MAPS[i - 1]) or SaveManager.data.missions.has(mid)

func _show_arcade() -> void:
	_open_panel("ARCADE")
	var first: Control = null
	panel_body.add_child(UIStyle.label("MAP", 14, UIStyle.GOLD, true))
	var maps := HBoxContainer.new()
	maps.add_theme_constant_override("separation", 8)
	panel_body.add_child(maps)
	for mid in ARCADE_MAPS:
		var md: MissionData = Game.missions.get(mid)
		if md == null:
			continue
		var open := _arcade_unlocked(mid)
		var b := _arc_toggle(maps, tr(md.title) if open else tr(md.title) + tr("  [LOCKED]"), mid == _arc_map, func():
			_arc_map = mid
			_arc_focus = mid
			_show_arcade())
		b.disabled = not open
		if (first == null and mid == _arc_map and _arc_focus == "") or _arc_focus == mid:
			first = b
	panel_body.add_child(UIStyle.label("MODE", 14, UIStyle.GOLD, true))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	panel_body.add_child(modes)
	for i in ARCADE_MODES.size():
		var k := i
		var mb := _arc_toggle(modes, tr(str(ARCADE_MODES[i][0])), i == _arc_mode, func():
			_arc_mode = k
			_arc_focus = "mode%d" % k
			_show_arcade())
		if _arc_focus == "mode%d" % i:
			first = mb
	var blurb := UIStyle.label(tr(str(ARCADE_MODES[_arc_mode][2])), 14, UIStyle.DIM)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(720, 0)
	panel_body.add_child(blurb)
	panel_body.add_child(UIStyle.label("MODIFIERS", 14, UIStyle.GOLD, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	panel_body.add_child(grid)
	for m in ARCADE_MODS:
		var key: String = m[1]
		var cb := CheckButton.new()
		cb.text = tr(str(m[0]))
		cb.button_pressed = _arc_mods.get(key, false)
		cb.toggled.connect(func(on: bool):
			Audio.play("ui_select" if on else "ui_back", -6.0)
			if on:
				_arc_mods[key] = true
			else:
				_arc_mods.erase(key)
			if key == "melee_only" and on:
				_arc_mods.erase("infinite_ammo"))
		cb.focus_entered.connect(func(): Audio.play("ui_move", -10.0))
		grid.add_child(cb)
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 12)
	panel_body.add_child(wrow)
	wrow.add_child(UIStyle.label("WEATHER", 14, UIStyle.GOLD, true))
	var wopt := OptionButton.new()
	for w in ARCADE_WEATHER:
		wopt.add_item(tr(str(w[0])))
	wopt.selected = _arc_weather
	wopt.item_selected.connect(func(i: int):
		_arc_weather = i
		Audio.play("ui_select", -6.0))
	wrow.add_child(wopt)
	var go := _panel_button("▶ START", func():
		var mods: Dictionary = (ARCADE_MODES[_arc_mode][1] as Dictionary).duplicate()
		mods.merge(_arc_mods, true)
		var w := str(ARCADE_WEATHER[_arc_weather][1])
		if w != "":
			mods["weather"] = w
		Game.replay_mission(_arc_map, "cass", mods))
	go.add_theme_color_override("font_color", UIStyle.PINK)
	# local board for this map + mode
	var mode_key: String = str(ARCADE_MODES[_arc_mode][1].get("mode", ""))
	var board_id := _arc_map if mode_key == "" else "%s@%s" % [_arc_map, mode_key]
	var board: Array = SaveManager.data.leaderboards.get(board_id, [])
	panel_body.add_child(UIStyle.label("
" + tr("LOCAL BOARD"), 14, UIStyle.GOLD, true))
	if board.is_empty():
		panel_body.add_child(UIStyle.label(tr("No runs yet. Be the first name on the tape."), 14, UIStyle.DIM))
	for i in mini(board.size(), 5):
		var r: Dictionary = board[i]
		panel_body.add_child(UIStyle.label("%2d.  %-4s  %8d   %s   %s" % [i + 1, r.rank, int(r.score), Level._fmt_time(float(r.time)), r.date], 14))
	_back_button()
	if first:
		first.grab_focus()
	_arc_focus = ""

func _arc_toggle(parent: Control, text: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = ("■ " if on else "□ ") + text
	b.pressed.connect(func():
		Audio.play("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", -10.0))
	if on:
		b.add_theme_color_override("font_color", UIStyle.PINK)
	UIStyle.menu_fx(b)
	parent.add_child(b)
	return b

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
