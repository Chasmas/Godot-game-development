extends Node2D
func _ready() -> void:
	var previous := Gore.level()
	SaveManager.settings["gore"] = 2
	var fx := Effects.new()
	add_child(fx)
	var wall := StaticBody2D.new()
	wall.position = Vector2(20,0)
	wall.collision_layer = Layers.WORLD
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2,100)
	shape.shape = rectangle
	wall.add_child(shape)
	add_child(wall)
	var gib := Gore.Gib.new()
	gib.kind = "arm"
	gib.position = Vector2(17,0)
	gib.velocity = Vector2(500,0)
	add_child(gib)
	gib.set_process(false)
	for i in 2: await get_tree().physics_frame
	gib._process(0.05)
	var ok := gib.velocity.x < 0.0 and gib.position.x <= 17.01 and gib._trail < 0.01
	ok = ok and int(wall.get_meta("blood_stain_count",0)) == 1 and fx.decals.blood_chunks.is_empty()
	print("GIB IMPACT REVIEW: ", "0 failures" if ok else "1 failure", " position=",gib.position," velocity=",gib.velocity," trail=",gib._trail)
	SaveManager.settings["gore"] = previous
	Audio.shutdown()
	get_tree().quit(0 if ok else 1)
