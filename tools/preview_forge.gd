extends SceneTree
func _init():
	var pals := ["cass", "guard", "gunner", "hunter", "heavy", "scout", "riot", "boss"]
	var poses := ["unarmed", "aim_one", "aim_two", "melee", "punch_r"]
	var sc := 5
	var sheet := Image.create((poses.size() + 2) * 50 * sc / 2 + 60, pals.size() * 36 * sc / 2 * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.3, 0.28, 0.34))
	for pi in pals.size():
		for k in poses.size() + 1:
			var layers := []
			if k < poses.size():
				layers = [SpriteForge.legs(1, pals[pi]).get_image(), SpriteForge.torso(poses[k], pals[pi]).get_image()]
			else:
				layers = [SpriteForge.corpse(pals[pi]).get_image()]
			for L in layers:
				var img: Image = L.duplicate()
				img.resize(img.get_width() * sc, img.get_height() * sc, Image.INTERPOLATE_NEAREST)
				sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(10 + k * 34 * sc, 10 + pi * 34 * sc))
	sheet.save_png(OS.get_environment("OUT"))
	quit()
