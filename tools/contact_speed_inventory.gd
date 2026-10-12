extends Node
func _ready() -> void:
	for look in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
		if look == "eldorado": continue
		var model := CastModel.create(look) as CastModel
		if model == null: continue
		add_child(model)
		print("CONTACT_SPEED ", look, " ", model._contact_native_speed)
		model.queue_free()
	await get_tree().process_frame
	get_tree().quit()
