extends Node
var failures := 0
func check(ok:bool,label:String)->void:
 if not ok: failures += 1
 print("PASS " if ok else "FAIL ",label)
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://security_corridor_counterplay_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 Game.replay_mission("m01_checkout")
 Game.attempts = 2
 for frame in 90: await get_tree().physics_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 var player := level.player
 player.god_mode = true
 player.input_enabled = false
 player.set_physics_process(false)
 player.respawn_grace = 0
 for enemy in level.enemies:
  enemy.set_physics_process(false)
  enemy.collision_layer = 0
 for node in get_tree().get_nodes_in_group("security_cameras"): node.set_physics_process(false)
 for mount in [Vector2(296,516),Vector2(648,516)]:
  var camera:SecurityCamera
  for node in get_tree().get_nodes_in_group("security_cameras"):
   if node.position.distance_to(mount) < 1: camera = node
  check(camera != null,"authored corridor camera found at " + str(mount))
  if camera == null: continue
  await review_crossing(camera,player,mount)
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 print("CORRIDOR COUNTERPLAY: ",failures," failures")
 Game.request_quit(1 if failures else 0)

func review_crossing(camera:SecurityCamera,player:Player,mount:Vector2)->void:
 for direction in [-1.0,1.0]:
  camera._meter = 0.0
  camera._cool = 0.0
  camera._aim = camera.base_angle
  camera._t = 0.0
  player.global_position = mount + Vector2(-direction*48,20)
  player.velocity = Vector2.ZERO
  var start := player.global_position
  var peak := 0.0
  for frame in 110:
   await get_tree().physics_frame
   player._movement(Vector2(direction,0),1.0/120.0)
   player.move_and_slide()
   camera._physics_process(1.0/120.0)
   peak = maxf(peak,camera._meter)
  print("ROUTE mount=",mount," direction=",direction," start=",start," end=",player.global_position," peak=",peak," cooldown=",camera._cool)
  check((player.global_position.x-start.x)*direction >= 96,"real movement crosses corridor mount")
  check(camera._cool == 0.0,"wall-side crossing avoids alarm")
 # Standing in clear view must still trigger surveillance.
 camera._meter = 0.0
 camera._cool = 0.0
 camera._aim = camera.base_angle
 player.global_position = camera.global_position + Vector2.from_angle(camera.base_angle)*60
 check(camera.can_see_point(player.global_position),"waiting position has clear lens view")
 for frame in 120:
  await get_tree().physics_frame
  camera._physics_process(1.0/120.0)
 check(camera._cool > 0.0,"lingering in clear view triggers alarm")
