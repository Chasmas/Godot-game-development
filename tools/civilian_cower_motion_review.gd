extends Node
func _ready()->void:
 var stage := SubViewport.new()
 stage.size = Vector2i(640,220)
 stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 add_child(stage)
 var bg := ColorRect.new()
 bg.color = Color("292430")
 bg.size = Vector2(640,220)
 bg.z_index = -10
 stage.add_child(bg)
 var bodies: Array[CastModel] = []
 for i in 4:
  var cast := CastModel.new()
  if not cast.configure("civilian","res://build/civilian_cower_review/civilian_cower.glb"):
   Game.request_quit(1)
   return
  var rig := Node2D.new()
  rig.position = Vector2(80+i*160,175)
  rig.rotation = i*PI*.5
  stage.add_child(rig)
  rig.add_child(cast)
  cast.scale = Vector2.ONE*3
  cast.rotation = 0
  bodies.append(cast)
 DirAccess.make_dir_recursive_absolute("res://build/civilian_cower_review/motion")
 for frame in 37:
  var progress := frame/36.0
  for cast in bodies: cast.play_sample("cower",1.0/30.0,progress)
  if frame in [0,5,10,20,36]:
   var cast := bodies[0]
   for bone_name in ["RightHand","LeftHand","RightForeArm","LeftForeArm"]:
    var bone := cast._skeleton.find_bone(bone_name)
    print("COWER_RUNTIME_BONE ",frame," ",bone_name," ",cast._skeleton.get_bone_global_pose(bone).origin)
  await get_tree().process_frame
  await RenderingServer.frame_post_draw
  stage.get_texture().get_image().save_png("res://build/civilian_cower_review/motion/%03d.png" % frame)
 print("CIVILIAN COWER MOTION: 37 frames, four directions")
 Game.request_quit(0)