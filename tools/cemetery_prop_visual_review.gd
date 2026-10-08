extends Node

func _ready() -> void:
 Engine.set_meta("skip_tasks", true)
 Engine.set_meta("autoplay", true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var saved_path := SaveManager.save_path
 SaveManager.save_path = "user://cemetery_prop_visual_review_save.json"
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 Game.replay_mission("m04_sweet_dreams")
 Game.attempts = 2
 for frame in 90: await get_tree().physics_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 level.player.input_enabled = false
 level.player.set_physics_process(false)
 for enemy in level.enemies: enemy.set_physics_process(false)
 level.camera.set_process(false)
 level.camera.set_physics_process(false)
 if OS.get_environment("CEMETERY_COLLISION_REVIEW") == "1":
  var failures := 0
  var player := level.player
  player.god_mode = true
  for x in [120.0,216.0,168.0]:
   player.global_position = Vector2(x,824)
   player.velocity = Vector2.ZERO
   for frame in 90:
    player._movement(Vector2.UP,1.0/120.0)
    player.move_and_slide()
    await get_tree().physics_frame
   var okay := player.global_position.y < 750 if x != 168 else player.global_position.y >= 797
   if not okay: failures += 1
   print("PASS " if okay else "FAIL "," mausoleum walking lane x=",x," end=",player.global_position)
  var path := level.get_nav_path(Vector2(168,824),Vector2(168,728))
  if path.is_empty(): failures += 1
  for point in path:
   if Rect2(137,758,62,34).has_point(point): failures += 1
  player.global_position = Vector2(1080,904)
  var guard := Enemy.new()
  guard.idle_action = "watch"
  level.actors_root.add_child(guard)
  guard.setup(DB.enemy(&"guard"),level,Vector2.UP)
  guard.global_position = Vector2(168,824)
  guard._begin_investigate(Vector2(168,728),0.0)
  var nearest := INF
  var crossed := false
  for frame in 960:
   await get_tree().physics_frame
   nearest = minf(nearest,guard.global_position.distance_to(Vector2(168,728)))
   crossed = crossed or Rect2(137,758,62,34).has_point(guard.global_position)
  var reached := nearest < 12 and not crossed
  if not reached: failures += 1
  print("PASS " if reached else "FAIL "," active guard detour nearest=",nearest," crossed footprint=",crossed)
  print("MAUSOLEUM COLLISION REVIEW: ",failures," failures; detour points=",path.size())
  SaveManager.data = saved
  SaveManager.save_path = saved_path
  Game.request_quit(1 if failures else 0)
  return
 var target := Vector2(200,712)
 if OS.get_environment("CEMETERY_ANGEL_REVIEW") == "1":
  target = Vector2(296,696)
  var image := Image.load_from_file("res://assets/art/reference/cemetery/mourning_angel_v2.png")
  var angel := Sprite2D.new()
  angel.texture = ImageTexture.create_from_image(image)
  angel.scale = Vector2.ONE * (66.0/image.get_height())
  angel.offset.y = -image.get_height()*.47
  angel.position = target
  angel.modulate = Color(.6,.6,.6,1)
  angel.z_index = 1
  level.props_root.add_child(angel)
 if OS.get_environment("CEMETERY_MAUSOLEUM_REVIEW") == "1":
  target = Vector2(168,792)
 level.player.global_position = target + Vector2(0,60)
 level.camera.global_position = target
 DirAccess.make_dir_recursive_absolute("res://build/cemetery_prop_review")
 for frame in 8: await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://build/cemetery_prop_review/villa_before.png")
 var decor := level.get_node("Decor")
 var replaced := 0
 for child in decor.get_children():
  if child is Sprite2D and child.get_meta("rendered_decor_id", "") == "grave":
   replaced += 1
 for frame in 8: await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://build/cemetery_prop_review/villa_after.png")
 if OS.get_environment("CEMETERY_ANGEL_REVIEW") == "1":
  get_viewport().get_texture().get_image().save_png("res://build/cemetery_prop_review/angel_game.png")
 if OS.get_environment("CEMETERY_MAUSOLEUM_REVIEW") == "1":
  get_viewport().get_texture().get_image().save_png("res://build/cemetery_prop_review/mausoleum_game.png")
 if OS.get_environment("CEMETERY_LIGHT_DIAGNOSTIC") == "1":
  var cel = PostFX.mat.get_shader_parameter("cel")
  PostFX.mat.set_shader_parameter("cel", 0.0)
  for frame in 3: await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://build/cemetery_prop_review/villa_no_cel.png")
  PostFX.mat.set_shader_parameter("cel", cel)
  var shadows: Array = []
  for fixture in get_tree().get_nodes_in_group("lights"):
   if fixture is LightFixture:
    shadows.append([fixture, fixture.light.shadow_enabled])
    fixture.light.shadow_enabled = false
  for frame in 3: await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://build/cemetery_prop_review/villa_no_shadows.png")
  for entry in shadows: entry[0].light.shadow_enabled = entry[1]
 print("CEMETERY PROP REVIEW: ", replaced, " imported burial plots present; collision unchanged")
 SaveManager.data = saved
 SaveManager.save_path = saved_path
 Game.request_quit(0 if replaced == 18 else 1)
