extends Node2D
var failures := 0
func check(ok:bool,label:String)->void:
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 await get_tree().process_frame
 var npc := NPC.new()
 npc.npc_id = "panic_transition_review"
 npc.lines = ["Test line."]
 add_child(npc)
 npc.set_physics_process(false)
 print("CIVILIAN CLIPS: ",npc.visual.cast_sprite.clips.keys() if npc.visual.cast_sprite else [])
 npc._drop_activity()
 var activity := IdleActivity.new()
 npc.visual.rig.add_child(activity)
 activity.setup(npc.visual,IdleActivity.Kind.DRINK,"panic_transition")
 npc._activity = activity
 check(npc.can_interact(null),"calm civilian offers conversation")
 npc._on_noise(Vector2(-30,0),100,&"gunshot",null)
 check(npc._activity == null and activity.is_queued_for_deletion() and npc.visual.idle_activity_pose == "","panic clears held idle activity")
 check(not npc.can_interact(null),"conversation unavailable during flight")
 var previous := npc._line_i
 npc.interact(null)
 check(npc._line_i == previous,"direct interaction cannot advance dialogue during panic")
 for frame in 370:
  await get_tree().physics_frame
  npc._physics_process(1.0/120.0)
 check(not npc.panicking and npc.cowering and npc.velocity == Vector2.ZERO,"panic ends at rest")
 check(npc.visual._cast_velocity == Vector2.ZERO if npc.visual.cast_sprite else npc.visual._speed_k < .01,"rest does not retain walking velocity")
 check(npc.can_interact(null),"conversation returns after panic")
 npc.interact(null)
 check(npc._line_i == previous+1,"settled civilian dialogue can advance")
 print("NPC PANIC TRANSITION REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)