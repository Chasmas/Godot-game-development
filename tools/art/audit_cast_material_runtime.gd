extends Node

func _ready() -> void:
	var failures := 0
	for id in ["cass", "guard", "bellhop", "civilian", "zombie"]:
		var cast := CastModel.new()
		var source := "res://assets/art/cast3d_rt/%s/%s.glb" % [id, id]
		if not cast.configure(id, source):
			push_error("Character configuration failed: " + id)
			failures += 1
			cast.free()
			continue
		add_child(cast)
		var checked := 0
		for mesh in cast._model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material == null:
					continue
				if material.texture_filter != BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
					failures += 1
				for field in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture"]:
					var texture := material.get(field) as Texture2D
					if texture != null:
						checked += 1
						if not texture.get_image().has_mipmaps():
							failures += 1
		if checked == 0:
			failures += 1
		print("CAST MATERIAL RUNTIME: %s, %d textures" % [id, checked])
		cast.queue_free()
		await get_tree().process_frame
	print("CAST MATERIAL RUNTIME DONE: %d failures" % failures)
	Game.request_quit(1 if failures else 0)
