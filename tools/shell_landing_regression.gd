extends Node

func _ready() -> void:
	var fx := Effects.new()
	add_child(fx)
	for index in 60:
		fx.shells.eject(Vector2(index, 40), Vector2.RIGHT, false, index % 2 == 0)
	fx.shells.set_process(false)
	for frame in 180:
		await get_tree().physics_frame
		fx.shells._process(1.0 / 60.0)
	var landed := 0
	var dots := 0
	for chunk in fx.decals.chunks:
		landed += chunk.shells.size()
		dots += chunk.marks.size()
	var valid := landed == 60 and fx.shells.items.is_empty() and dots == 0
	print("SHELL LANDING REGRESSION: landed=", landed, " airborne=", fx.shells.items.size(), " legacy dots=", dots)
	fx.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if valid else 1)
