extends Node2D
var failures:=0
func check(ok: bool,message: String) -> void:
 if not ok: failures+=1
 print("PASS " if ok else "FAIL ",message)
func _ready() -> void:
 var effects:=Effects.new()
 add_child(effects)
 SaveManager.settings["gore"]=2
 var wall:=StaticBody2D.new()
 wall.position=Vector2(40,0)
 wall.collision_layer=Layers.WORLD
 var shape:=CollisionShape2D.new()
 var box:=RectangleShape2D.new()
 box.size=Vector2(8,100)
 shape.shape=box
 wall.add_child(shape)
 add_child(wall)
 await get_tree().physics_frame
 Gore._surface_splatter(Vector2.ZERO,Vector2.RIGHT,2.)
 check(wall.get_child_count()>1,"Blood rays attach to real wall")
 var stain:=wall.get_child(1) as Node2D
 var before:=stain.global_position
 wall.position+=Vector2(10,20)
 check(stain.global_position.distance_to(before+Vector2(10,20))<.001,"Stain follows moving surface")
 await get_tree().create_timer(.15).timeout
 check(is_instance_valid(stain) and not stain.is_processing(),"Stain persists without continuous processing")
 for i in 40: Gore.attach_surface_blood(wall,wall.global_position,Vector2.LEFT,2.)
 check(int(wall.get_meta("blood_stain_count"))==32 and is_instance_valid(stain),"Stain limit preserves existing blood")
 if DisplayServer.get_name()!="headless":
  position=Vector2(500,300)
  scale=Vector2.ONE*4.
  var paint:=Polygon2D.new()
  paint.polygon=PackedVector2Array([Vector2(-4,-50),Vector2(4,-50),Vector2(4,50),Vector2(-4,50)])
  paint.color=Color("797060")
  paint.z_index=-1
  wall.add_child(paint)
  for frame in 5: await get_tree().process_frame
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://build/surface_blood_visual.png")
 SaveManager.settings["gore"]=0
 check(Gore.attach_surface_blood(wall,wall.global_position,Vector2.LEFT,2.)==null,"Gore off creates no surface blood")
 SaveManager.settings["gore"]=1
 var info:=DamageInfo.new()
 info.set_meta("finisher","skull")
 check(Gore.on_kill(Vector2.ZERO,info,"guard",Vector2.ZERO)=="","Reduced gore retains complete corpse")
 SaveManager.settings["gore"]=2
 check(Gore.on_kill(Vector2.ZERO,info,"guard",Vector2.ZERO)=="head","Full gore removes exploded head from corpse")
 effects.decals.add_splat(Vector2(100,100),3.,Gore.BLOOD)
 var first_batch=effects.decals.blood_chunks[0]
 var first_mark=first_batch.splats[0].duplicate(true)
 for i in Effects.MAX_DECALS+200:
  effects.decals.add_mark(Vector2(i,0),Color.BLACK,1.)
  effects.decals.add_splat(Vector2(i,10),2.,Gore.BLOOD)
 await get_tree().process_frame
 check(is_instance_valid(first_batch) and first_batch.splats[0]==first_mark,"Floor blood survives debris budget overflow")
 print("SURFACE BLOOD REVIEW: ",failures," failures")
 Game.request_quit(1 if failures else 0)
