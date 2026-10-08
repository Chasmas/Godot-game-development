extends Node2D
func _ready()->void:
 await get_tree().process_frame
 var failures := 0
 var npc := NPC.new()
 npc.npc_id = "punch_flee_review"
 add_child(npc)
 npc.set_physics_process(false)
 for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2.ZERO]:
  npc.position = Vector2(200,200)
  npc.facing = Vector2.DOWN
  npc.panicking = false
  var info := DamageInfo.make(DamageInfo.Type.PUNCH,null,npc.global_position,direction,&"fists",&"punch")
  info.lethal = false
  info.dir = direction
  var result := npc.take_damage(info)
  for frame in 30:
   await get_tree().physics_frame
   npc._physics_process(1.0/120.0)
  var expected: Vector2 = direction if direction != Vector2.ZERO else Vector2.DOWN
  var travel := npc.position-Vector2(200,200)
  var ok := result == "hurt" and npc.alive and travel.dot(expected) > 20 and npc.panicking
  if not ok: failures += 1
  print("PASS " if ok else "FAIL ","punch direction=",direction," travel=",travel)
 npc.position = Vector2(200,200)
 npc._on_noise(npc.position,100,&"explosion",null)
 var ok := npc._flee_dir.length() > .99
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ","coincident noise has valid escape direction")
 print("NPC PUNCH FLEE REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)