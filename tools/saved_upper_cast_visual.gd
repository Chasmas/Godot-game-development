extends Node2D
func _ready() -> void:
 RenderingServer.set_default_clear_color(Color("191622"))
 var looks := DirAccess.get_directories_at("res://assets/art/cast3d_rt")
 looks.remove_at(looks.find("eldorado"))
 var stage := SubViewport.new()
 stage.size = Vector2i(780,1680)
 stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 add_child(stage)
 for batch in 6:
  var cells: Array[Node] = []
  var models: Array[CastModel] = []
  for row in 12:
   var look := looks[batch*4+row/3]
   for col in 2:
    var part: String = ["head","arm"][col]
    var cell := Node2D.new()
    cell.position = Vector2(105+col*250,100+row*140)
    cell.scale = Vector2.ONE*4.0
    stage.add_child(cell)
    cells.append(cell)
    var model := CastModel.create(look)
    cell.add_child(model)
    var applied: int = preload("res://tools/saved_sever_candidate.gd").apply(model,part)
    if applied<=0:
     push_error("Saved cut unavailable: "+look+" "+part)
     Game.request_quit(1)
     return
    model.moving = false
    models.append(model)
    model.set_meta("review_phase",[.15,.5,.995][row%3])
    var label := Label.new()
    label.text = look + " / " + part + " / " + str([.15,.5,.995][row%3])
    label.position = Vector2(20+col*250,110+row*140)
    stage.add_child(label)
    cells.append(label)
  for frame in 8:
   for model in models: model.play_sample("death_back",1.0/60.0,model.get_meta("review_phase"))
   await get_tree().process_frame
  await RenderingServer.frame_post_draw
  stage.get_texture().get_image().save_png("res://build/packed_sever_mesh_candidates/poses_%d.png" % batch)
  for cell in cells: cell.queue_free()
  await get_tree().process_frame
  print("Rendered wound cast batch ",batch)
 Game.request_quit()
