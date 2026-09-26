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
	var title := UIStyle.title_label("%s — COMPLETE" % (Game.current_mission.title if Game.current_mission else "MISSION"), 44)
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
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.visible = false
	UIStyle.place(buttons, Control.PRESET_BOTTOM_RIGHT, Vector2(-430, -70), Vector2(400, 40))
	add_child(buttons)
	var st: Dictionary = r.get("stats", {})
	_items = [
		["TIME", Level._fmt_time(float(r.get("time", 0.0)))],
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
	await get_tree().create_timer(0.4).timeout
	buttons.visible = true
	var cont := _btn("CONTINUE", func(): Game.story_beat_finished())
	_btn("RETRY", func(): Game.start_mission(String(Game.current_mission.id), String(Game.current_character.id), Game.modifiers))
	_btn("TITLE", func(): Game.goto_title())
	cont.grab_focus()

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
