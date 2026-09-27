extends CanvasLayer
## Reusable dialogue system: speakers, portraits, typewriter text with voice
## blips, sound cues, branching, conditions, choices that set story flags,
## script events, auto-advance barks. Dialogue data: res://data/dialogue/*.json
##
## Node fields: speaker, text, next, choices[{text,next,set,if}], set{},
## branch[{if,next}], sfx, event, auto (seconds)

signal finished(dialogue_id: String)
signal event(name: String)
signal line_shown(speaker: String, text: String)

const CPS := 55.0

var speakers: Dictionary = {}
var active := false
var _data: Dictionary = {}
var _id := ""
var _node: Dictionary = {}
var _shown := 0.0
var _full := ""
var _choice_i := 0
var _choices: Array = []
var _pause_game := true
var _auto_t := -1.0
var _input_block := 0.0

var root: Control
var cinematic_art: TextureRect
var cinematic_dim: ColorRect
var letterbox_top: ColorRect
var letterbox_bottom: ColorRect
var box: PanelContainer
var name_label: Label
var text_label: RichTextLabel
var portrait: Portrait
var choice_box: VBoxContainer
var hint_label: Label
var _fx := TextFX.Pop.new()
var _spk := ""
var _voice_i := -1

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://data/dialogue/speakers.json", FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			speakers = parsed
	_build_ui()
	root.visible = false

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	cinematic_art = TextureRect.new()
	cinematic_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinematic_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cinematic_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cinematic_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_art.visible = false
	root.add_child(cinematic_art)
	cinematic_dim = ColorRect.new()
	cinematic_dim.color = Color(0.01, 0.0, 0.025, 0.18)
	cinematic_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cinematic_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cinematic_dim.visible = false
	root.add_child(cinematic_dim)
	letterbox_top = ColorRect.new()
	letterbox_top.color = Color(0, 0, 0, 0.92)
	letterbox_top.anchor_right = 1.0
	letterbox_top.offset_bottom = 42
	letterbox_top.visible = false
	root.add_child(letterbox_top)
	letterbox_bottom = ColorRect.new()
	letterbox_bottom.color = Color(0, 0, 0, 0.92)
	letterbox_bottom.anchor_top = 1.0
	letterbox_bottom.anchor_right = 1.0
	letterbox_bottom.anchor_bottom = 1.0
	letterbox_bottom.offset_top = -42
	letterbox_bottom.visible = false
	root.add_child(letterbox_bottom)
	box = PanelContainer.new()
	box.anchor_left = 0.08
	box.anchor_right = 0.92
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_top = -170
	box.offset_bottom = -24
	root.add_child(box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	box.add_child(hb)
	portrait = Portrait.new()
	portrait.custom_minimum_size = Vector2(124, 124)
	hb.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	name_label = UIStyle.label("", 18, UIStyle.PINK, true)
	vb.add_child(name_label)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.add_theme_font_override("normal_font", UIStyle.font_mono())
	text_label.add_theme_font_size_override("normal_font_size", 18)
	text_label.add_theme_color_override("default_color", UIStyle.PAPER)
	text_label.install_effect(_fx)
	vb.add_child(text_label)
	choice_box = VBoxContainer.new()
	vb.add_child(choice_box)
	hint_label = UIStyle.label("▶", 14, UIStyle.GOLD)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(hint_label)

func load_dialogue(id: String) -> Dictionary:
	var path := "res://data/dialogue/%s.json" % id
	if not FileAccess.file_exists(path):
		push_warning("Dialogue missing: " + id)
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

## Start a conversation. pause_game=false lets gameplay continue (barks, phone calls).
func start(id: String, pause_game := true) -> void:
	_data = load_dialogue(id)
	if _data.is_empty():
		finished.emit(id)
		return
	_id = id
	_pause_game = pause_game
	_apply_reading_settings()
	var art_tex := CinematicArt.cutscene_texture(id) if pause_game else null
	cinematic_art.texture = art_tex
	cinematic_art.material = CinematicArt.cutscene_material(id) if art_tex else null
	cinematic_art.visible = art_tex != null
	cinematic_dim.visible = art_tex != null
	# in-level scenes get cinema bars; story cutscenes already frame
	# themselves (StoryShot letterbox + the VHS counter up top)
	var in_level := get_tree().get_first_node_in_group("level") != null
	letterbox_top.visible = pause_game and in_level
	letterbox_bottom.visible = pause_game and in_level
	active = true
	root.visible = true
	if _pause_game:
		get_tree().paused = true
	_input_block = 0.25
	_goto(str(_data.get("start", "a")))

## Text speed and size come from the accessibility settings.
const SPEEDS := [30.0, 55.0, 95.0, 100000.0]
const SIZES := [15, 18, 23]
var _cps := CPS

func _apply_reading_settings() -> void:
	_cps = SPEEDS[clampi(int(SaveManager.get_setting("text_speed", 1)), 0, SPEEDS.size() - 1)]
	var fs: int = SIZES[clampi(int(SaveManager.get_setting("subtitle_size", 1)), 0, SIZES.size() - 1)]
	text_label.add_theme_font_size_override("normal_font_size", fs)
	text_label.add_theme_font_size_override("italics_font_size", fs)
	name_label.add_theme_font_size_override("font_size", fs)

func _goto(node_id: String) -> void:
	var nodes: Dictionary = _data.get("nodes", {})
	if node_id == "" or not nodes.has(node_id):
		_end()
		return
	_node = nodes[node_id]
	# conditional redirect
	if _node.has("if") and not _check(str(_node["if"])):
		_goto(str(_node.get("else", _node.get("next", ""))))
		return
	for k in (_node.get("set", {}) as Dictionary).keys():
		SaveManager.set_flag(k, _node.set[k])
	if _node.has("sfx"):
		Audio.play(str(_node.sfx))
	if _node.has("event"):
		event.emit(str(_node.event))
	_cut_to(str(_node.get("shot", "")))
	var spk := str(_node.get("speaker", "narration"))
	var sd: Dictionary = speakers.get(spk, {"name": spk.to_upper(), "color": "f4f0e8"})
	name_label.text = tr(str(sd.get("name", "")))
	name_label.add_theme_color_override("font_color", Color.html("#" + str(sd.get("color", "f4f0e8"))))
	portrait.visible = spk != "narration"
	portrait.speaker = spk
	portrait.mood = str(_node.get("mood", _infer_mood(str(_node.get("text", "")))))
	_full = tr(str(_node.get("text", "")))
	# the whole line is laid out up front (the box sizes to it once) and the
	# Pop effect reveals it letter by letter
	var body := ("[i]" + _full + "[/i]") if spk == "narration" else _full
	text_label.text = "[pop]" + body + "[/pop]"
	text_label.visible_characters = -1
	_shown = 0.0
	_spk = spk
	_voice_i = -1
	_fx.shown = 0.0
	_fx.mood = _text_mood(spk, portrait.mood)
	_auto_t = float(_node.get("auto", -1.0))
	if not _pause_game and _auto_t < 0.0:
		_auto_t = 1.2 + _full.length() / 22.0
	for c in choice_box.get_children():
		c.queue_free()
	_choices = []
	for ch in _node.get("choices", []):
		if ch.has("if") and not _check(str(ch["if"])):
			continue
		_choices.append(ch)
	_choice_i = 0
	line_shown.emit(spk, _full)

## In a level, a line with a "shot" cuts the frame behind the box to that
## painting (animated, faded in with a touch of tape glitch). Story
## cutscenes run their own StoryShot, so this only acts inside a level.
func _cut_to(sid: String) -> void:
	if sid == "" or not _pause_game or get_tree().get_first_node_in_group("level") == null:
		return
	var rid := StoryShot.resolve(sid)
	var tex := StoryShot.painted_tex(rid)
	if tex == null or cinematic_art.texture == tex:
		return
	cinematic_art.texture = tex
	cinematic_art.material = StoryShot.painted_material(rid)
	cinematic_art.visible = true
	cinematic_dim.visible = true
	cinematic_art.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(cinematic_art, "modulate:a", 1.0, 0.35)
	PostFX.vhs_glitch(0.3)

## Lines without an explicit "mood" get a light guess from punctuation so
## portraits react even in dialogue written before moods existed.
func _infer_mood(text: String) -> String:
	var t := text.strip_edges()
	if t.ends_with("?!") or t.ends_with("!?"):
		return "shock"
	if t.ends_with("!") and t.length() < 60 and t.to_upper() == t:
		return "angry"
	if t.begins_with("..."):
		return "sad"
	return ""

## How the letters move for this line.
func _text_mood(spk: String, mood: String) -> String:
	if spk == "voice":
		return "phone"
	if spk == "narration":
		return "dream"
	if mood in ["angry", "scared", "shock", "sad"]:
		return mood
	return ""

## Still typing the current line out.
func is_typing() -> bool:
	return _shown < _full.length()

func _check(cond: String) -> bool:
	var neg := cond.begins_with("!")
	var flag := cond.trim_prefix("!")
	var v: bool = bool(SaveManager.get_flag(flag, false))
	return not v if neg else v

func _show_choices() -> void:
	if choice_box.get_child_count() > 0 or _choices.is_empty():
		return
	for i in _choices.size():
		var b := Button.new()
		b.text = "  " + tr(str(_choices[i].text))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		var idx := i
		b.pressed.connect(func(): _pick(idx))
		b.focus_entered.connect(func():
			_choice_i = idx
			Audio.play("ui_move", -6.0))
		choice_box.add_child(b)
	(choice_box.get_child(0) as Button).grab_focus()

func _pick(i: int) -> void:
	if i < 0 or i >= _choices.size():
		return
	var ch: Dictionary = _choices[i]
	for k in (ch.get("set", {}) as Dictionary).keys():
		SaveManager.set_flag(k, ch.set[k])
	Audio.play("ui_select")
	_goto(str(ch.get("next", "")))

func _advance() -> void:
	if is_typing():
		_shown = _full.length()
		_fx.shown = _shown + TextFX.SETTLE
		return
	if not _choices.is_empty():
		return
	if _node.has("branch"):
		for b in _node.branch:
			if not b.has("if") or _check(str(b["if"])):
				_goto(str(b.get("next", "")))
				return
		_end()
		return
	_goto(str(_node.get("next", "")))

func _end() -> void:
	active = false
	root.visible = false
	cinematic_art.texture = null
	cinematic_art.visible = false
	cinematic_dim.visible = false
	letterbox_top.visible = false
	letterbox_bottom.visible = false
	for c in choice_box.get_children():
		c.queue_free()
	if _pause_game:
		get_tree().paused = false
	var id := _id
	_id = ""
	finished.emit(id)

const BOX_MIN_H := 146.0
const BOX_BOTTOM := 24.0

func _process(delta: float) -> void:
	if not active:
		return
	# the box grows upward to fit long lines (Portuguese, large text) instead
	# of letting text spill out of it
	var need := box.get_combined_minimum_size().y
	box.offset_top = -BOX_BOTTOM - maxf(BOX_MIN_H, need)
	var real := delta / maxf(Engine.time_scale, 0.03) if not get_tree().paused else delta
	_input_block = maxf(0.0, _input_block - real)
	_fx.clock += real
	if is_typing():
		# a beat on punctuation, like someone drawing breath
		var at := clampi(int(_shown), 0, _full.length() - 1)
		var slow := 0.25 if _full[at] in [".", "!", "?", "…"] else (0.5 if _full[at] == "," else 1.0)
		_shown = minf(_shown + real * _cps * slow, _full.length())
		_fx.shown = _shown
		portrait.talking = true
		_speak(int(_shown))
	else:
		_fx.shown = _full.length() + TextFX.SETTLE

		portrait.talking = false
		_show_choices()
		hint_label.visible = _choices.is_empty() and _pause_game
		if _auto_t >= 0.0 and _choices.is_empty():
			_auto_t -= real
			if _auto_t <= 0.0:
				_advance()

## Babble: one grain every other spoken letter (the vowel follows the text),
## narration gets a typewriter key instead.
func _speak(i: int) -> void:
	if i == _voice_i or not TextFX.speaks(_full, i):
		return
	_voice_i = i
	if i % 2 == 1:
		return
	if _spk == "narration":
		Audio.play("type_clack", -16.0, randf_range(0.9, 1.1))
		return
	var base := float(speakers.get(_spk, {}).get("pitch", 1.0))
	Audio.play(TextFX.voice_grain(_spk, _full, i), -9.0, TextFX.voice_pitch(base, _full, i))

func _unhandled_input(e: InputEvent) -> void:
	if not active or not _pause_game or _input_block > 0.0:
		return
	if not _choices.is_empty() and not is_typing():
		return   # buttons handle it
	var pressed := (e.is_action_pressed("ui_confirm") or e.is_action_pressed("fire") or e.is_action_pressed("interact") or e.is_action_pressed("ui_accept"))
	if pressed:
		get_viewport().set_input_as_handled()
		_advance()
