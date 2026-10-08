extends Node2D
func _ready() -> void:
 seed(71)
 var previous_gore := Gore.level()
 SaveManager.settings["gore"]=2
 var output := "res://build/runtime_sever_review"
 DirAccess.make_dir_recursive_absolute(output)
 var looks := DirAccess.get_directories_at("res://assets/art/cast3d_rt")
 looks.remove_at(looks.find("eldorado"))
 var stage := SubViewport.new()
 stage.size=Vector2i(960,960)
 stage.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(stage)
 var warm_start := Time.get_ticks_usec()
 preload("res://scripts/player/sever_meshes.gd").prefetch(Array(looks))
 var prefetch_us := Time.get_ticks_usec()-warm_start
 var failures := 0
 var timings: Array = []
 for batch in 4:
  var floor := ColorRect.new()
  floor.color=Color("77716d")
  floor.size=Vector2(960,960)
  floor.z_index=-20
  stage.add_child(floor)
  var fx := Effects.new()
  stage.add_child(fx)
  var cells: Array[Node] = [fx,floor]
  for row in 6:
   var look: String = looks[batch*6+row]
   for col in 4:
    var part: String = ["head","arm","leg","legs"][col]
    var cell := Node2D.new()
    cell.position=Vector2(80+col*230,85+row*155)
    cell.scale=Vector2.ONE*3.0
    stage.add_child(cell)
    cells.append(cell)
    var body := Corpse.new()
    var start := Time.get_ticks_usec()
    body.setup(look,Vector2.LEFT,look=="cass",part,0.0)
    timings.append(Time.get_ticks_usec()-start)
    cell.add_child(body)
    if body._cast==null or body._cast.get_meta("authored_sever_part","")!=part:
     failures+=1
     push_error("Runtime sever not applied: "+look+" "+part)
    for step in 33: body._process(0.1)
    if body._bleed_left>0.0 or not body._pooled: failures+=1
    body.set_process(false)
    var gib := Gore.Gib.new()
    gib.kind="leg" if part=="legs" else part
    gib.palette=look
    gib.position=Vector2(16,18)
    cell.add_child(gib)
    gib.set_process(false)
    var label := Label.new()
    label.text=look+" / "+part
    label.position=Vector2(15+col*230,135+row*155)
    stage.add_child(label)
    cells.append(label)
  if fx.pools.pools.size()!=24: failures+=1
  for step in 35: fx.pools._process(0.1)
  for frame in 10: await get_tree().process_frame
  await RenderingServer.frame_post_draw
  stage.get_texture().get_image().save_png(output+"/cast_%d.png" % batch)
  for cell in cells: cell.queue_free()
  await get_tree().process_frame
  print("Rendered runtime corpses and gibs batch ",batch)
 timings.sort()
 var file := FileAccess.open(output+"/review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scope":"Actual Corpse.setup/_process and Gore.Gib rendering across 24 looks x four cuts. Manual 3.3-second corpse advance; screenshots and authored mesh markers checked. Not full combat or frame-time benchmark.","failures":failures,"cases":96,"prefetch_us":prefetch_us,"gore_mode_tested":2,"setup_median_us":timings[timings.size()/2],"setup_max_us":timings[-1]},"  "))
 SaveManager.settings["gore"]=previous_gore
 Game.request_quit(1 if failures else 0)
