extends Node
var failures := 0
func check(ok:bool,label:String)->void:
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 await get_tree().process_frame
 var settings := SaveManager.settings.duplicate(true)
 for reduced in [false,true]:
  SaveManager.settings["reduced_flashing"] = reduced
  var marker := CheckpointMarker.new()
  add_child(marker)
  marker.set_process(false)
  check(marker._cassette != null and marker._neon_review,"neon candidate loads")
  if marker._cassette == null: continue
  marker._t = (PI*0.5)/0.55
  marker._process(0.0)
  check(marker._cassette_edge.visible,"edge-on checkpoint remains visible")
  marker.activate()
  marker._process(0.15)
  var progress := marker._burst
  marker.activate()
  check(marker._burst == progress,"duplicate activation cannot restart transition")
  var gain:float = marker._cassette.material.get_shader_parameter("gain")
  check(is_equal_approx(gain,1.0) if reduced else gain > 1.0 and gain <= 1.4,"save pulse respects reduced flashing")
  check(marker._light.energy <= 0.10 and marker._light.texture_scale <= 0.12,"save confirmation stays local")
  marker._process(0.46)
  check(marker.is_queued_for_deletion(),"save marker finishes within .61 seconds")
  await get_tree().process_frame
 var restored := CheckpointMarker.new()
 add_child(restored)
 restored.activate(true)
 check(restored.is_queued_for_deletion(),"restored checkpoint disappears silently")
 SaveManager.settings = settings
 print("CHECKPOINT ACTIVATION: ",failures," failures")
 Game.request_quit(1 if failures else 0)
