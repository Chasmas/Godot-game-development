extends Node2D
var models: Array=[]
func _ready() -> void:
 RenderingServer.set_default_clear_color(Color("191622"))
 var stage:=SubViewport.new()
 stage.size=Vector2i(1100,720)
 stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(stage)
 for row in 3:
  for col in 3:
   var cell:=Node2D.new()
   cell.position=Vector2(110+col*215,190+row*220)
   cell.scale=Vector2.ONE*4.
   stage.add_child(cell)
   var look: String = ["cass","heavy","guard"][col]
   var part: String = ["arm","arm","head"][col]
   var model:=CastModel.create(look)
   cell.add_child(model)
   var caps: int = preload("res://tools/wound_candidate_binding.gd").attach(model,look,part)
   var cap_nodes: Array = []
   for cap in model._model.find_children("*", "MeshInstance3D", true, false):
    if not cap.get_meta("wound_candidate",false): continue
    cap_nodes.append([cap,cap.get_parent()])
    cap.get_parent().remove_child(cap)
   model.sever_part(part)
   for entry in cap_nodes: entry[1].add_child(entry[0])
   print(look," ",part," attached candidates=",caps)
   model.moving=false
   model.move_speed=[118.,191.,65.][row]
   model.move_angle=0.
   models.append([model,"death_back",[.15,.5,.995][row]])
   var label:=Label.new()
   label.text = look + " / " + part + " / " + str([.15,.5,.995][row])
   label.position=Vector2(25+col*215,210+row*220)
   stage.add_child(label)
 for frame in 20:
  for item in models:
   item[0].play_sample(item[1],1./60.,item[2])
  await get_tree().process_frame
 await RenderingServer.frame_post_draw
 stage.get_texture().get_image().save_png("res://build/wound_surface_candidates/binding_visual.png")
 Game.request_quit()
