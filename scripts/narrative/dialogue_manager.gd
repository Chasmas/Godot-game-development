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
var _line_voice: AudioStreamPlayer
var _has_authored_voice := false
var _silent_line := false
var _speech_words := RegEx.create_from_string("[\\p{L}\\p{N}]")

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
	_line_voice = AudioStreamPlayer.new()
	_line_voice.bus = "Dialogue"
	_line_voice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_line_voice)
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
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.03, 0.015, 0.06, 0.94)
	bsb.border_color = Color(UIStyle.PINK, 0.85)
	bsb.border_width_top = 2
	bsb.border_width_bottom = 1
	bsb.shadow_color = Color(0, 0, 0, 0.45)
	bsb.shadow_size = 10
	bsb.shadow_offset = Vector2(0, 6)
	bsb.content_margin_left = 20
	bsb.content_margin_right = 22
	bsb.content_margin_top = 16
	bsb.content_margin_bottom = 12
	box.add_theme_stylebox_override("panel", bsb)
	root.add_child(box)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	box.add_child(hb)
	portrait = Portrait.new()
	portrait.custom_minimum_size = Vector2(124, 124)
	hb.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	name_label = UIStyle.label("", 18, UIStyle.PINK, true)
	# the speaker's name on a tape-label tab in their own colour
	_name_sb = StyleBoxFlat.new()
	_name_sb.bg_color = UIStyle.PINK
	_name_sb.content_margin_left = 10
	_name_sb.content_margin_right = 12
	_name_sb.content_margin_top = 1
	_name_sb.content_margin_bottom = 1
	_name_sb.skew = Vector2(-0.18, 0)
	name_label.add_theme_stylebox_override("normal", _name_sb)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	_frame = BoxFrame.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_frame)

var _name_sb: StyleBoxFlat
var _frame: Control
var _open_t := 1.0

## Over the box: corner ticks, faint scanlines, and on opening a bright
## line sweeping down it like a tape head finding the picture.
class BoxFrame extends Control:
	var k := 1.0     ## 0 -> 1 as the box opens
	var t := 0.0
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		for y in range(4, int(size.y), 3):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.018), 1.0)
		var c := Color(UIStyle.CYAN, 0.7)
		var L := 14.0
		for p in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
			var o: Vector2 = p[0] + (p[1] as Vector2) * 4.0
			draw_line(o, o + Vector2((p[1] as Vector2).x * L, 0), c, 1.5)
			draw_line(o, o + Vector2(0, (p[1] as Vector2).y * L), c, 1.5)
		if k < 1.0:
			var y := size.y * k
			draw_rect(Rect2(0, y - 2, size.x, 3), Color(1, 0.85, 0.95, 0.7 * (1.0 - k)))
			draw_rect(Rect2(0, y, size.x, size.y - y), Color(0.03, 0.015, 0.06, 0.95))

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
	# a story cutscene with its own StoryShot sequence cuts frame by frame
	# underneath; one fixed key art over the top would hide every cut
	var own_shots := StoryShot.has_shot(str(_data.get("shot", "")))
	var art_tex := CinematicArt.cutscene_texture(id) if pause_game and not own_shots else null
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
	if not root.visible:
		_open_t = 0.0
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
	_play_authored_voice(node_id)
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
	var scol := Color.html("#" + str(sd.get("color", "f4f0e8")))
	_name_sb.bg_color = scol
	name_label.add_theme_color_override("font_color", UIStyle.INK if scol.get_luminance() > 0.35 else UIStyle.PAPER)
	name_label.visible = spk != "narration" and name_label.text != ""
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

## Optional human performance generated with ElevenLabs. The file is only
## played when an authored line exists; otherwise the familiar per-letter
## timbre remains active. This keeps generation opt-in and separate from music.
func _play_authored_voice(node_id: String) -> void:
	# A new line must never display the previous performance's open mouth.
	if portrait != null:
		portrait.reset_speech()
	_has_authored_voice = false
	_silent_line = _speech_words.search(str(_node.get("text", ""))) == null
	if _line_voice == null:
		return
	_line_voice.stop()
	_line_voice.stream = null
	if _silent_line:
		return
	var explicit := str(_node.get("voice", ""))
	var base := explicit if explicit.begins_with("res://") else "res://assets/audio/voice/%s/%s" % [_id, node_id]
	if explicit.begins_with("res://"):
		var stream := load(explicit) as AudioStream
		if stream:
			_has_authored_voice = true
			_line_voice.stream = stream
			_line_voice.volume_db = float(_node.get("voice_db", -1.5))
			_line_voice.play()
		return
	for ext in [".ogg", ".wav", ".mp3"]:
		var p: String = base + str(ext)
		if ResourceLoader.exists(p):
			_has_authored_voice = true
			_line_voice.stream = load(p) as AudioStream
			_line_voice.volume_db = float(_node.get("voice_db", -1.5))
			_line_voice.play()
			return

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

## Speech follows the recording, which may end before or after the text.
func is_speaking(speaker := "") -> bool:
	if not active or (speaker != "" and _spk != speaker):
		return false
	if _has_authored_voice:
		return _line_voice != null and _line_voice.playing
	return is_typing() and not _silent_line

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

func _end(emit_finished := true) -> void:
	if _line_voice:
		_line_voice.stop()
		_line_voice.stream = null
	if portrait:
		portrait.talking = false
		portrait.speech_energy = 0.0
		portrait._mouth = 0
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
	if emit_finished:
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
	# opening: the box rises a little and the tape head sweeps down it
	_open_t = minf(1.0, _open_t + real / 0.22)
	var e := 1.0 - pow(1.0 - _open_t, 3.0)
	box.modulate.a = clampf(_open_t * 2.0, 0.0, 1.0)
	box.offset_bottom = -BOX_BOTTOM + (1.0 - e) * 18.0
	box.offset_top += (1.0 - e) * 18.0
	(_frame as BoxFrame).k = e
	(_frame as BoxFrame).t += real
	_frame.queue_redraw()
	hint_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	_fx.clock += real
	portrait.speech_energy = -1.0
	if _has_authored_voice and _line_voice != null:
		if _line_voice.playing and _line_voice.stream != null:
			# Follow audible output, rather than the last mixer block's cursor.
			# This matches the latency correction used by the music beat clock.
			var audible_time := maxf(0.0,_line_voice.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
			portrait.speech_energy = VoiceEnvelope.sample(_line_voice.stream.resource_path, audible_time)
		else:
			portrait.speech_energy = 0.0
	if is_typing():
		# a beat on punctuation, like someone drawing breath
		var at := clampi(int(_shown), 0, _full.length() - 1)
		var slow := 0.25 if _full[at] in [".", "!", "?", "…"] else (0.5 if _full[at] == "," else 1.0)
		_shown = minf(_shown + real * _cps * slow, _full.length())
		_fx.shown = _shown
		portrait.talking = (_line_voice != null and _line_voice.playing) if _has_authored_voice else not _silent_line
		_speak(int(_shown))
	else:
		_fx.shown = _full.length() + TextFX.SETTLE
		portrait.talking = _line_voice != null and _line_voice.playing
		_show_choices()
		hint_label.visible = _choices.is_empty() and _pause_game
		if _auto_t >= 0.0 and _choices.is_empty():
			_auto_t -= real
			if _auto_t <= 0.0 and not (_line_voice != null and _line_voice.playing):
				_advance()
	# Human performances can outlive the typewriter. Keep lip, blink and
	# portrait motion alive until the recorded line actually ends.
	if _line_voice != null and _line_voice.playing:
		portrait.talking = true

## Babble: one grain every other spoken letter (the vowel follows the text),
## narration gets a typewriter key instead.
func _speak(i: int) -> void:
	# Authored ElevenLabs performances replace the procedural letter grains.
	# Keeping both layers active creates the garbled, doubled voice heard
	# underneath the clean recording.
	if _has_authored_voice or _silent_line:
		return
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
		_input_block = 0.12
		_advance()
