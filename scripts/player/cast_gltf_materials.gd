extends RefCounted
## Direct GLTF loads may supply texture images without mipmaps.
## Prepare local material copies so small character viewports do not shimmer.

static func prepare(model: Node, texture_filter: int = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS) -> Dictionary:
	var textures := {}
	var prepared_surfaces := 0
	var generated_mipmaps := 0
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
						generated_mipmaps += 1
				material.set(field, textures[key])
			material.texture_filter = texture_filter
			mesh.set_surface_override_material(surface, material)
			prepared_surfaces += 1
	return {"prepared_surfaces":prepared_surfaces, "unique_textures":textures.size(), "generated_mipmaps":generated_mipmaps}
