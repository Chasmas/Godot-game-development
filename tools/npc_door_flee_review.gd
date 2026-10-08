extends Node2D
var failures := 0
func check(ok:bool,label:String)->void:
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 await get_tree().process_frame
 var npc := NPC.new()
 npc.npc_id = "flee_door_review"
 add_child(npc)
 npc.position = Vector2(100,100)
 npc.set_physics_process(false)
 npc.visual.set_process(false)
 var door := StaticBody2D.new()
 door.position = Vector2(120,100)
 door.collision_layer = Layers.DOOR
 var collider := CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 shape.size = Vector2(4,160)
 collider.shape = shape
 door.add_child(collider)
 add_child(door)
 for frame in 2: await get_tree().physics_frame
 npc.cowering = true
 npc._on_noise(Vector2(70,100),100,&"gunshot",null)
 check(npc.panicking and not npc.cowering,"new panic leaves crouched pose before fleeing")
 var crossed := false
 var wrong_facing := false
 var recovered_along_wall := false
 for frame in 40:
  await get_tree().physics_frame
  npc._physics_process(1.0/120.0)
  crossed = crossed or npc.position.x > 113.0
  var travel := npc.get_real_velocity()
  if travel.length() > 5.0: wrong_facing = wrong_facing or npc.facing.dot(travel.normalized()) < .99
  recovered_along_wall = recovered_along_wall or absf(travel.y) > 80.0
 check(not crossed,"fleeing civilian cannot cross closed door")
 check(not wrong_facing,"civilian faces actual travel after collision")
 check(recovered_along_wall,"head-on collision becomes movement along door surface")
 door.collision_layer = 0
 npc.position = Vector2(100,100)
 npc._flee_dir = Vector2.RIGHT
 npc._panic_t = 3.0
 for frame in 40:
  await get_tree().physics_frame
  npc._physics_process(1.0/120.0)
 check(npc.position.x > 125,"open doorway permits normal escape")
 npc._panic_t = 1.0
 npc._physics_process(1.0/120.0)
 check(npc.velocity == Vector2.ZERO and npc.cowering,"settling panic stops movement and returns cowering pose")
 print("NPC DOOR FLEE REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)