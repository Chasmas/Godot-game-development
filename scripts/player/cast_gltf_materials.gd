extends RefCounted
## Direct GLTF loads may supply texture images without mipmaps.
## Prepare local material copies so small character viewports do not shimmer.

static func prepare(model: Node) -> void:
	var textures := {}
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as StandardMaterial3D
			for field in ["albedo_texture", "normal_texture", "roughness_texture", "metallic_texture"]:
				var texture := material.get(field) as Texture2D
				if texture == null:
					continue
				var normal_map: bool = field == "normal_texture"
				var key := "%s:%s" % [texture.get_instance_id(), normal_map]
				if not textures.has(key):
					var pixels := texture.get_image()
					if pixels == null:
						continue
					if pixels.has_mipmaps():
						textures[key] = texture
					else:
						pixels = pixels.duplicate()
						if pixels.is_compressed() and pixels.decompress() != OK:
							continue
						if pixels.generate_mipmaps(normal_map) != OK:
							continue
						textures[key] = ImageTexture.create_from_image(pixels)
				material.set(field, textures[key])
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			mesh.set_surface_override_material(surface, material)
