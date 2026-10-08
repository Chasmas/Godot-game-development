extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var call := IntroCall.new()
	call.dialogue_id = "call_m01"
	add_child(call)
	call.set_process(false)
	call._pick_up()
	var scroll := InputEventMouseButton.new()
	scroll.button_index = MOUSE_BUTTON_WHEEL_DOWN
	scroll.pressed = true
	call._unhandled_input(scroll)
	check(call._state == "talk" and Dialogue.active, "mouse wheel does not hang up a spoken call")
	call._state = "talk"
	if not Dialogue.active: Dialogue.start("call_m01", false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	call._unhandled_input(click)
	check(call._state == "hangup" and not Dialogue.active, "left click dismisses the active call")
	check(not Dialogue._line_voice.playing and Dialogue._line_voice.stream == null, "dismissal stops and releases the voice")
	call.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("INTRO CALL INPUT REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
