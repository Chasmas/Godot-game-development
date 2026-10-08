extends Node2D
func _ready() -> void:
	get_window().size = Vector2i(960, 540)
	var player := Player.new()
	add_child(player)
	player.setup(CharacterData.new())
	player.set_physics_process(false)
	player.slots[0] = WeaponInstance.create(DB.weapon(&"chainsaw"))
	player._refresh_weapon()
	player.position = Vector2(440, 250)
	player.scale = Vector2.ONE * 8.0
	player.visual.set_aim(0.0)
	player.visual.idle_fidgets = false
	for i in 30: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/chainsaw_held_visual.png")
	Audio.shutdown()
	get_tree().quit()
