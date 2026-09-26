class_name OptionsMenu
extends PanelContainer
## Settings: audio, video, gameplay, accessibility and full control remapping
## (keyboard/mouse and gamepad). Everything saves immediately.

signal closed

var tabs: TabContainer
var _waiting_action := ""
var _waiting_pad := false
var _waiting_button: Button
var _bind_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIStyle.theme()
	custom_minimum_size = Vector2(700, 440)
	UIStyle.place(self, Control.PRESET_CENTER, -custom_minimum_size * 0.5, custom_minimum_size)
	var vb := VBoxContainer.new()
	add_child(vb)
	var title := UIStyle.title_label("OPTIONS", 34)
	vb.add_child(title)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(660, 330)
	vb.add_child(tabs)
	_audio_tab()
	_video_tab()
	_gameplay_tab()
	_access_tab()
	_controls_tab()
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	vb.add_child(bar)
	var apply := Button.new()
	apply.text = "APPLY & SAVE"
	apply.pressed.connect(_apply_and_save)
	bar.add_child(apply)
	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_close)
	bar.add_child(back)
	_status = UIStyle.label("LB / RB  change tab   ·   A  select   ·   B  back", 12, UIStyle.DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar.add_child(_status)
	tabs.tab_changed.connect(func(_i): _focus_first.call_deferred())
	Events.settings_changed.connect(_on_changed)
	await get_tree().process_frame
	_focus_first()

var _status: Label
var _status_t := 0.0

func _on_changed() -> void:
	_status.text = "✓ SAVED"
	_status.add_theme_color_override("font_color", UIStyle.GOLD)
	_status_t = 1.5

func _process(delta: float) -> void:
	if _status_t > 0.0:
		_status_t -= delta
		if _status_t <= 0.0:
			_status.text = "LB / RB  change tab   ·   A  select   ·   B  back"
			_status.add_theme_color_override("font_color", UIStyle.DIM)

func _apply_and_save() -> void:
	SaveManager.apply_video_settings()
	SaveManager.save_settings()
	Events.settings_changed.emit()
	InputSetup.rebuild()
	Audio.play("ui_select")

## Focus the first interactive control on the current tab (controller-friendly).
func _focus_first() -> void:
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

func _row(parent: Control, text: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var l := UIStyle.label(text, 16)
	l.custom_minimum_size = Vector2(260, 0)
	hb.add_child(l)
	parent.add_child(hb)
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

func _toggle(parent: Control, text: String, key: String) -> void:
	var hb := _row(parent, text)
	var c := CheckButton.new()
	c.button_pressed = bool(SaveManager.get_setting(key, false))
	c.toggled.connect(func(v):
		SaveManager.set_setting(key, v)
		Audio.play("ui_select", -8.0))
	hb.add_child(c)

func _choice(parent: Control, text: String, key: String, options: Array) -> void:
	var hb := _row(parent, text)
	var o := OptionButton.new()
	for i in options.size():
		o.add_item(str(options[i]), i)
	o.selected = int(SaveManager.get_setting(key, 0))
	o.item_selected.connect(func(i):
		SaveManager.set_setting(key, i)
		Audio.play("ui_select", -8.0))
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
	_toggle(p, "VSync", "vsync")
	_toggle(p, "CRT / VHS effect", "crt")
	_toggle(p, "Chromatic aberration", "chromatic")
	_toggle(p, "Neon glow (bloom)", "bloom")
	_toggle(p, "Cel-shaded finish", "cel_shading")
	_toggle(p, "Weather (rain, storms)", "weather")
	_slider(p, "Brightness", "brightness", 0.6, 1.4, 0.05)
	_toggle(p, "Show FPS", "show_fps")
	_choice(p, "Window size", "window_size", ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440"])

func _gameplay_tab() -> void:
	var p := _page("GAMEPLAY")
	_slider(p, "Screen shake", "screen_shake", 0.0, 1.5, 0.05)
	_choice(p, "Gore", "gore", ["Off (ink)", "Reduced", "Full"])
	_slider(p, "Aim assist", "aim_assist")
	_toggle(p, "Lock-on: auto-switch to next target", "lock_auto_next")
	_toggle(p, "Controller vibration", "vibration")
	_toggle(p, "Subtitles", "subtitles")
	_choice(p, "Language", "language_idx", ["English"])

func _access_tab() -> void:
	var p := _page("ACCESS")
	_choice(p, "Colour-blind filter", "colorblind", ["Off", "Protanopia", "Deuteranopia", "Tritanopia"])
	_toggle(p, "Reduced flashing", "reduced_flashing")
	_slider(p, "UI scale", "ui_scale", 0.75, 1.5, 0.05)
	p.add_child(UIStyle.label("Screen shake and aim assist are under GAMEPLAY.\nAll controls can be remapped under CONTROLS.", 13, UIStyle.DIM))

func _controls_tab() -> void:
	var p := _page("CONTROLS")
	var head := HBoxContainer.new()
	var l0 := UIStyle.label("ACTION", 14, UIStyle.DIM, true)
	l0.custom_minimum_size = Vector2(220, 0)
	head.add_child(l0)
	var l1 := UIStyle.label("KEYBOARD / MOUSE", 14, UIStyle.DIM, true)
	l1.custom_minimum_size = Vector2(200, 0)
	head.add_child(l1)
	head.add_child(UIStyle.label("GAMEPAD", 14, UIStyle.DIM, true))
	p.add_child(head)
	for action in InputSetup.REMAPPABLE:
		var hb := HBoxContainer.new()
		var name_l := UIStyle.label(str(InputSetup.ACTIONS[action][0]), 15)
		name_l.custom_minimum_size = Vector2(220, 0)
		hb.add_child(name_l)
		for pad in [false, true]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(200 if not pad else 150, 0)
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
	b.text = "PRESS A %s..." % ("BUTTON" if pad else "KEY")
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
			Audio.play("ui_move", -8.0)
		elif (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_LEFT_SHOULDER) or (e is InputEventKey and e.pressed and e.keycode == KEY_Q):
			get_viewport().set_input_as_handled()
			tabs.current_tab = (tabs.current_tab - 1 + tabs.get_tab_count()) % tabs.get_tab_count()
			Audio.play("ui_move", -8.0)
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

func _close() -> void:
	Audio.play("ui_back")
	closed.emit()
	queue_free()
