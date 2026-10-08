extends Node2D
var models: Array=[]
func _ready() -> void:
 RenderingServer.set_default_clear_color(Color("191622"))
 var stage:=SubViewport.new()
 stage.size=Vector2i(1000,720)
 stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(stage)
 for row in 3:
  for col in 3:
   var cell:=Node2D.new()
   cell.position=Vector2(140+col*310,190+row*220)
   cell.scale=Vector2.ONE*7.
   stage.add_child(cell)
   var look := OS.get_environment("CUT_VISUAL_LOOK")
   var part := "legs"
   var model := CastModel.create(look)
   cell.add_child(model)
   var caps := 0
   if col > 0:
    preload("res://tools/anatomical_cut_candidate.gd").cut(model,part)
   if col == 2:
    caps = preload("res://tools/wound_candidate_binding.gd").attach(model,look,part)
   print(look," ",part," attached candidates=",caps)
   model.moving=false
   model.move_speed=[118.,191.,65.][row]
   model.move_angle=0.
   models.append([model,"death_back",[.15,.5,.995][row]])
   var label:=Label.new()
   label.text = ["Intact","Joint cut","Joint cut + wound"][col] + " / " + str([.15,.5,.995][row])
   label.position=Vector2(25+col*310,210+row*220)
   stage.add_child(label)
 for frame in 20:
  for item in models:
   item[0].play_sample(item[1],1./60.,item[2])
  await get_tree().process_frame
 await RenderingServer.frame_post_draw
 stage.get_texture().get_image().save_png("res://build/odd_joint_wound_candidates/" + OS.get_environment("CUT_VISUAL_LOOK") + "_comparison.png")
 Game.request_quit()
