extends Node2D
func _ready()->void:
 await get_tree().process_frame
 var failures := 0
 for locked in [false,true]:
  var npc := NPC.new()
  npc.npc_id = "civilian_push_review"
  npc.position = Vector2(100,100)
  add_child(npc)
  npc.set_physics_process(false)
  var door := Door.new()
  door.setup(Vector2(116,84),32,PI*.5,locked)
  add_child(door)
  for frame in 2: await get_tree().physics_frame
  npc._on_noise(Vector2(70,100),100,&"gunshot",null)
  var max_swing := 0.0
  var max_x := npc.position.x
  for frame in 90:
   npc._physics_process(1.0/120.0)
   await get_tree().physics_frame
   max_swing = maxf(max_swing,absf(door.swing))
   max_x = maxf(max_x,npc.position.x)
  var ok := max_x <= 110 and max_swing < .001 if locked else max_x > 130 and max_swing > .1
  if not ok: failures += 1
  print("PASS " if ok else "FAIL ","locked=",locked," furthest_x=",max_x," swing=",max_swing)
  npc.queue_free()
  door.queue_free()
  for frame in 2: await get_tree().physics_frame
 print("CIVILIAN DOOR PUSH REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)