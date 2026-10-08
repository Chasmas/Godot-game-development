extends Node
func _ready()->void:
 var sequence := FrameSequence.new()
 add_child(sequence)
 var pixels := Image.create(16,9,false,Image.FORMAT_RGBA8)
 pixels.fill(Color.WHITE)
 var texture := ImageTexture.create_from_image(pixels)
 var frames: Array[Texture2D] = [texture,texture]
 var completions := [0]
 sequence.configure_textures(frames,10.0,false)
 sequence.finished.connect(func():
  completions[0] += 1
  if completions[0] == 1:
   sequence.configure_textures(frames,10.0,false)
   sequence.play())
 sequence.play()
 sequence._process(.21)
 var next_ok: bool = completions[0] == 1 and sequence.playing and sequence.is_processing() and sequence.frame == 0
 var failures := 0
 if not next_ok: failures += 1
 print("PASS " if next_ok else "FAIL "," finished callback starts next sequence without being stopped")
 sequence._process(.21)
 var end_ok: bool = completions[0] == 2 and not sequence.playing and not sequence.is_processing()
 if not end_ok: failures += 1
 print("PASS " if end_ok else "FAIL "," final sequence stops and emits once")
 sequence._process(1.0)
 if completions[0] != 2: failures += 1
 sequence.configure_textures(frames,10.0,true)
 sequence.play()
 var rejected := not sequence.configure_reviewed("res://build/missing_sequence_review", "nonexistent")
 var fallback_ok := rejected and sequence.frames.is_empty() and not sequence.playing and not sequence.is_processing()
 if not fallback_ok: failures += 1
 print("PASS " if fallback_ok else "FAIL "," rejected replacement clears stale animation for still fallback")
 var names: Array[String] = ["contact.png","frame_2.png","frame_1.png"]
 var ordered := FrameSequence.ordered_render_names(names)
 var order_ok := ordered == ["frame_1.png","frame_2.png"]
 if not order_ok: failures += 1
 print("PASS " if order_ok else "FAIL "," numeric render order excludes contact sheet")
 var gap: Array[String] = ["frame_0001.png","frame_0003.png"]
 var duplicate: Array[String] = ["frame_0001.png","frame_1.webp"]
 var integrity_ok := FrameSequence.ordered_render_names(gap).is_empty() and FrameSequence.ordered_render_names(duplicate).is_empty()
 if not integrity_ok: failures += 1
 print("PASS " if integrity_ok else "FAIL "," missing and duplicate frame numbers rejected")
 var preview_path := "res://assets/art/animated/cutscenes/apartment_1988"
 var preview_ok := sequence.configure(preview_path,12.0,false) and sequence.frames.size() == 24
 if not preview_ok: failures += 1
 print("PASS " if preview_ok else "FAIL "," existing 24-frame staging preview loads in numeric order")
 var gate_ok := not sequence.configure_reviewed(preview_path) and sequence.frames.is_empty()
 if not gate_ok: failures += 1
 print("PASS " if gate_ok else "FAIL "," actual unapproved preview remains excluded from production playback")
 var clock := FrameSequence.new()
 add_child(clock)
 clock.configure_textures(frames,10.0,true)
 clock.play()
 clock._process(3600.15)
 var clock_ok := clock.playing and clock.frame == 1 and absf(clock.elapsed-.05) < .0001
 if not clock_ok: failures += 1
 print("PASS " if clock_ok else "FAIL ","long stall advances looping clock directly with remainder")
 clock.pause()
 var paused_frame := clock.frame
 clock._process(1.0)
 var pause_ok := clock.frame == paused_frame
 if not pause_ok: failures += 1
 print("PASS " if pause_ok else "FAIL ","pause preserves frame")
 var one: Array[Texture2D] = [texture]
 clock.configure_textures(one,10.0,false)
 var single_completions := [0]
 clock.finished.connect(func(): single_completions[0] += 1)
 clock.play()
 clock._process(.1)
 var single_ok:bool = single_completions[0] == 1 and not clock.playing and clock.frame == 0
 if not single_ok: failures += 1
 print("PASS " if single_ok else "FAIL ","one-frame shot completes at its authored duration")
 clock.hold_last = false
 clock.configure_textures(frames,10.0,false)
 clock.play()
 clock._process(4.0)
 var clear_ok := clock.frames.is_empty() and not clock.playing
 if not clear_ok: failures += 1
 print("PASS " if clear_ok else "FAIL ","non-holding shot clears completed image")
 print("FRAME SEQUENCE TRANSITION REVIEW: ",failures," failures")
 Audio.shutdown()
 get_tree().quit(1 if failures else 0)
