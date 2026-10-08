extends Node2D
func _ready() -> void:
 if DisplayServer.get_name()=="headless":
  Game.request_quit(1)
  return
 var output:="res://build/matched_gore_parts_candidate"
 DirAccess.make_dir_recursive_absolute(output)
 var records:=[]
 var looks: PackedStringArray=["guard","stagehand"]
 if OS.get_environment("GORE_BAKE_ALL")=="1":
  looks=DirAccess.get_directories_at("res://assets/art/cast3d_rt")
 if OS.get_environment("GORE_BAKE_LOOKS")!="": looks=OS.get_environment("GORE_BAKE_LOOKS").split(",")
 for look in looks:
  if look in ["eldorado"]: continue
  for part in ["head","arm","leg"]:
   var stage:=SubViewport.new()
   stage.size=Vector2i(256,256)
   stage.transparent_bg=true
   stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
   add_child(stage)
   var cell:=Node2D.new()
   cell.position=Vector2(128,128)
   cell.scale=Vector2.ONE*4.
   stage.add_child(cell)
   var model:=CastModel.create(look)
   cell.add_child(model)
   preload("res://tools/upper_joint_cut_candidate.gd").cut(model,part,true)
   preload("res://tools/wound_candidate_binding.gd").attach(model,look,part)
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
   crop.save_png(output+"/"+look+"_"+part+".png")
   records.append({"look":look,"part":part,"pixels":[bounds.size.x,bounds.size.y],"game_size":[bounds.size.x/4.,bounds.size.y/4.],"approved":false})
   stage.queue_free()
   await get_tree().process_frame
 var file:=FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(records,"  "))
 print("BAKED BODY PARTS: ",records.size()," pending visual approval")
 Game.request_quit()
