extends Node
func _ready() -> void:
 Engine.set_meta("skip_tasks", true)
 Engine.set_meta("autoplay", true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://security_map_visual_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 DirAccess.make_dir_recursive_absolute("res://build/security_map_review")
 var captured := 0
 for mission in ["m01_checkout", "m02_dog_days", "m03_prime_time"]:
  Game.replay_mission(mission)
  Game.attempts = 2
  for frame in 90: await get_tree().physics_frame
  var level := get_tree().get_first_node_in_group("level") as Level
  var player := level.player
  player.god_mode = true
  player.input_enabled = false
  player.set_physics_process(false)
  for enemy in level.enemies: enemy.set_physics_process(false)
  for camera in get_tree().get_nodes_in_group("security_cameras"):
   camera.set_physics_process(false)
   camera._aim = camera.base_angle + camera.sweep * clampf(float(OS.get_environment("CAMERA_SWEEP_OFFSET")), -1.0, 1.0)
   camera._meter = 0.0
   if not OS.get_environment("CAMERA_SCAN_PHASE").is_empty():
    camera._led = clampf(float(OS.get_environment("CAMERA_SCAN_PHASE")), 0.0, 0.99) / 0.9
   player.global_position = camera.global_position + Vector2.from_angle(camera.base_angle) * 50.0
   level.camera.snap_to_target()
   camera._rebuild_cone()
   camera.queue_redraw()
   for frame in 8: await get_tree().process_frame
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://build/security_map_review/%s_%d%s.png" % [mission,captured,OS.get_environment("CAMERA_CAPTURE_SUFFIX")])
   print("CAPTURE ",mission," ",camera.position," aim=",rad_to_deg(camera.base_angle))
   captured += 1
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 print("SECURITY MAP VISUAL: ",captured," captures")
 Game.request_quit(0 if captured == 9 else 1)
