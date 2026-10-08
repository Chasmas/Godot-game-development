extends Node2D
func _ready() -> void:
 if DisplayServer.get_name()=="headless":
  Game.request_quit(1)
  return
 var output:="res://build/cass_arm_angle_candidates"
 DirAccess.make_dir_recursive_absolute(output)
 var records:=[]
 var looks: PackedStringArray = ["cass","cass","cass","cass","cass","cass","cass","cass"]
 var angle_index := -1
 for look in looks:
  angle_index += 1
  if look in ["eldorado"]: continue
  for part in ["arm"]:
   var stage:=SubViewport.new()
   stage.size=Vector2i(256,256)
   stage.transparent_bg=true
   stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
   add_child(stage)
   var cell:=Node2D.new()
   cell.position=Vector2(128,128)
   cell.scale=Vector2.ONE*4.
   cell.rotation=float(angle_index)*PI/4.0
   stage.add_child(cell)
   var model:=CastModel.create(look)
   cell.add_child(model)
   preload("res://tools/wing_safe_cut_candidate.gd").cut(model,part,true)
   var attached: int = preload("res://tools/wound_candidate_binding.gd").attach(model,look,part)
   var geometry: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("WOUND_GEOMETRY_PATH")))
   var expected := 0
   for item in geometry:
    if item.look==look and item.part==part: expected += 1
   if attached != expected or expected == 0:
    push_error("Incomplete detached wound: " + look + " " + part)
    Game.request_quit(1)
    return
   for frame in 16:
    model.play_sample("death_back",1./60.,.995)
    await get_tree().process_frame
   await RenderingServer.frame_post_draw
   var pixels:=stage.get_texture().get_image()
   var bounds:=pixels.get_used_rect()
   if bounds.size.x==0 or bounds.size.y==0:
    push_error("Empty body part: "+look+" "+part)
    Game.request_quit(1)
    return
   var crop:=pixels.get_region(bounds)
   crop.save_png(output+"/angle_%d.png" % angle_index)
   records.append({"look":look,"part":part,"pixels":[bounds.size.x,bounds.size.y],"game_size":[bounds.size.x/4.,bounds.size.y/4.],"approved":false,"angle_index":angle_index,"caps":attached,"expected_caps":expected})
   stage.queue_free()
   await get_tree().process_frame
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(records,"  "))
 print("BAKED BODY PARTS: ",records.size()," pending visual approval")
 Game.request_quit()
