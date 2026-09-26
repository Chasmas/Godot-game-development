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

func _btn(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Audio.play("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.play("ui_move", -8.0))
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

func _pause() -> void:
	root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.set_music_muffled(true)
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and level and level.player and level.player.alive and not get_tree().paused and not Dialogue.active:
		_pause()
