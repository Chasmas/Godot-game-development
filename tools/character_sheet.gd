extends SceneTree
## Dev tool: every character as it appears in game (legs + torso + weapon),
## scaled up for review. Row per palette, columns per pose.
##   godot --headless --path . --script tools/character_sheet.gd  (OUT=/path.png)

const PALS := ["cass", "guard", "gunner", "hunter", "heavy", "scout", "riot", "boss", "civilian"]
const POSES := [["unarmed", ""], ["aim_one", "pistol"], ["aim_two", "shotgun"], ["melee", "bat"], ["aim_dual", "pistol"]]

func _init() -> void:
	var sc := 4
	var cell := 68 * sc
	var sheet := Image.create(POSES.size() * cell, PALS.size() * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.16, 0.15, 0.2))
	for r in PALS.size():
		var pal: String = PALS[r]
		for c in POSES.size():
			var pose: String = POSES[c][0]
			# textures are 2x (drawn at 0.5 in game): compose at 2x world scale
			var canvas := Image.create(68, 68, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0.24, 0.22, 0.28))
			var legs := SpriteLib.legs(1, pal).get_image().duplicate() as Image
			canvas.blend_rect(legs, Rect2i(Vector2i.ZERO, legs.get_size()), Vector2i(18, 18))
			var torso := SpriteLib.torso(pose, pal).get_image().duplicate() as Image
			canvas.blend_rect(torso, Rect2i(Vector2i.ZERO, torso.get_size()), Vector2i(18, 18))
			var wkey: String = POSES[c][1]
			if wkey != "":
				var wimg := SpriteLib.weapon(wkey).get_image().duplicate() as Image
				wimg.resize(wimg.get_width() * 2, wimg.get_height() * 2, Image.INTERPOLATE_NEAREST)
				var hand := SpriteForge.hand_world("aim_dual" if pose == "aim_dual" else pose)
				canvas.blend_rect(wimg, Rect2i(Vector2i.ZERO, wimg.get_size()), Vector2i(34 + int(hand.x * 2) - 4, 34 + int(hand.y * 2) - wimg.get_height() / 2))
				if pose == "aim_dual":
					var w2 := wimg.duplicate()
					w2.flip_y()
					var h2 := SpriteForge.hand_world("aim_dual_l")
					canvas.blend_rect(w2, Rect2i(Vector2i.ZERO, w2.get_size()), Vector2i(34 + int(h2.x * 2) - 4, 34 + int(h2.y * 2) - w2.get_height() / 2))
			canvas.resize(68 * sc, 68 * sc, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(canvas, Rect2i(0, 0, 68 * sc, 68 * sc), Vector2i(c * cell, r * cell))
	sheet.save_png(OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/characters.png")
	quit()
