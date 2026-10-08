extends Node
func _ready() -> void:
 Engine.set_meta("autoplay", true)
 Engine.set_meta("trailer", true)
 # Running this helper with `--script` does not expose autoload singletons as
 # compile-time identifiers. Resolve Game from the scene tree so the gallery
 # remains usable both as a project script and as a headless capture helper.
 var game := get_node_or_null("/root/Game")
 if game == null:
  push_error("Game autoload is unavailable; run the gallery with --path .")
  get_tree().quit(1)
  return
 game.force_intro_calls = false
 var dialogue := get_node_or_null("/root/Dialogue")
 var post_fx := get_node_or_null("/root/PostFX")
 await get_tree().process_frame
 var placeholder := Node.new()
 get_tree().root.add_child(placeholder)
 get_tree().current_scene = placeholder
 var mid := OS.get_environment("GALLERY_MISSION")
 game.start_mission(mid)
 for i in 140:
  if dialogue and dialogue.active: dialogue._end()
  var player := get_tree().get_first_node_in_group("player") as Player
  if player: player.god_mode = true
  await get_tree().process_frame
 var level := get_tree().get_first_node_in_group("level") as Level
 if level == null:
  push_error("Mission did not load: " + mid)
  get_tree().quit(1)
  return
 # Clean art-review mode removes gameplay presentation filters so a preview
 # can be judged for alignment, value structure, and occlusion. It is opt-in
 # and gallery-only; normal gameplay keeps the CRT, darkness, and lighting.
 if OS.get_environment("GALLERY_CLEAN") == "1":
  if is_instance_valid(post_fx) and post_fx.rect:
   post_fx.rect.visible = false
  if level.darkness:
   level.darkness.visible = false
  if level.dark_modulate:
   # Preserve the production ambient by default. Neutral white is available
   # for raw texture inspection, but should not hide the level's value design.
   level.dark_modulate.color = Color.WHITE if OS.get_environment("GALLERY_CLEAN_NEUTRAL") == "1" else level.ambient
  if level.weather:
   # Weather is useful for the final mood pass, but it obscures edge and
   # occlusion checks while judging a static plate.
   level.weather.visible = false
 # Optional lighting-isolation pass for the prerender review. M01 uses
 # magenta exterior fixtures as a production mood cue; hiding only those
 # fixtures makes it possible to judge the plate without changing gameplay.
 if OS.get_environment("GALLERY_MUTE_MAGENTA_LIGHTS") == "1":
  for light_node in get_tree().get_nodes_in_group("lights"):
   if light_node is LightFixture and light_node.light and light_node.light.color.r > 0.55 and light_node.light.color.b > 0.35 and light_node.light.color.g < 0.55:
    light_node.visible = false
 # Review-only isolation mode: keep gameplay nodes/collisions alive while
 # hiding the live art roots that can duplicate a Blender plate. This never
 # runs in normal gameplay and makes layer alignment/occlusion captures
 # reproducible before any runtime integration decision.
 if OS.get_environment("GALLERY_PRERENDER_ISOLATE") == "1":
  for root_name in ["Walls", "Decor", "Props", "Floor", "Visual3DDressing"]:
   var review_root := level.get_node_or_null(NodePath(root_name))
   if review_root:
    review_root.visible = false
 var player_for_review := get_tree().get_first_node_in_group("player") as Node2D
 var review_cell := OS.get_environment("GALLERY_PLAYER_CELL")
 if player_for_review and review_cell != "":
  var pc := review_cell.split(",")
  if pc.size() >= 2:
   player_for_review.global_position = Vector2(float(pc[0]) * 16 + 8, float(pc[1]) * 16 + 8)
 if player_for_review and OS.get_environment("GALLERY_SHOW_PLAYER") == "1":
  player_for_review.visible = true
  player_for_review.z_index = 100
  if player_for_review is Player and player_for_review.visual:
   player_for_review.visual.visible = true
   if player_for_review.visual.cast_sprite:
    player_for_review.visual.cast_sprite.play_sample("idle", 0.0)
    player_for_review.visual.cast_sprite.self_modulate.a = 1.0
    var cast_model := player_for_review.visual.cast_sprite as CastModel
    if cast_model and cast_model._viewport:
     cast_model._viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
   player_for_review.visual.scale = Vector2.ONE
 var points := {"m01_checkout": Vector2(510, 340), "m02_dog_days": Vector2(590, 330), "m03_prime_time": Vector2(560, 330), "m04_sweet_dreams": Vector2(585, 280)}
 # Optional, preview-only Blender plate. It is deliberately opt-in so the
 # normal level and all gameplay validation remain unchanged.
 if OS.get_environment("GALLERY_PRERENDER") == "1" and mid == "m01_checkout":
  var plate_alpha := float(OS.get_environment("GALLERY_PRERENDER_ALPHA")) if OS.get_environment("GALLERY_PRERENDER_ALPHA") != "" else 0.62
  var plate_scale := float(OS.get_environment("GALLERY_PRERENDER_SCALE")) if OS.get_environment("GALLERY_PRERENDER_SCALE") != "" else 0.333333
  var pixel_candidate := OS.get_environment("GALLERY_PRERENDER_PIXEL") == "1"
  var pixel_candidate_hq := OS.get_environment("GALLERY_PRERENDER_PIXEL_HQ") == "1"
  var ground_only := OS.get_environment("GALLERY_PRERENDER_GROUND_ONLY") == "1"
  var ground_no_emissive := OS.get_environment("GALLERY_PRERENDER_GROUND_NO_EMISSIVE") == "1"
  var ground_no_pool := OS.get_environment("GALLERY_PRERENDER_GROUND_NO_POOL") == "1"
  # Neutral is a Blender-light-disabled staging layer; it never changes normal art.
  var ground_neutral := OS.get_environment("GALLERY_PRERENDER_GROUND_NEUTRAL") == "1"
  if ground_neutral and ground_no_pool:
   push_warning("Gallery staging flags GALLERY_PRERENDER_GROUND_NEUTRAL and GALLERY_PRERENDER_GROUND_NO_POOL are both set; neutral variant takes precedence.")
  var plate_position := Vector2(464, 296)
  var plate_offset := OS.get_environment("GALLERY_PRERENDER_OFFSET")
  if plate_offset != "":
   var po := plate_offset.split(",")
   if po.size() >= 2:
    plate_position += Vector2(float(po[0]), float(po[1]))
  var layer_paths := [
   "res://assets/art/prerendered/m01_sunset_palms/layers/ground.png",
   "res://assets/art/prerendered/m01_sunset_palms/layers/props_vegetation.png"
  ] if OS.get_environment("GALLERY_PRERENDER_LAYERS") == "1" and not ground_only else [
   "res://assets/art/prerendered/m01_sunset_palms/layers/ground_no_pool_neutral_review.png"
  ] if ground_only and ground_neutral else [
   "res://assets/art/prerendered/m01_sunset_palms/layers/ground_no_pool_review.png"
  ] if ground_only and ground_no_pool else [
   "res://assets/art/prerendered/m01_sunset_palms/layers/ground_no_emissive_review.png"
  ] if ground_only and ground_no_emissive else [
   "res://assets/art/prerendered/m01_sunset_palms/layers/ground.png"
  ] if ground_only else [
   ("res://assets/art/prerendered/m01_sunset_palms/courtyard_pixel_art_candidate_hq.png" if pixel_candidate_hq else ("res://assets/art/prerendered/m01_sunset_palms/courtyard_pixel_art_candidate.png" if pixel_candidate else "res://assets/art/prerendered/m01_sunset_palms/courtyard_master.png"))
  ]
  for i in layer_paths.size():
   var plate := Sprite2D.new()
   plate.name = "M01PrerenderPreview_%d" % i
   plate.texture = load(layer_paths[i])
   plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
   plate.centered = true
   plate.position = plate_position
   plate.scale = Vector2.ONE * plate_scale
   plate.modulate.a = plate_alpha
   plate.z_index = -10 + i
   level.add_child(plate)
 var probe := Node2D.new()
 level.add_child(probe)
 probe.global_position = points.get(mid, Vector2(500,300))
 level.camera.target = probe
 level.camera.zoom_bias = float(OS.get_environment("GALLERY_ZOOM")) if OS.get_environment("GALLERY_ZOOM") != "" else 1.0
 if OS.get_environment("GALLERY_CELL") != "":
  var gc := OS.get_environment("GALLERY_CELL").split(",")
  probe.global_position = Vector2(float(gc[0]) * 16 + 8, float(gc[1]) * 16 + 8)
 if OS.get_environment("GALLERY_AT") == "player":
  probe.global_position = (get_tree().get_first_node_in_group("player") as Node2D).global_position
 level.camera.snap_to_target()
 if level.hud: level.hud.visible = false
 for i in 20: await get_tree().process_frame
 if player_for_review and review_cell != "":
  var pc_after := review_cell.split(",")
  if pc_after.size() >= 2:
   player_for_review.global_position = Vector2(float(pc_after[0]) * 16 + 8, float(pc_after[1]) * 16 + 8)
 if player_for_review and OS.get_environment("GALLERY_SHOW_PLAYER") == "1" and player_for_review.visual and player_for_review.visual.cast_sprite:
  player_for_review.visual.cast_sprite.self_modulate.a = 1.0
  var final_cast_model := player_for_review.visual.cast_sprite as CastModel
  if final_cast_model and final_cast_model._viewport:
   final_cast_model.set_process(false)
   final_cast_model._viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 if player_for_review and OS.get_environment("GALLERY_PLAYER_FALLBACK") == "1":
  var fallback := Sprite2D.new()
  var fallback_atlas := load("res://assets/art/cast3d/cass/aim.png") as Texture2D
  if fallback_atlas:
   var fallback_texture := AtlasTexture.new()
   fallback_texture.atlas = fallback_atlas
   fallback_texture.region = Rect2(0, 0, 80, 80)
   fallback.texture = fallback_texture
   fallback.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
   fallback.position = player_for_review.global_position
   fallback.scale = Vector2.ONE * 1.0
   fallback.z_index = 101
   level.add_child(fallback)
 # In headless validation there may be no frame_post_draw signal at all. A
 # regular frame is enough after the settling loop above and keeps gallery
 # captures from hanging indefinitely while the real game remains unchanged.
 await get_tree().process_frame
 if DisplayServer.get_name().to_lower().contains("headless"):
  push_warning("Gallery capture skipped: headless renderer has no visual capture")
  get_tree().quit()
  return
 var gallery_texture := get_viewport().get_texture()
 if gallery_texture == null:
  push_warning("Gallery capture skipped: headless renderer has no viewport texture")
  get_tree().quit()
  return
 var gallery_image := gallery_texture.get_image()
 if gallery_image == null:
  push_warning("Gallery capture skipped: renderer returned no image")
  get_tree().quit()
  return
 gallery_image.save_png(OS.get_environment("GALLERY_OUT"))
 print("GALLERY mission=",mid," floor=",level.data.get("layout_revision")," pixelart=",ArtLib.sprite("palm") != null)
 get_tree().quit()
