extends Control
## Title screen + front-end: continue, new game, chapters, arcade/challenges
## with local leaderboards, cast, extras (gallery, stats, credits), options.

var backdrop: TitleBackdrop
var key_art: TextureRect
var key_art_shade: ColorRect
var logo_top: Label
var logo_bottom: Label
var press_label: Label
var press_fx: PressStart
var vignette: StoryShot
const VIGNETTES := ["menu_smoke", "menu_revolver", "menu_dutch", "menu_marv", "menu_arlo", "menu_tommy"]
var _vig_i := -1
var _vig_t := 0.0             ## time on the current picture
var _vig_on := false          ## showing a vignette (vs the key art)
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
		# behind the key art: small moments from the story it dissolves to now
		# and then (Cass smoking at the window, loading the revolver, the
		# Fireman lighting his pilot, Marv practising his smile...)
		vignette = StoryShot.new()
		vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vignette.letterbox = false
		vignette.ambience = false
		vignette.shot_time = 30.0
		vignette.modulate.a = 0.0
		add_child(vignette)
		key_art = CinematicArt.make_fullscreen(title_tex)
		key_art.modulate = Color(1, 1, 1, 0.94)
		# a tape on an old deck: the picture holds still, the tape doesn't
		var vm := ShaderMaterial.new()
		vm.shader = load("res://shaders/vcr_filter.gdshader")
		key_art.material = vm
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
		# The commissioned key art already contains the HOTSHOT wordmark; the
		# drawn one only shows over the vignettes, where the painted one sits
		logo_top.visible = false
		logo_bottom.visible = false
		logo_top.add_theme_font_size_override("font_size", 92)
		UIStyle.place(logo_top, Control.PRESET_TOP_LEFT, Vector2(40, 34), Vector2(560, 120))
		logo_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		logo_bottom.add_theme_font_size_override("font_size", 50)
		UIStyle.place(logo_bottom, Control.PRESET_TOP_LEFT, Vector2(150, 128), Vector2(460, 80))
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
	press_fx = PressStart.new()
	press_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if key_art:
		UIStyle.place(press_fx, Control.PRESET_BOTTOM_LEFT, Vector2(60, -150), Vector2(520, 90))
	else:
		UIStyle.place(press_fx, Control.PRESET_CENTER_BOTTOM, Vector2(-260, -190), Vector2(520, 90))
	add_child(press_fx)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 0)
	menu.visible = false
	if key_art:
		# Art-directed composition: menu sits in the quieter lower-left quadrant.
		menu.anchor_left = 0.0
		menu.anchor_right = 0.0
		menu.anchor_top = 1.0
		menu.anchor_bottom = 1.0
		menu.offset_left = 76
		menu.offset_right = 356
		menu.anchor_top = 0.0
		menu.anchor_bottom = 0.0
		menu.offset_top = 226
		menu.offset_bottom = 506
		menu.offset_right = 470
	else:
		UIStyle.place(menu, Control.PRESET_CENTER_BOTTOM, Vector2(-140, -250), Vector2(280, 230))
	add_child(menu)
	menu_desc = UIStyle.label("", 15, UIStyle.PAPER, true)
	menu_desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	menu_desc.add_theme_constant_override("outline_size", 5)
	UIStyle.place(menu_desc, Control.PRESET_TOP_LEFT, Vector2(76, 510), Vector2(640, 22))
	menu_desc.visible = false
	add_child(menu_desc)
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
	press_label.modulate.a = 0.0   # PressStart draws it now
	if press_fx:
		press_fx.visible = not _started
	var flick := 1.0
	if fmod(_t, 5.1) < 0.08 or fmod(_t, 3.3) < 0.04:
		flick = 0.35
	logo_bottom.modulate = Color(1, 1, 1, flick)
	var secs := int(_t)
	osd.text = "PLAY ▶   SP   %d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
	if not key_art:
		logo_top.position.y = 36 + sin(_t * 1.3) * 3.0
	# (the key art stays still: the VCR filter on it does the moving)
	_cycle_vignettes(delta)
	if menu_desc:
		menu_desc.visible = menu.visible
		if _desc_n < _desc_full.length():
			_desc_n += delta * 60.0
		menu_desc.text = _desc_full.substr(0, int(_desc_n))

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
	_menu_i = 0
	for c in menu.get_children():
		c.queue_free()
	menu.visible = true
	var has_save := SaveManager.has_progress()
	if has_save:
		_add("CONTINUE", Game.continue_game)
	_add("NEW GAME", _confirm_new_game if has_save else _choose_difficulty)
	_add("CHAPTERS", _show_chapters)
	_add("PLAY VIDEOTAPE", _show_vcr)
	_add("MASKS", _show_masks)
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

## What each entry does, typed along the bottom when it's in focus.
const MENU_DESC := {
	"CONTINUE": "Pick the tape up where it stopped.",
	"NEW GAME": "July 4, 1988. A key to room 204, and a star to wear.",
	"CHAPTERS": "Replay any job you've been through, as many times as it takes.",
	"PLAY VIDEOTAPE": "The tapes and photos you've found. Put one in the deck.",
	"MASKS": "Every mask gives something and takes something. Pick one for the next job.",
	"ARCADE": "The jobs as score attacks, waves and endless runs, with modifiers.",
	"ARCADE  [LOCKED]": "Finish Checkout Time to open the arcade.",
	"CAST": "Who made this, and why.",
	"EXTRAS": "The evidence locker and the rest of the archive.",
	"OPTIONS": "Sound, picture, controls, language.",
	"QUIT": "Stop the tape.",
}
var menu_desc: Label
var _menu_i := 0
var _desc_full := ""
var _desc_n := 0.0

func _add(text: String, cb: Callable, disabled := false) -> Button:
	var b := TitleEntry.new()
	_menu_i += 1
	b.index = _menu_i
	b.label_text = tr(text)
	b.custom_minimum_size = Vector2(0, 28)
	b.disabled = disabled
	b.focus_entered.connect(func():
		_desc_full = tr(str(MENU_DESC.get(text, "")))
		_desc_n = 0.0)
	b.pressed.connect(func():
		Audio.play("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", -8.0))
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus())
	menu.add_child(b)
	return b

func _show_vcr() -> void:
	menu.visible = false
	var v := VcrScreen.new()
	add_child(v)
	v.closed.connect(_build_menu)

## The masks gallery: the same shelf as before a job, without the pause;
## picking one sets it for the next job.
func _show_masks() -> void:
	menu.visible = false
	var ms := MaskSelect.new()
	ms.gallery = true
	add_child(ms)
	ms.closed.connect(_build_menu)

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
		{"mission": "m01_checkout", "year": "1988", "num": "I", "title": "CHECKOUT TIME", "place": "Sunset Palms Motel", "cover": "motel_night", "box": "cover_m01", "blurb": "A key to room 204, a star to wear, and a night manager who was on fire watch in 1987.", "open": true},
		{"mission": "m02_dog_days", "year": "1988", "num": "I-B", "title": "DOG DAYS", "place": "Yermo Salvage & K-9", "cover": "salvage_yard", "box": "cover_m02", "blurb": "A salvage yard in the Mojave. Forty dogs, one old man with six TVs, and a tape somebody wants back.", "open": m2_open},
		{"mission": "m03_prime_time", "year": "1988", "num": "I-C", "title": "PRIME TIME", "place": "KHSC Studios, Stage Nine", "cover": "burbank_night", "box": "cover_m03", "blurb": "Live from Stage Nine: the premiere of HOTSHOT CALIFORNIA. The Fireman is the special guest.", "open": SaveManager.data.missions.has("m02_dog_days") or SaveManager.data.missions.has("m03_prime_time")},
		{"mission": "m04_sweet_dreams", "year": "1988", "num": "I-D", "title": "SWEET DREAMS", "place": "Villa Estrella", "cover": "villa_gate", "box": "cover_m04", "blurb": "She counts them before she sleeps. Tonight they're all at the party, and Tommy is the host.", "open": SaveManager.data.missions.has("m03_prime_time") or SaveManager.data.missions.has("m04_sweet_dreams")},
		{"mission": "", "year": "1990", "num": "II", "title": "THE GALAXY PALACE", "place": "TAPE DAMAGED", "cover": "galaxy_palace", "box": "cover_m05", "open": false},
		{"mission": "", "year": "1991", "num": "III", "title": "BARSTOW PD", "place": "TAPE DAMAGED", "cover": "barstow_pd", "box": "cover_m06", "open": false},
		{"mission": "", "year": "1992", "num": "IV", "title": "THE HILLS", "place": "TAPE DAMAGED", "cover": "hills_fire", "box": "cover_m07", "open": false},
	]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_body.add_child(row)
	var detail := ChapterDetail.new()
	detail.custom_minimum_size = Vector2(720, 132)
	var first: ChapterCard = null
	for ch in chapters:
		var card := ChapterCard.new()
		card.info = ch
		card.custom_minimum_size = Vector2(140, 236)
		var info: Dictionary = ch
		card.focus_entered.connect(func():
			Audio.play("tape_slide", -6.0, randf_range(0.95, 1.05))
			detail.info = info)
		card.mouse_entered.connect(func(): card.grab_focus())
		card.pressed.connect(func():
			if not info.open:
				Audio.play("ui_back")
				PostFX.vhs_glitch(0.4)
				card.shake()
				return
			Audio.play("tape_insert", -2.0)
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
	## the painted VHS box art (assets/art/covers), held in a static cache
	static var _boxes: Dictionary = {}
	static func _box(id: String) -> Texture2D:
		if id == "":
			return null
		if not _boxes.has(id):
			var p := "res://assets/art/covers/%s.webp" % id
			_boxes[id] = load(p) if ResourceLoader.exists(p) else null
		return _boxes[id]
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
		var painted := _box(str(info.get("box", "")))
		if painted == null:
			painted = StoryShot.painted_tex(cover)
		if painted:
			var pw := float(painted.get_width())
			var ph := float(painted.get_height())
			var psw := ph * art.size.x / art.size.y
			var ppan := sin(_t * 0.4) * 30.0 * e
			var src := Rect2((pw - psw) * 0.5 + ppan, 0, psw, ph)
			if psw > pw:
				# portrait box art: crop height instead, drifting slowly while focused
				var sh := pw * art.size.y / art.size.x
				src = Rect2(0, (ph - sh) * (0.5 + 0.3 * sin(_t * 0.3) * e), pw, sh)
			draw_texture_rect_region(painted, art, src, Color(1, 1, 1) if open else Color(0.45, 0.4, 0.5))
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
		var blurb := tr(str(info.get("blurb", ""))) if open else ""
		if blurb != "":
			var n := int(_k * 1.0 * blurb.length()) if _k < 1.0 else blurb.length()
			draw_multiline_string(UIStyle.font_bold(), Vector2(8 + x, 102), blurb.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 14, 2, Color(UIStyle.GOLD, 0.85 * a))

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
		mods["arcade"] = true
		Game.replay_mission(_arc_map, "cass", mods))
	go.add_theme_color_override("font_color", UIStyle.PINK)
	# local board for this map + mode
	var mode_key: String = str(ARCADE_MODES[_arc_mode][1].get("mode", ""))
	var board_id := _arc_map if mode_key == "" else "%s@%s" % [_arc_map, mode_key]
	var board: Array = SaveManager.data.leaderboards.get(board_id, [])
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	panel_body.add_child(gap)
	panel_body.add_child(UIStyle.label("LOCAL BOARD", 14, UIStyle.GOLD, true))
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

## CAST: the person behind the tape.
const CAST_STORY := [
	"HOTSHOT CALIFORNIA was made by one person: me, Gilberto Lopes.",
	"Since I was a kid I've dreamed of making games - the kind I grew up loving, the ones you still remember years later and tell your friends about.",
	"This one was built in the hours between everything else: late nights, weekends, a lot of coffee, and more restarts than Cass gets on a single floor.",
	"Every motel room, every tape, every note of the score came out of that same stubborn dream.",
	"If you laughed, jumped, or held your breath for a second while playing - then it worked, and every one of those nights was worth it.",
	"Thank you for playing. I really hope you have fun.",
]

func _show_cast() -> void:
	_open_panel("CAST")
	var who := UIStyle.title_label("A GAME BY GILBERTO LOPES", 30, UIStyle.GOLD)
	panel_body.add_child(who)
	panel_body.add_child(UIStyle.label(tr("WRITTEN, DESIGNED, DIRECTED AND DREAMED UP BY"), 13, UIStyle.CYAN, true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	panel_body.add_child(gap)
	for line in CAST_STORY:
		var l := UIStyle.label(tr(line), 16, UIStyle.PAPER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(700, 0)
		panel_body.add_child(l)
	var sig := UIStyle.label("-  Gilberto", 22, UIStyle.PINK, true)
	sig.add_theme_font_override("font", UIStyle.font_script())
	panel_body.add_child(sig)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 8)
	panel_body.add_child(gap2)
	panel_body.add_child(UIStyle.label(tr("WITH THANKS TO EVERYONE WHO PLAYS, TESTS AND SHARES IT."), 13, UIStyle.DIM, true))
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


## PRESS ANY BUTTON, with some life: the words in the display face with a
## chrome gradient and a shine sweeping through them, neon brackets that
## breathe in and out, a blinking play arrow, a thin scan of light under it.
class PressStart extends Control:
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var fd := UIStyle.font_display()
		var word := tr("PRESS ANY BUTTON")
		var fs := 30
		var tw := fd.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x0 := 56.0
		var y := 50.0
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		# brackets breathing out and in
		var open := 10.0 + 6.0 * pulse
		var bc := Color(UIStyle.PINK, 0.6 + 0.4 * pulse)
		for side in [-1.0, 1.0]:
			var bx := (x0 - open) if side < 0 else (x0 + tw + open)
			draw_line(Vector2(bx, y - 30), Vector2(bx, y + 8), bc, 3.0)
			draw_line(Vector2(bx, y - 30), Vector2(bx - side * 10.0, y - 30), bc, 3.0)
			draw_line(Vector2(bx, y + 8), Vector2(bx - side * 10.0, y + 8), bc, 3.0)
		# the play arrow, blinking
		if fmod(_t, 1.0) < 0.6:
			draw_colored_polygon(PackedVector2Array([Vector2(x0 - open - 34, y - 22), Vector2(x0 - open - 34, y), Vector2(x0 - open - 20, y - 11)]), UIStyle.GOLD)
		# the words: shadow, chroma split, gold-to-pink per letter, a shine
		draw_string(fd, Vector2(x0 + 3, y + 3), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
		draw_string(fd, Vector2(x0 - 2, y), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.9, 1.0, 0.35))
		var x := x0
		var shine := fmod(_t * 0.5, 1.6) * tw * 1.3 - tw * 0.15
		for i in word.length():
			var ch := word[i]
			var cw := fd.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var k := float(i) / maxf(1.0, word.length() - 1)
			var col := Color(1.0, 0.88, 0.45).lerp(Color(1.0, 0.35, 0.65), k)
			var near := clampf(1.0 - absf((x - x0) - shine) / 40.0, 0.0, 1.0)
			col = col.lerp(Color.WHITE, near * 0.8)
			draw_string(fd, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			x += cw
		# a scan of light underneath
		var sx := fmod(_t * 0.8, 1.0)
		draw_line(Vector2(x0, y + 18), Vector2(x0 + tw, y + 18), Color(UIStyle.PINK, 0.25), 1.0)
		draw_line(Vector2(x0 + tw * sx - 30, y + 18), Vector2(x0 + tw * sx + 30, y + 18), Color(1, 1, 1, 0.7), 2.0)


## A title-menu entry with some soul: a two-digit tape index in cyan, the
## name in the display face; in focus a slanted neon plate slides in behind
## it, a chrome shine runs through the letters and a play arrow blinks.
class TitleEntry extends Button:
	var index := 1
	var label_text := ""
	var _k := 0.0
	var _t := 0.0

	func _ready() -> void:
		flat = true
		text = ""
		focus_mode = Control.FOCUS_ALL
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _process(delta: float) -> void:
		_t += delta
		_k = move_toward(_k, 1.0 if has_focus() else 0.0, delta * 8.0)
		queue_redraw()

	func _draw() -> void:
		var e := _k * _k * (3.0 - 2.0 * _k)
		var h := size.y
		var fd := UIStyle.font_display()
		var fm := UIStyle.font_mono()
		# the plate
		if e > 0.01:
			var w := (size.x - 20.0) * e
			var plate := PackedVector2Array([Vector2(8, 2), Vector2(8 + w + 12, 2), Vector2(8 + w, h - 2), Vector2(-4, h - 2)])
			draw_colored_polygon(plate, Color(UIStyle.PINK, 0.85 * e))
			draw_line(Vector2(8 + w + 12, 2), Vector2(8 + w, h - 2), Color(UIStyle.CYAN, e), 2.0)
		var dis := disabled
		var ix := "%02d" % index
		draw_string(fm, Vector2(14, h * 0.5 + 6), ix, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UIStyle.CYAN, 0.35 if dis else (0.6 + 0.4 * e)))
		var col := UIStyle.DIM if dis else Color.WHITE.lerp(UIStyle.INK, e)
		var x := 46.0 + 8.0 * e
		draw_string(fd, Vector2(x + 2, h * 0.5 + 9), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, 0.6 * (1.0 - e)))
		draw_string(fd, Vector2(x, h * 0.5 + 7), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		if e > 0.5 and fmod(_t, 0.9) < 0.55:
			var ax := x + fd.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 12.0
			draw_colored_polygon(PackedVector2Array([Vector2(ax, h * 0.5 - 6), Vector2(ax, h * 0.5 + 6), Vector2(ax + 9, h * 0.5)]), UIStyle.INK)


## Key art for a good while, then a slow dissolve (through a touch of tape
## glitch) to one of the vignettes for a few seconds, and back. Only while
## no panel is open, so it never pulls the eye from reading.
func _cycle_vignettes(delta: float) -> void:
	if vignette == null or key_art == null:
		return
	_vig_t += delta
	var hold := 9.0 if _vig_on else 16.0
	if _vig_t > hold and not panel.visible:
		_vig_t = 0.0
		_vig_on = not _vig_on
		if _vig_on:
			var n := VIGNETTES.size()
			for k in n:
				_vig_i = (_vig_i + 1) % n
				if StoryShot.painted_tex(VIGNETTES[_vig_i]) != null:
					break
			vignette.show_shot(VIGNETTES[_vig_i], true)
		PostFX.vhs_glitch(0.3)
	var want := 1.0 if _vig_on else 0.0
	vignette.modulate.a = move_toward(vignette.modulate.a, want, delta / 1.6)
	key_art.modulate.a = 0.94 * (1.0 - vignette.modulate.a)
	# the wordmark rides over the vignettes (the key art has it painted in)
	logo_top.visible = vignette.modulate.a > 0.01
	logo_bottom.visible = logo_top.visible
	logo_top.modulate.a = vignette.modulate.a
