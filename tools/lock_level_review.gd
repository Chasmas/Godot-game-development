extends Node
var failures: Array=[]
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
 print("PASS " if ok else "FAIL ",message)
func _ready() -> void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var placeholder:=Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene=placeholder
 Game.start_mission("m01_checkout")
 for frame in 60: await get_tree().physics_frame
 var p:=get_tree().get_first_node_in_group("player") as Player
 p.god_mode=true
 p.set_physics_process(false)
 p.input_enabled=true
 var enemies:=get_tree().get_nodes_in_group("enemies")
 var target:=enemies[0] as Enemy
 for enemy in enemies:
  enemy.set_physics_process(false)
  if enemy!=target: enemy.remove_from_group("enemies")
 target.global_position=p.global_position+Vector2(24,0)
 await get_tree().physics_frame
 print("LOCK FIXTURE alive=",target.is_alive()," input=",p.input_enabled," candidates=",p._lock_candidates().size())
 check(p._has_los(p.global_position,target.global_position,target),"Real enemy visible for acquisition")
 await get_tree().process_frame
 p.input_enabled=true
 Input.action_press("lock_on")
 p._update_lock(.016)
 check(p.lock_target==target,"Real candidate discovery acquires enemy")
 Input.action_release("lock_on")
 await get_tree().process_frame
 Input.action_press("lock_on")
 p._update_lock(.016)
 check(p.lock_target==null,"Real level tap releases enemy")
 Input.action_release("lock_on")
 await get_tree().process_frame
 p.set_lock(target)
 var obstacle:=StaticBody2D.new()
 obstacle.collision_layer=Layers.WORLD
 var shape:=CollisionShape2D.new()
 var box:=RectangleShape2D.new()
 box.size=Vector2(4,16)
 shape.shape=box
 obstacle.add_child(shape)
 get_tree().root.add_child(obstacle)
 obstacle.global_position=(p.global_position+target.global_position)*.5
 await get_tree().physics_frame
 await get_tree().physics_frame
 check(not p._has_los(p.global_position,target.global_position,target),"Inserted wall blocks actual physics ray")
 p._update_lock(.1)
 check(p.lock_target==target,"Brief obstruction keeps lock")
 p._update_lock(.21)
 check(p.lock_target==null,"Sustained obstruction returns free aim")
 obstacle.queue_free()
 print("LOCK LEVEL REVIEW: ",failures.size()," failures ",failures)
 Game.request_quit(1 if not failures.is_empty() else 0)
