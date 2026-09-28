extends Control
## Mission results: stat tally, bonuses, the rank STAMP, best score, board place.

var r: Dictionary
var lines_box: VBoxContainer
var rank_label: Label
var buttons: HBoxContainer
var _items: Array = []
var _i := 0
var _tick := 0.0
var _done := false

func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	r = Game.last_result
	var bg := TitleBackdrop.new()
	bg.mode = "black"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color(UIStyle.PINK, 0.12)
	stripe.position = Vector2(0, 60)
	stripe.size = Vector2(4000, 70)
	add_child(stripe)
	var arc: Dictionary = r.get("arcade", {})
	var head := tr("%s — COMPLETE") % (tr(Game.current_mission.title) if Game.current_mission else tr("MISSION"))
	if not arc.is_empty():
		head = (tr("%s — ALL WAVES CLEARED") if arc.get("won", false) else tr("%s — RUN OVER")) % (tr(Game.current_mission.title) if Game.current_mission else tr("ARCADE"))
	var title := UIStyle.title_label(head, 44)
	title.position = Vector2(48, 66)
	add_child(title)
	lines_box = VBoxContainer.new()
	lines_box.position = Vector2(60, 150)
	lines_box.add_theme_constant_override("separation", 0)
	add_child(lines_box)
	rank_label = Label.new()
	rank_label.add_theme_font_override("font", UIStyle.font_display())
	rank_label.add_theme_font_size_override("font_size", 190)
	rank_label.add_theme_color_override("font_color", UIStyle.GOLD)
	rank_label.add_theme_color_override("font_outline_color", UIStyle.INK)
	rank_label.add_theme_constant_override("outline_size", 18)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.pivot_offset = Vector2(190, 130)
	rank_label.modulate.a = 0.0
	rank_label.rotation = -0.12
	UIStyle.place(rank_label, Control.PRESET_CENTER_RIGHT, Vector2(-430, -170), Vector2(380, 260))
	add_child(rank_label)
	if not Game.highlights.is_empty():
		var reel := HighlightReel.new()
		UIStyle.place(reel, Control.PRESET_TOP_LEFT, Vector2(360, 140), Vector2(240, 175))
		add_child(reel)
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.visible = false
	UIStyle.place(buttons, Control.PRESET_BOTTOM_RIGHT, Vector2(-430, -70), Vector2(400, 40))
	add_child(buttons)
	var st: Dictionary = r.get("stats", {})
	_items = [
		["TIME", Level._fmt_time(float(r.get("time", 0.0)))] if arc.is_empty() else ["WAVE REACHED", str(int(arc.get("wave", 0)))],
		["KILLS", str(int(st.get("kills", 0)))],
		["MAX COMBO", "%dx" % int(r.get("max_combo", 0))],
		["ACCURACY", "%d%%" % int(float(r.get("accuracy", 0.0)) * 100.0)],
		["EXECUTIONS", str(int(st.get("executions", 0)))],
		["SILENT KILLS", str(int(st.get("silent_kills", 0)))],
		["WEAPON VARIETY", str(int(r.get("variety", 0)))],
		["ATTEMPTS", str(int(st.get("attempts", 1)))],
		["", ""],
		["SCORE", str(int(r.get("score", 0)))],
		["TIME BONUS", "+%d" % int(r.get("time_bonus", 0))],
		["FLOW BONUS", "+%d" % int(r.get("flow_bonus", 0))],
		["STYLE BONUS", "+%d" % int(r.get("variety_bonus", 0))],
		["ACCURACY BONUS", "+%d" % int(r.get("accuracy_bonus", 0))],
		["TOTAL", str(int(r.get("total", 0)))],
	]
	Music.play("aftermath")

func _process(delta: float) -> void:
	if _done:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	if _i < _items.size():
		var it: Array = _items[_i]
		var hb := HBoxContainer.new()
		var big: bool = it[0] == "TOTAL"
		var a := UIStyle.label(it[0], 22 if big else 16, UIStyle.DIM if not big else UIStyle.PINK, true)
		a.custom_minimum_size = Vector2(230, 0)
		var b := UIStyle.label(it[1], 22 if big else 16, UIStyle.PAPER if not big else UIStyle.GOLD, true)
		hb.add_child(a)
		hb.add_child(b)
		lines_box.add_child(hb)
		if it[0] != "":
			Audio.play("blip", -4.0, 1.0 + _i * 0.03)
		_i += 1
		_tick = 0.09
	else:
		_done = true
		_stamp()

func _stamp() -> void:
	rank_label.text = str(r.get("rank", "C"))
	rank_label.scale = Vector2(2.4, 2.4)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(rank_label, "modulate:a", 1.0, 0.12)
	tw.tween_property(rank_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("rank_stamp", 2.0)
	PostFX.vhs_glitch(0.5)
	var extra := ""
	if r.get("new_best", false):
		extra = "NEW BEST!"
	if int(r.get("place", 0)) > 0:
		extra += "   LOCAL BOARD #%d" % int(r.place)
	var ex := UIStyle.label(extra, 20, UIStyle.CYAN, true)
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIStyle.place(ex, Control.PRESET_CENTER_RIGHT, Vector2(-420, 100), Vector2(360, 30))
	add_child(ex)
	_director_notes()
	await get_tree().create_timer(0.4).timeout
	buttons.visible = true
	var cont := _btn("CONTINUE", func(): Game.story_beat_finished())
	_btn("RETRY", func(): Game.start_mission(String(Game.current_mission.id), String(Game.current_character.id), Game.modifiers))
	_btn("TITLE", func(): Game.goto_title())
	cont.grab_focus()

## THE VOICE reviews the take: two notes picked from how you played, typed
## out under the rank.
func _director_notes() -> void:
	var st: Dictionary = r.get("stats", {})
	var notes: Array[String] = []
	var attempts := int(st.get("attempts", 1))
	if attempts >= 5:
		notes.append(tr("%d takes. The audience never sees the takes. I do.") % attempts)
	if float(r.get("accuracy", 1.0)) < 0.35 and int(st.get("shots", 0)) > 10:
		notes.append(tr("You spray like a garden hose. Aim is a choice."))
	if int(r.get("max_combo", 0)) >= 8:
		notes.append(tr("That run in the middle - that's the trailer."))
	if int(st.get("silent_kills", 0)) >= 5:
		notes.append(tr("Quiet work. I had to turn the volume up."))
	if int(st.get("executions", 0)) >= 4:
		notes.append(tr("You finish what you start. Close-ups sell."))
	if int(st.get("feeds_cut", 0)) >= 1:
		notes.push_front(tr("You found my cameras. Rude. There are always more."))
	elif int(st.get("camera_kills", 0)) >= 2:
		notes.push_front(tr("You played to the camera. I'm keeping that footage."))
	if attempts <= 1 and notes.size() < 2:
		notes.append(tr("One take. Print it."))
	if notes.is_empty():
		notes.append(tr("Adequate. Tomorrow, be magnificent."))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	UIStyle.place(box, Control.PRESET_BOTTOM_LEFT, Vector2(60, -96), Vector2(450, 90))
	add_child(box)
	box.add_child(UIStyle.label("DIRECTOR'S NOTES", 12, UIStyle.GOLD, true))
	for i in mini(2, notes.size()):
		var l := UIStyle.label("“" + notes[i] + "”", 13, UIStyle.PAPER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(450, 0)
		l.visible_ratio = 0.0
		box.add_child(l)
		var tw := create_tween()
		tw.tween_interval(0.3 + i * 1.1)
		tw.tween_callback(func(): Audio.play("type_clack", -12.0))
		tw.tween_property(l, "visible_ratio", 1.0, 0.9)

func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(func():
		Audio.play("ui_select")
		cb.call())
	buttons.add_child(b)
	return b

func _unhandled_input(e: InputEvent) -> void:
	if not _done and (e.is_action_pressed("ui_confirm") or e.is_action_pressed("fire")):
		# skip the tally
		while _i < _items.size():
			_tick = 0.0
			_process(0.0)
		get_viewport().set_input_as_handled()


## HIGHLIGHTS: the job's best kills, played back as a tape - each frame
## pushes in slowly, the deck's OSD shows the time and the combo, and a
## splice of tracking noise cuts to the next.
class HighlightReel extends Control:
	var _texs: Array = []
	var _i := 0
	var _t := 0.0
	const HOLD := 2.6
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for h in Game.highlights:
			_texs.append(ImageTexture.create_from_image(h.img))
	func _process(delta: float) -> void:
		_t += delta
		if _t > HOLD:
			_t = 0.0
			_i = (_i + 1) % maxi(1, _texs.size())
		queue_redraw()
	func _draw() -> void:
		if _texs.is_empty():
			return
		var fb := UIStyle.font_bold()
		var fm := UIStyle.font_mono()
		draw_string(fb, Vector2(0, 14), tr("HIGHLIGHTS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.GOLD)
		var r := Rect2(Vector2(0, 22), Vector2(size.x, size.x * 9.0 / 16.0))
		draw_rect(r.grow(4), Color(0.1, 0.08, 0.1))
		var tex: Texture2D = _texs[_i]
		var z := 1.0 + 0.06 * (_t / HOLD)
		var src_sz := Vector2(tex.get_width(), tex.get_height()) / z
		var src := Rect2((Vector2(tex.get_width(), tex.get_height()) - src_sz) * 0.5, src_sz)
		draw_texture_rect_region(tex, r, src)
		var h: Dictionary = Game.highlights[_i]
		var secs := int(float(h.t))
		draw_string(fm, r.position + Vector2(8, 16), "PLAY ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))
		draw_string(fm, r.position + Vector2(r.size.x - 70, 16), "%d:%02d" % [secs / 60, secs % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
		if int(h.combo) > 1:
			draw_string(fb, r.position + Vector2(8, r.size.y - 10), tr("COMBO %dx") % int(h.combo), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIStyle.PINK)
		if _t < 0.2:
			var rng := RandomNumberGenerator.new()
			rng.seed = int(_t * 100.0) + _i
			for k in 6:
				draw_rect(Rect2(r.position.x, r.position.y + rng.randf() * r.size.y, r.size.x, rng.randf_range(2, 8)), Color(1, 1, 1, 0.3))
		for yy in range(int(r.position.y), int(r.end.y), 3):
			draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(0, 0, 0, 0.15), 1.0)
		draw_string(fm, Vector2(0, r.end.y + 18), "%d / %d" % [_i + 1, _texs.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UIStyle.DIM)
