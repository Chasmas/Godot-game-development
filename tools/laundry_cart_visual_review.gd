extends Node
func _ready()->void:
 Engine.set_meta("skip_tasks",true)
 Engine.set_meta("autoplay",true)
 await get_tree().process_frame
 var saved := SaveManager.data.duplicate(true)
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 Game.campaign_mode = false
 Game.replay_mission("m01_checkout")
 Game.attempts = 2
 for frame in 90: await get_tree().physics_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 level.player.god_mode = true
 level.player.input_enabled = false
 level.player.set_physics_process(false)
 for enemy in level.enemies: enemy.set_physics_process(false)
 var image := Image.load_from_file("res://build/blender_prop_review/laundry_cart_v6.png")
 if image == null or image.is_empty():
  SaveManager.data = saved
  Game.request_quit(1)
  return
 var sprite := Sprite2D.new()
 sprite.name = "StagingLaundryCart"
 sprite.texture = ImageTexture.create_from_image(image)
 sprite.centered = false
 sprite.offset = Vector2(-128,-210)
 sprite.scale = Vector2.ONE*.125
 sprite.position = Vector2(136,456)
 sprite.modulate = Color(.65,.65,.65)
 sprite.z_index = 5
 level.props_root.add_child(sprite)
 var shadow := Polygon2D.new()
 var points := PackedVector2Array()
 for i in 24: points.append(Vector2(cos(i*TAU/24)*8,sin(i*TAU/24)*2.5))
 shadow.polygon = points
 shadow.color = Color(0,0,0,.22)
 shadow.position = sprite.position+Vector2(0,-2)
 shadow.z_index = -6
 level.props_root.add_child(shadow)
 var body := StaticBody2D.new()
 body.position = Vector2(136,450)
 body.collision_layer = Layers.LOW
 body.collision_mask = 0
 var shape := CollisionShape2D.new()
 var footprint := RectangleShape2D.new()
 footprint.size = Vector2(18,12)
 shape.shape = footprint
 body.add_child(shape)
 level.props_root.add_child(body)
 level.nav.set_point_solid(Vector2i(8,28),true)
 for frame in 2: await get_tree().physics_frame
 if OS.get_environment("LAUNDRY_COLLISION_REVIEW") == "1":
  var failures := 0
  var player := level.player
  for route in [[Vector2(120,488),Vector2.UP],[Vector2(120,440),Vector2.DOWN]]:
   player.global_position = route[0]
   player.velocity = Vector2.ZERO
   for frame in 70:
    player._movement(route[1],1.0/120.0)
    player.move_and_slide()
    await get_tree().physics_frame
   var travelled: float = (player.global_position-route[0]).dot(route[1])
   if travelled < 40: failures += 1
   print("PASS " if travelled >= 40 else "FAIL "," washer/cart passage start=",route[0]," end=",player.global_position)
  player.global_position = Vector2(136,488)
  player.velocity = Vector2.ZERO
  for frame in 70:
   player._movement(Vector2.UP,1.0/120.0)
   player.move_and_slide()
   await get_tree().physics_frame
  var blocked := player.global_position.y >= 460.9 and player.global_position.y < 465
  if not blocked: failures += 1
  print("PASS " if blocked else "FAIL "," cart footprint blocks walking at ",player.global_position)
  player.global_position = Vector2(848,880)
  var guard := Enemy.new()
  guard.idle_action = "watch"
  level.actors_root.add_child(guard)
  guard.setup(DB.enemy(&"guard"),level,Vector2.UP)
  guard.global_position = Vector2(136,488)
  guard._begin_investigate(Vector2(136,440),0.0)
  var nearest := 1000.0
  for frame in 720:
   await get_tree().physics_frame
   nearest = minf(nearest,guard.global_position.distance_to(Vector2(136,440)))
  var reached := nearest < 12.0
  if not reached: failures += 1
  print("PASS " if reached else "FAIL "," active guard navigates around cart, nearest=",nearest)
  guard.set_physics_process(false)
  player.global_position = Vector2(136,488)
  player.velocity = Vector2.ZERO
  player._last_move = Vector2.UP
  player._dash_cd = 0.0
  player.stamina = 100.0
  player._start_dash()
  var crossed := false
  for frame in 180:
   player._movement(Vector2.ZERO,1.0/120.0)
   player.move_and_slide()
   player._after_move()
   await get_tree().physics_frame
   crossed = crossed or player.global_position.y < 444
  var roll_ok := crossed and not player.is_dashing() and not player._overlaps(Layers.LOW) and player.collision_mask == Layers.WALK_MASK_PLAYER
  if not roll_ok: failures += 1
  print("PASS " if roll_ok else "FAIL "," cart roll clears obstacle and restores walking collision at ",player.global_position)
  SaveManager.data = saved
  print("LAUNDRY COLLISION REVIEW: ",failures," failures")
  Game.request_quit(1 if failures else 0)
  return
 level.camera.set_process(false)
 level.camera.set_physics_process(false)
 level.camera.zoom = Vector2.ONE*3.0
 level.camera.global_position = sprite.global_position
 for frame in 8: await get_tree().process_frame
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://build/blender_prop_review/laundry_cart_game_review.png")
 SaveManager.data = saved
 print("LAUNDRY CART VISUAL REVIEW: staging-only capture")
 Game.request_quit(0)
