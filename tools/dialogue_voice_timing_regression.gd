extends Node

func _ready() -> void:
	var scene_id := OS.get_environment("VOICE_TEST_SCENE")
	Dialogue.start(scene_id if scene_id != "" else "call_m01", false)
	Dialogue.set_process(false)
	var failures := 0
	var words := RegEx.create_from_string("[\\p{L}\\p{N}]")
	for node_id in Dialogue._data.nodes:
		var node: Dictionary = Dialogue._data.nodes[node_id]
		if node.get("speaker", "narration") != "narration" and words.search(str(node.get("text", ""))) != null:
			Dialogue._goto(node_id)
			break
	if not Dialogue._has_authored_voice:
		push_error("Timing test requires a recorded voice")
		get_tree().quit(1)
		return
	Dialogue._line_voice.stop()
	var call := IntroCall.new()
	call.dialogue_id = Dialogue._id
	call.caller = Dialogue._spk
	call._state = "talk"
	Dialogue._shown = 0.0
	Dialogue._process(0.01)
	if Dialogue.portrait.speech_energy != 0.0:
		failures += 1
		push_error("Stopped voice retains mouth energy")
	if call._caller_talking():
		failures += 1
		push_error("Caller panel animates speech after recording stops")
	if not Dialogue.is_typing() or Dialogue.portrait.talking:
		failures += 1
		push_error("Stopped recording animates lips while text types")
	Dialogue._line_voice.play()
	Dialogue._shown = Dialogue._full.length()
	Dialogue._process(0.01)
	if Dialogue.portrait.speech_energy < 0.0:
		failures += 1
		push_error("Recorded voice fails to resolve its measured envelope")
	if not call._caller_talking():
		failures += 1
		push_error("Caller panel stops before the recorded voice ends")
	call.caller = "different_speaker"
	if call._caller_talking():
		failures += 1
		push_error("Caller panel animates another character's reply")
	call.free()
	if not Dialogue.portrait.talking:
		failures += 1
		push_error("Text ending prematurely stops recorded speech lips")
	var current_text: String = Dialogue._node.text
	Dialogue._auto_t = 0.001
	Dialogue._process(0.01)
	if Dialogue._node.text != current_text:
		failures += 1
		push_error("Automatic advance cuts a playing recording")
	for node_id in Dialogue._data.nodes:
		var node: Dictionary = Dialogue._data.nodes[node_id]
		if node.get("speaker", "narration") != "narration" and words.search(str(node.get("text", ""))) == null:
			Dialogue._goto(node_id)
			Dialogue._process(0.01)
			if Dialogue.portrait.talking or Dialogue._line_voice.stream != null:
				failures += 1
				push_error("Punctuation-only pause plays speech or mouth animation")
		if node.get("speaker", "narration") == "narration" or words.search(str(node.get("text", ""))) == null:
			continue
		Dialogue._goto(node_id)
		if not Dialogue._has_authored_voice or Dialogue._line_voice.stream.get_length() <= 0.0:
			failures += 1
			push_error("Missing or undecodable recorded node: " + str(node_id))
	Dialogue._end()
	if Dialogue.portrait.talking or Dialogue.portrait.speech_energy != 0.0 or Dialogue.portrait._mouth != 0:
		failures += 1
		push_error("Dialogue close retains portrait speech state")
	if Dialogue._line_voice.playing or Dialogue._line_voice.stream != null:
		failures += 1
		push_error("Dialogue close retains voice playback")
	await get_tree().create_timer(0.1).timeout
	print("DIALOGUE VOICE TIMING: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
