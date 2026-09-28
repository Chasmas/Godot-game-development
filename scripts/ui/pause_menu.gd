class_name PauseMenu
extends CanvasLayer
## Pause: resume, restart from checkpoint, restart mission, options, quit.

var level: Node
var root: Control
var menu: VBoxContainer
var _options: OptionsMenu

func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	root.visible = false
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.01, 0.08, 0.75)
	root.add_child(shade)
	var osd := UIStyle.label("❚❚ PAUSE", 28, UIStyle.PAPER, true)
	osd.position = Vector2(40, 30)
	root.add_child(osd)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 6)
	UIStyle.place(menu, Control.PRESET_CENTER_LEFT, Vector2(60, -110))
	root.add_child(menu)
	_btn("RESUME", _resume)
	_btn("RESTART FROM CHECKPOINT", func():
		_resume()
		Game.restart_level())
	_btn("RESTART MISSION", func():
		_resume()
		Game.start_mission(String(Game.current_mission.id), String(Game.current_character.id)))
	_btn("OPTIONS", _open_options)
	_btn("QUIT TO TITLE", func():
		_resume()
		Game.goto_title())
	# right side: where you are and what you're doing
	_info = UIStyle.label("", 15, UIStyle.DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIStyle.place(_info, Control.PRESET_CENTER_RIGHT, Vector2(-460, -120), Vector2(420, 260))
	root.add_child(_info)
	_shade = shade

func _btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Audio.play("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", -8.0))
	UIStyle.menu_fx(b)
	menu.add_child(b)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		if _options:
			return
		if root.visible:
			_resume()
		elif not get_tree().paused and level and level.player and level.player.alive and not Dialogue.active:
			_pause()
		get_viewport().set_input_as_handled()

var _info: Label
var _shade: ColorRect

func _pause() -> void:
	root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.set_music_muffled(true)
	Audio.play("ui_back", -6.0, 0.8)
	if level and _info:
		var m: MissionData = level.mission
		_info.text = "%s\n%s\n\n%s\n\n%s: %s" % [tr(m.title), tr(m.location), level.hud.objective_label.text if level.hud else "",
			tr("Difficulty"), tr(Difficulty.NAMES[Difficulty.current()])]
	# backdrop fades, menu slides in from the left
	_shade.modulate.a = 0.0
	menu.modulate.a = 0.0
	var x0 := menu.position.x
	menu.position.x = x0 - 40.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_shade, "modulate:a", 1.0, 0.12)
	tw.tween_property(menu, "modulate:a", 1.0, 0.14)
	tw.tween_property(menu, "position:x", x0, 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	(menu.get_child(0) as Button).grab_focus()

func _resume() -> void:
	root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Audio.set_music_muffled(false)

func _open_options() -> void:
	menu.visible = false
	_options = OptionsMenu.new()
	root.add_child(_options)
	_options.closed.connect(func():
		_options = null
		menu.visible = true
		(menu.get_child(3) as Button).grab_focus())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not Engine.has_meta("autoplay") and level and level.player and level.player.alive and not get_tree().paused and not Dialogue.active:
		_pause()
