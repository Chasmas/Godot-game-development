extends SceneTree
## Paints every character texture (all palettes x variants x poses, legs,
## downed and corpse versions) and saves them as PNGs in
## res://assets/characters/baked/, which SpriteForge loads instead of
## painting at runtime. Re-run after changing SpriteForge or palettes:
##   godot --headless --path . --script tools/bake_sprites.gd
## then run the editor or `godot --headless --import` once to import them.

func _init() -> void:
	SpriteForge.bake_disabled = true
	var dir := ProjectSettings.globalize_path(SpriteForge.BAKE_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var looks: Array[String] = []
	for pal in SpriteLib.PALETTES.keys():
		looks.append(pal)
		if pal in ["guard", "gunner", "hunter", "scout", "heavy", "civilian"]:   # = Enemy.VARIED_PALETTES
			for v in range(1, 4):
				looks.append("%s#%d" % [pal, v])
	var n := 0
	var t0 := Time.get_ticks_msec()
	for look in looks:
		var jobs: Array = []
		for pose in SpriteForge.PREWARM_POSES + ["aim_dual"]:
			jobs.append(["t|%s|%s" % [look, pose], SpriteForge.torso(pose, look)])
		for f in 3:
			jobs.append(["l|%s|%d" % [look, f], SpriteForge.legs(f, look)])
		for downed in [true, false]:
			jobs.append(["c|%s|%s" % [look, downed], SpriteForge.corpse(look, downed)])
		for missing in ["head", "arm"]:
			jobs.append(["c|%s|%s|%s" % [look, false, missing], SpriteForge.corpse(look, false, missing)])
		for j in jobs:
			var tex: Texture2D = j[1]
			tex.get_image().save_png(ProjectSettings.globalize_path(SpriteForge.baked_path(j[0])))
			n += 1
	print("baked %d textures for %d looks in %d ms" % [n, looks.size(), Time.get_ticks_msec() - t0])
	quit()
