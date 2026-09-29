extends Node
## Controller regression test: gamepad on device 1 must drive gameplay AND menus.
func _ready():
	await get_tree().process_frame
	var ok := true
	var b := InputEventJoypadButton.new()
	b.device = 1
	b.button_index = JOY_BUTTON_A
	b.pressed = true
	Input.parse_input_event(b)
	await get_tree().process_frame
	print("dash(dev1)=", Input.is_action_pressed("dash"), " ui_accept(dev1)=", Input.is_action_pressed("ui_accept"))
	ok = ok and Input.is_action_pressed("dash") and Input.is_action_pressed("ui_accept")
	b.pressed = false
	Input.parse_input_event(b)
	# a focused button must fire on A
	var btn := Button.new()
	var fired := [false]
	btn.pressed.connect(func(): fired[0] = true)
	get_tree().root.add_child(btn)
	btn.grab_focus()
	await get_tree().process_frame
	b.pressed = true
	Input.parse_input_event(b)
	await get_tree().process_frame
	b.pressed = false
	Input.parse_input_event(b)
	await get_tree().process_frame
	print("button pressed by A: ", fired[0])
	ok = ok and fired[0]
	# options menu opens, B closes it, settings persist
	var om := OptionsMenu.new()
	get_tree().root.add_child(om)
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.set_setting("crt", false)
	var f := FileAccess.open(SaveManager.settings_path, FileAccess.READ)
	var saved: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	print("crt saved false: ", saved.crt == false)
	ok = ok and saved.crt == false
	SaveManager.set_setting("crt", true)
	var bb := InputEventJoypadButton.new()
	bb.device = 2
	bb.button_index = JOY_BUTTON_B
	bb.pressed = true
	Input.parse_input_event(bb)
	await get_tree().create_timer(0.3).timeout   # it fades out first
	print("options closed by B: ", not is_instance_valid(om) or om.is_queued_for_deletion())
	ok = ok and (not is_instance_valid(om) or om.is_queued_for_deletion())
	print("PAD TEST ", "PASS" if ok else "FAIL")
	get_tree().quit()
