extends Node
func _ready()->void:
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var title: Control = load("res://scenes/ui/title_screen.tscn").instantiate()
 add_child(title)
 title._show_jukebox()
 Music.play("menu",true,0.0)
 for frame in 20: await get_tree().physics_frame
 var seek := title.find_child("JukeboxSeek",true,false) as HSlider
 var timer: Timer
 for node in title.panel_body.get_children():
  if node is Timer: timer = node
 var failures := 0
 if seek == null or timer == null or Music.playback_length() <= 0:
  failures += 1
 else:
  timer.stop()
  seek.release_focus()
  seek.set_value_no_signal(0.0)
  var signals := [0]
  seek.value_changed.connect(func(_v): signals[0] += 1)
  for i in 5: timer.timeout.emit()
  var sync_ok: bool = signals[0] == 0 and seek.value > 0.0
  if not sync_ok: failures += 1
  print("PASS " if sync_ok else "FAIL "," real jukebox timer updates progress without emitting seek command")
  seek.value = .5
  var user_ok: bool = signals[0] == 1
  if not user_ok: failures += 1
  print("PASS " if user_ok else "FAIL "," player slider change still emits one seek command")
  seek.grab_focus()
  seek.set_value_no_signal(0.0)
  timer.timeout.emit()
  var focus_ok: bool = seek.has_focus() and seek.value > 0.0 and signals[0] == 1
  if not focus_ok: failures += 1
  print("PASS " if focus_ok else "FAIL "," focused idle slider continues silent progress updates")
  seek.drag_started.emit()
  seek.set_value_no_signal(.25)
  timer.timeout.emit()
  var drag_ok := is_equal_approx(seek.value,.25)
  if not drag_ok: failures += 1
  print("PASS " if drag_ok else "FAIL "," progress timer does not fight active drag")
  seek.drag_ended.emit(false)
  timer.timeout.emit()
  var resumed_ok := not is_equal_approx(seek.value,.25)
  if not resumed_ok: failures += 1
  print("PASS " if resumed_ok else "FAIL "," progress resumes when drag ends")
  seek.set_value_no_signal(.25)
  Input.action_press("ui_left")
  timer.timeout.emit()
  var keyboard_ok := is_equal_approx(seek.value,.25)
  Input.action_release("ui_left")
  timer.timeout.emit()
  keyboard_ok = keyboard_ok and not is_equal_approx(seek.value,.25)
  if not keyboard_ok: failures += 1
  print("PASS " if keyboard_ok else "FAIL "," held keyboard seek suppresses sync until release")
 title._close_panel()
 var back_ok := Music.current_id == "menu"
 if not back_ok: failures += 1
 print("PASS " if back_ok else "FAIL "," leaving jukebox returns to menu music")
 SaveManager.data = saved
 print("JUKEBOX SEEK REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)
