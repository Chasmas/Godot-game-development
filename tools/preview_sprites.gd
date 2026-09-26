extends SceneTree
## Dev tool: renders every procedural sprite into a PNG sheet.
## godot --headless --path . --script tools/preview_sprites.gd

func _init() -> void:
	var scale := 6
	var items: Array = []
	for pal in ["cass", "guard", "gunner", "hunter", "heavy", "scout", "riot", "boss"]:
		for pose in SpriteLib.TORSO.keys():
			items.append([SpriteLib.torso(pose, pal), SpriteLib.legs(1, pal)])
		items.append([SpriteLib.corpse(pal), null])
		items.append([SpriteLib.downed(pal), null])
	for k in SpriteLib.WEAPONS.keys():
		items.append([SpriteLib.weapon(k), null])
	var cols := 10
	var cell := 26 * scale
	var rows := int(ceil(items.size() / float(cols)))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.22, 0.2, 0.26))
	for i in items.size():
		var cx := (i % cols) * cell
		var cy := (i / cols) * cell
		for layer in [1, 0]:
			var tex: Texture2D = items[i][layer]
			if tex == null:
				continue
			var img := tex.get_image()
			img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(cx + 4, cy + 4))
	sheet.save_png(OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/sprites.png")
	quit()
