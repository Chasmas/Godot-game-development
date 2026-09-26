class_name OptionsMenu
extends PanelContainer
## Settings: audio, video, gameplay (difficulty, language), accessibility and
## full control remapping (keyboard/mouse and gamepad). Everything saves
## immediately. The whole menu rebuilds itself when the language changes, so
## every label, tab and dropdown switches on the spot (and longer Portuguese
## labels get room: rows wrap instead of clipping).

signal closed

const ROW_LABEL_W := 300.0

var tabs: TabContainer
var _waiting_action := ""
var _waiting_pad := false
var _waiting_button: Button
var _bind_buttons: Dictionary = {}
var _status: Label
var _help: Label
var _status_t := 0.0
var _root: VBoxContainer
var _t := 0.0

## Short explanation shown at the bottom for whatever is focused.
const HELP := {
	"Difficulty": "Takes effect on the next mission start or restart.",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIStyle.theme()
	custom_minimum_size = Vector2(760, 470)
	UIStyle.place(self, Control.PRESET_CENTER, -custom_minimum_size * 0.5, custom_minimum_size)
	Events.settings_changed.connect(_on_changed)
	Loc.language_changed.connect(func(_l): _rebuild.call_deferred())
	_build(0)
	# slide + fade in
	modulate.a = 0.0
	position.y += 24.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_property(self, "position:y", position.y - 24.0, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _build(tab_index: int) -> void:
	if _root:
		_root.queue_free()
	_bind_buttons.clear()
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 6)
	add_child(_root)
	var title := UIStyle.title_label("OPTIONS", 34)
	_root.add_child(title)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(720, 330)
	_root.add_child(tabs)
	_audio_tab()
	_video_tab()
	_gameplay_tab()
	_access_tab()
	_controls_tab()
	for i in tabs.get_tab_count():
		tabs.set_tab_title(i, tr(tabs.get_tab_control(i).name))
	tabs.current_tab = clampi(tab_index, 0, tabs.get_tab_count() - 1)
	_help = UIStyle.label("", 13, UIStyle.CYAN)
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(720, 18)
	_root.add_child(_help)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	_root.add_child(bar)
	var apply := Button.new()
	apply.text = "APPLY & SAVE"
	apply.pressed.connect(_apply_and_save)
	bar.add_child(apply)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_close)
	bar.add_child(back)
	# controller hints / "saved" confirmation on their own line so a longer
	# translation never gets clipped
	_status = UIStyle.label("LB / RB  change tab   ·   A  select   ·   B  back", 12, UIStyle.DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_status)
	tabs.tab_changed.connect(func(_i):
		Audio.play("ui_move", -8.0)
		_focus_first.call_deferred())
	_focus_first.call_deferred()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	_build(tabs.current_tab if tabs else 0)

func _on_changed() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	_status.text = tr("✓ SAVED")
	_status.add_theme_color_override("font_color", UIStyle.GOLD)
	_status_t = 1.5

func _process(delta: float) -> void:
	_t += delta
	if _status_t > 0.0:
		_status_t -= delta
		if _status_t <= 0.0 and _status and is_instance_valid(_status):
			_status.text = tr("LB / RB  change tab   ·   A  select   ·   B  back")
			_status.add_theme_color_override("font_color", UIStyle.DIM)

func _apply_and_save() -> void:
	SaveManager.apply_video_settings()
	SaveManager.save_settings()
	Events.settings_changed.emit()
	InputSetup.rebuild()
	Audio.play("ui_select")

## Focus the first interactive control on the current tab (controller-friendly).
func _focus_first() -> void:
	if tabs == null or not is_instance_valid(tabs):
		return
	var page := tabs.get_current_tab_control()
	if page == null:
		return
	var stack: Array = [page]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n is Control and n != page and (n as Control).focus_mode == Control.FOCUS_ALL and (n as Control).is_visible_in_tree():
			(n as Control).grab_focus()
			return
		stack.append_array(n.get_children())

func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	return vb

## A labelled row. The label lights up while its control has focus, and the
## help line explains the setting.
func _row(parent: Control, text: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l := UIStyle.label(text, 16)
	l.custom_minimum_size = Vector2(ROW_LABEL_W, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(l)
	parent.add_child(hb)
	var help_text: String = HELP.get(text, "")
	hb.child_entered_tree.connect(func(c: Node):
		if c is Control and c != l:
			(c as Control).focus_entered.connect(func():
				l.add_theme_color_override("font_color", UIStyle.GOLD)
				if _help and is_instance_valid(_help):
					_help.text = tr(help_text) if help_text != "" else "")
			(c as Control).focus_exited.connect(func(): l.add_theme_color_override("font_color", UIStyle.PAPER)))
	return hb

func _slider(parent: Control, text: String, key: String, lo := 0.0, hi := 1.0, step := 0.05) -> void:
	var hb := _row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(SaveManager.get_setting(key, 1.0))
	s.custom_minimum_size = Vector2(260, 20)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := UIStyle.label("%d%%" % int(s.value / hi * 100.0), 14, UIStyle.GOLD)
	s.value_changed.connect(func(v):
		SaveManager.set_setting(key, v)
		val.text = "%d%%" % int(v / hi * 100.0)
		Audio.play("ui_move", -12.0))
	hb.add_child(s)
	hb.add_child(val)

func _toggle(parent: Control, text: String, key: String, fallback := false) -> void:
	var hb := _row(parent, text)
	var c := CheckButton.new()
	c.button_pressed = bool(SaveManager.get_setting(key, fallback))
	c.toggled.connect(func(v):
		SaveManager.set_setting(key, v)
		Audio.play("ui_select", -8.0))
	hb.add_child(c)

func _choice(parent: Control, text: String, key: String, options: Array, fallback := 0) -> OptionButton:
	var hb := _row(parent, text)
	var o := OptionButton.new()
	for i in options.size():
		o.add_item(tr(str(options[i])), i)
	o.selected = clampi(int(SaveManager.get_setting(key, fallback)), 0, options.size() - 1)
	o.item_selected.connect(func(i):
		SaveManager.set_setting(key, i)
		Audio.play("ui_select", -8.0))
	hb.add_child(o)
	return o

## Difficulty picker with a description of what it changes.
func _difficulty(parent: Control) -> void:
	var hb := _row(parent, "Difficulty")
	var o := OptionButton.new()
	for i in Difficulty.NAMES.size():
		o.add_item(tr(Difficulty.NAMES[i]), i)
	o.selected = Difficulty.current()
	hb.add_child(o)
	var desc := UIStyle.label(tr(Difficulty.DESCRIPTIONS[Difficulty.current()]), 13, UIStyle.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(680, 0)
	parent.add_child(desc)
	o.item_selected.connect(func(i):
		SaveManager.set_setting("difficulty", i)
		desc.text = tr(Difficulty.DESCRIPTIONS[i])
		Audio.play("ui_select", -8.0))

## Language picker: each language is named in its own language.
func _language(parent: Control) -> void:
	var hb := _row(parent, "Language")
	var o := OptionButton.new()
	var locales: Array = Loc.LANGUAGES.keys()
	for i in locales.size():
		o.add_item(str(Loc.LANGUAGES[locales[i]]), i)
		o.set_item_metadata(i, locales[i])
	o.selected = maxi(0, locales.find(Loc.current()))
	o.item_selected.connect(func(i):
		Audio.play("ui_select", -8.0)
		Loc.apply(str(o.get_item_metadata(i))))
	hb.add_child(o)

func _audio_tab() -> void:
	var p := _page("AUDIO")
	_slider(p, "Master volume", "master_volume")
	_slider(p, "Music", "music_volume")
	_slider(p, "Sound effects", "sfx_volume")
	_slider(p, "Dialogue", "dialogue_volume")

func _video_tab() -> void:
	var p := _page("VIDEO")
	_toggle(p, "Fullscreen", "fullscreen")
	_toggle(p, "VSync", "vsync", true)
	_toggle(p, "CRT / VHS effect", "crt", true)
	_toggle(p, "Chromatic aberration", "chromatic", true)
	_toggle(p, "Neon glow (bloom)", "bloom", true)
	_toggle(p, "Cel-shaded finish", "cel_shading", true)
	_toggle(p, "Weather (rain, storms)", "weather", true)
	_toggle(p, "Set dressing (room clutter)", "set_dressing", true)
	_slider(p, "Brightness", "brightness", 0.6, 1.4, 0.05)
	_toggle(p, "Show FPS", "show_fps")
	_choice(p, "Window size", "window_size", ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440"], 1)

func _gameplay_tab() -> void:
	var p := _page("GAMEPLAY")
	_difficulty(p)
	_language(p)
	_slider(p, "Screen shake", "screen_shake", 0.0, 1.5, 0.05)
	_choice(p, "Gore", "gore", ["Off (ink)", "Reduced", "Full"], 2)
	_slider(p, "Aim assist", "aim_assist")
	_toggle(p, "Lock-on: auto-switch to next target", "lock_auto_next", true)
	_toggle(p, "Controller vibration", "vibration", true)

func _access_tab() -> void:
	var p := _page("ACCESS")
	_toggle(p, "Subtitles", "subtitles", true)
	_choice(p, "Subtitle size", "subtitle_size", ["Small", "Medium", "Large"], 1)
	_choice(p, "Text speed", "text_speed", ["Slow", "Normal", "Fast", "Instant"], 1)
	_choice(p, "Colour-blind filter", "colorblind", ["Off", "Protanopia", "Deuteranopia", "Tritanopia"])
	_toggle(p, "Reduced flashing", "reduced_flashing")
	_slider(p, "UI scale", "ui_scale", 0.75, 1.5, 0.05)
	var note := UIStyle.label("Screen shake and aim assist are under GAMEPLAY.\nAll controls can be remapped under CONTROLS.", 13, UIStyle.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(680, 0)
	p.add_child(note)

func _controls_tab() -> void:
	var p := _page("CONTROLS")
	var head := HBoxContainer.new()
	var l0 := UIStyle.label("ACTION", 14, UIStyle.DIM, true)
	l0.custom_minimum_size = Vector2(240, 0)
	head.add_child(l0)
	var l1 := UIStyle.label("KEYBOARD / MOUSE", 14, UIStyle.DIM, true)
	l1.custom_minimum_size = Vector2(210, 0)
	head.add_child(l1)
	head.add_child(UIStyle.label("GAMEPAD", 14, UIStyle.DIM, true))
	p.add_child(head)
	for action in InputSetup.REMAPPABLE:
		var hb := HBoxContainer.new()
		var name_l := UIStyle.label(str(InputSetup.ACTIONS[action][0]), 15)
		name_l.custom_minimum_size = Vector2(240, 0)
		name_l.clip_text = true
		hb.add_child(name_l)
		for pad in [false, true]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(210 if not pad else 150, 0)
			b.text = InputSetup.binding_text(action, pad)
			b.add_theme_font_size_override("font_size", 14)
			var a: String = action
			var is_pad: bool = pad
			b.pressed.connect(func(): _begin_rebind(a, is_pad, b))
			hb.add_child(b)
			_bind_buttons[a + ("_pad" if pad else "_kb")] = b
		p.add_child(hb)
	var reset := Button.new()
	reset.text = "RESET TO DEFAULTS"
	reset.pressed.connect(func():
		InputSetup.reset_bindings()
		_refresh_bindings())
	p.add_child(reset)

func _begin_rebind(action: String, pad: bool, b: Button) -> void:
	_waiting_action = action
	_waiting_pad = pad
	_waiting_button = b
	b.text = tr("PRESS A %s...") % tr("BUTTON" if pad else "KEY")
	Audio.play("ui_select", -6.0)

func _refresh_bindings() -> void:
	for k in _bind_buttons.keys():
		var pad: bool = k.ends_with("_pad")
		var action: String = k.trim_suffix("_pad").trim_suffix("_kb")
		(_bind_buttons[k] as Button).text = InputSetup.binding_text(action, pad)

func _input(e: InputEvent) -> void:
	if _waiting_action == "":
		if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			_close()
		elif (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_RIGHT_SHOULDER) or (e is InputEventKey and e.pressed and e.keycode == KEY_E):
			get_viewport().set_input_as_handled()
			tabs.current_tab = (tabs.current_tab + 1) % tabs.get_tab_count()
		elif (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_LEFT_SHOULDER) or (e is InputEventKey and e.pressed and e.keycode == KEY_Q):
			get_viewport().set_input_as_handled()
			tabs.current_tab = (tabs.current_tab - 1 + tabs.get_tab_count()) % tabs.get_tab_count()
		return
	var is_pad := e is InputEventJoypadButton or (e is InputEventJoypadMotion and absf((e as InputEventJoypadMotion).axis_value) > 0.6)
	var is_kb := e is InputEventKey or e is InputEventMouseButton
	if not e.is_pressed() and not e is InputEventJoypadMotion:
		return
	if (_waiting_pad and is_pad) or (not _waiting_pad and is_kb):
		get_viewport().set_input_as_handled()
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_ESCAPE and _waiting_action != "pause":
			_waiting_action = ""
			_refresh_bindings()
			return
		InputSetup.remap(_waiting_action, e)
		_waiting_action = ""
		Audio.play("ui_select")
		_refresh_bindings()

var _closing := false

func _close() -> void:
	if _closing:
		return
	_closing = true
	Audio.play("ui_back")
	closed.emit()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_property(self, "position:y", position.y + 16.0, 0.1)
	tw.chain().tween_callback(queue_free)
