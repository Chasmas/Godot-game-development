extends Node
func _ready()->void:
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 Dialogue.start("call_m01",true)
 Dialogue.set_process(false)
 Dialogue._input_block = 0.0
 Dialogue._shown = 0.0
 var node_before: Dictionary = Dialogue._node.duplicate(true)
 var press := InputEventAction.new()
 press.action = "ui_accept"
 press.pressed = true
 Dialogue._unhandled_input(press)
 var failures := 0
 var reveal_ok := not Dialogue.is_typing() and Dialogue._node == node_before
 if not reveal_ok: failures += 1
 print("PASS " if reveal_ok else "FAIL "," first advance reveals text without skipping line")
 Dialogue._unhandled_input(press)
 var duplicate_ok := Dialogue._node == node_before and Dialogue._input_block > 0.0
 if not duplicate_ok: failures += 1
 print("PASS " if duplicate_ok else "FAIL "," immediate duplicate input cannot skip next line")
 Dialogue._input_block = 0.0
 Dialogue._unhandled_input(press)
 var next_ok := not Dialogue.active or Dialogue._node != node_before
 if not next_ok: failures += 1
 print("PASS " if next_ok else "FAIL "," subsequent intentional input advances")
 Dialogue._end(false)
 var close_ok := not Dialogue._line_voice.playing and Dialogue.portrait.speech_energy == 0.0
 if not close_ok: failures += 1
 print("PASS " if close_ok else "FAIL "," dialogue close stops voice and mouth animation")
 Dialogue.set_process(true)
 SaveManager.data = saved
 print("DIALOGUE ADVANCE REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)
