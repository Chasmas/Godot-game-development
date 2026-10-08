extends Node
var failures := 0
func check(ok:bool,label:String)->void:
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 Dialogue.start("call_m02",true)
 Dialogue.set_process(false)
 Dialogue.portrait.set_process(false)
 for node_id in ["b","c","d"]:
  Dialogue.portrait.talking = true
  Dialogue.portrait.speech_energy = 0.8
  Dialogue.portrait._mouth = 2
  Dialogue.portrait._talk_amt = 1.0
  Dialogue._goto(node_id)
  check(not Dialogue.portrait.talking and Dialogue.portrait.speech_energy == 0.0 and Dialogue.portrait._mouth == 0 and Dialogue.portrait._talk_amt == 0.0,"new line clears previous speech immediately: " + node_id)
  check(Dialogue._has_authored_voice and Dialogue._line_voice.playing,"new line still starts authored voice: " + node_id)
 var p := Dialogue.portrait
 p.speaker = "mom"
 p.talking = true
 p.speech_energy = 0.8
 p._process(0.01)
 p._blinking = 0.0
 check(p._art_frame().resource_path.ends_with("mom_talk.png"),"loud Mom speech uses approved soft frame when wide frame is absent")
 p.speech_energy = 0.0
 p._process(0.01)
 p._blinking = 0.0
 check(p._mouth == 0 and p._art_frame().resource_path.ends_with("mom.png"),"audible pause restores closed mouth")
 p.talking = true
 p.speech_energy = 0.8
 p._process(0.01)
 Dialogue._end(false)
 p._process(0.01)
 check(not Dialogue._line_voice.playing and p._mouth == 0,"closing dialogue stops voice and mouth")
 p.set_process(true)
 Dialogue.set_process(true)
 SaveManager.data = saved
 print("DIALOGUE PORTRAIT TRANSITION REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)