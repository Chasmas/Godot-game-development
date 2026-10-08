extends Node
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://checkpoint_placement_visual_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 DirAccess.make_dir_recursive_absolute("res://build/checkpoint_placement_review")
 var results:Array = []
 for mission in ["m01_checkout","m02_dog_days","m03_prime_time","m04_sweet_dreams"]:
  var filter := OS.get_environment("CHECKPOINT_REVIEW_MISSION")
  if not filter.is_empty() and mission != filter: continue
  Game.replay_mission(mission)
  Game.attempts = 2
  for frame in 90: await get_tree().physics_frame
  var level := get_tree().get_first_node_in_group("level") as Level
  level.set_physics_process(false)
  level.player.god_mode = true
  level.player.input_enabled = false
  level.player.set_physics_process(false)
  level.camera.set_process(false)
  for enemy in level.enemies: enemy.set_physics_process(false)
  for old in level._cp_markers:
   if is_instance_valid(old): old.hide()
  var checkpoints:Array = level.data.get("checkpoints",[])
  for i in checkpoints.size():
   var r:Array = checkpoints[i].rect
   var rect := Rect2i(r[0],r[1],r[2],r[3])
   var position:Vector2 = level._door_point(rect,level._mission_start)
   var marker := CheckpointMarker.new()
   marker.position = position
   level.floor_root.add_child(marker)
   level.player.global_position = position + Vector2(0,24)
   level.camera.global_position = position
   var shape := RectangleShape2D.new()
   shape.size = Vector2(22,11)
   var query := PhysicsShapeQueryParameters2D.new()
   query.shape = shape
   query.transform = Transform2D(0,position)
   query.collision_mask = Layers.WORLD|Layers.PROP|Layers.LOW|Layers.DOOR
   var overlaps := level.get_world_2d().direct_space_state.intersect_shape(query)
   var names:Array = []
   for hit in overlaps: names.append(str(hit.collider))
   results.append({"mission":mission,"index":i,"name":checkpoints[i].get("name",""),"position":[position.x,position.y],"inside_trigger":rect.has_point(Vector2i(position/16.0)),"overlaps":names})
   for frame in 8: await get_tree().process_frame
   if mission == "m04_sweet_dreams" and i == 3:
    # The entry whisper lasts 3.5s. Observe after its real presentation,
    # rather than hiding an unrelated dialogue panel for a clear capture.
    for frame in 480: await get_tree().physics_frame
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://build/checkpoint_placement_review/%s_%d.png" % [mission,i])
   if OS.get_environment("CHECKPOINT_DARK_REVIEW") == "1":
    marker.set_process(false)
    marker._t = 0.0
    marker._process(0.0)
    var zone:String = level.zone_at(position)
    for on in [true,false]:
     level.set_zone_lights(zone,on)
     for tick in 3: await get_tree().process_frame
     await RenderingServer.frame_post_draw
     var scene_image := get_viewport().get_texture().get_image()
     var centre:Vector2 = marker.get_global_transform_with_canvas().origin*Vector2(scene_image.get_size())/get_viewport().get_visible_rect().size
     scene_image.get_region(Rect2i(Vector2i(centre)-Vector2i(100,80),Vector2i(200,160))).save_png("res://build/checkpoint_placement_review/%s_%d_lights_%s.png" % [mission,i,str(on)])
    level.set_zone_lights(zone,true)
   print("CHECKPOINT ",results.back())
   if i == 1 and OS.get_environment("CHECKPOINT_ACTIVATION_VISUAL") == "1":
    marker.set_process(false)
    marker.activate()
    marker._process(0.15)
    for tick in 2: await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("res://build/checkpoint_placement_review/%s_activation.png" % mission)
   if i == 1 and OS.get_environment("CHECKPOINT_MOTION_REVIEW") == "1":
    marker.set_process(false)
    DirAccess.make_dir_recursive_absolute("res://build/checkpoint_placement_review/motion")
    for frame in 48:
     marker._t = (TAU*frame/48.0)/0.55
     marker._process(0.0)
     for tick in 2: await get_tree().process_frame
     await RenderingServer.frame_post_draw
     var full := get_viewport().get_texture().get_image()
     var centre:Vector2 = marker.get_global_transform_with_canvas().origin*Vector2(full.get_size())/get_viewport().get_visible_rect().size
     full.get_region(Rect2i(Vector2i(centre)-Vector2i(100,80),Vector2i(200,160))).save_png("res://build/checkpoint_placement_review/motion/%03d.png" % frame)
   marker.queue_free()
 var file := FileAccess.open("res://build/checkpoint_placement_review/report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(results,"  "))
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 print("CHECKPOINT PLACEMENT: ",results.size()," actual positions captured")
 Game.request_quit(0)
