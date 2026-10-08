extends Node
func _ready()->void:
 var stage:=SubViewport.new()
 stage.size=Vector2i(1024,512)
 stage.transparent_bg=false
 stage.own_world_3d=true
 stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(stage)
 var world:=WorldEnvironment.new()
 var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.background_color=Color("17131f")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color.WHITE
 env.ambient_light_energy=.5
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 world.environment=env
 stage.add_child(world)
 for i in 2:
  var document:=GLTFDocument.new()
  var state:=GLTFState.new()
  var name:String=["can","donut"][i]
  if document.append_from_file("res://build/idle_consumables_candidate/"+name+".glb",state)!=OK:
   get_tree().quit(1)
   return
  var model:=document.generate_scene(state) as Node3D
  model.position.x=-.085 if i==0 else .085
  stage.add_child(model)
 var camera:=Camera3D.new()
 stage.add_child(camera)
 camera.position=Vector3(.05,.17,.30)
 camera.look_at(Vector3(0,.05,0))
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=.23
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-50,-30,0)
 light.light_energy=1.5
 stage.add_child(light)
 for frame in 5:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var result:=stage.get_texture().get_image().save_png("res://build/idle_consumables_candidate/godot_material_review.png")
 print("CONSUMABLE MATERIAL REVIEW: ",result)
 get_tree().quit(result)
