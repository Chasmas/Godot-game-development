extends SceneTree
## Writes plain top-down rig torsos as repaint guides for PixelLab.
## Same 64 px canvas, shoulders and hand coordinates as the runtime pose layers,
## so a repaint that keeps the silhouette also keeps the weapon grip.
## Usage: godot --headless --path . --script tools/art/topdown_pose_guides.gd

const OUT := "C:/tmp_shots/topdown_pose_guides"
const LOOKS := ["guard", "civilian", "welder", "security", "bellhop", "biker", "gunner", "handler", "heavy", "hunter", "riot", "scout", "scrapper", "sniper", "stagehand"]
const POSES := ["unarmed", "aim_one", "aim_two", "melee"]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	SpriteForge.bake_disabled = true
	SpriteForge.plain_topdown = true
	var count := 0
	for look in LOOKS:
		for pose in POSES:
			var tex := SpriteForge.torso(pose, look)
			if tex == null:
				push_error("no torso for %s %s" % [look, pose])
				continue
			tex.get_image().save_png("%s/%s_%s.png" % [OUT, look, pose])
			count += 1
	print("topdown_guides=%d" % count)
	quit()
