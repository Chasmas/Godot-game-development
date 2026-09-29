extends SceneTree
## Exports one look's poses as a 4x2 grid for the painter (tools/art/repaint_sheet.py):
##   godot --headless --path . --script tools/export_pose_sheet.gd -- <look> <out.png>
## Cells (384 px each, the 64 px pose scaled up, nearest):
##   unarmed, aim_one, aim_two, aim_dual / melee, punch_l, legs0, legs1

const CELL := 384
const POSES := ["unarmed", "aim_one", "aim_two", "aim_dual", "melee", "punch_l", "legs0", "legs1"]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var look: String = args[0] if args.size() > 0 else "cass"
	var out: String = args[1] if args.size() > 1 else "user://sheet.png"
	SpriteForge.bake_disabled = true
	var sheet := Image.create(CELL * 4, CELL * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	for i in POSES.size():
		var p: String = POSES[i]
		var tex: Texture2D
		if p.begins_with("legs"):
			tex = SpriteForge.legs(int(p.substr(4)) + 1, look)
		else:
			tex = SpriteForge.torso(p, look)
		var img := tex.get_image()
		var k := float(CELL) / float(img.get_width()) * 0.9
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_NEAREST)
		var at := Vector2i((i % 4) * CELL + (CELL - img.get_width()) / 2, (i / 4) * CELL + (CELL - img.get_height()) / 2)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(out)
	print("sheet ", look, " -> ", out)
	quit()
