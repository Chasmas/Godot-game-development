extends Node

const STAGING_LIBRARY := "res://build/locomotion_candidates/cass/cass_moderate_sneak_staging.res"
const OUTPUT := "res://build/cass_moderate_sneak_review/armed_weapon_grid.png"

func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	var stage := SubViewport.new()
	stage.size = Vector2i(1024, 512)
	stage.transparent_bg = false
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var background := ColorRect.new()
	background.color = Color("181622")
	background.size = Vector2(stage.size)
	stage.add_child(background)
	var library := load(STAGING_LIBRARY) as Resource
	if library == null:
		push_error("Missing Cass staging locomotion library")
		get_tree().quit(1)
		return
	for pose_index in 4:
		var cell := Node2D.new()
		cell.position = Vector2(128 + pose_index * 256, 244)
		cell.scale = Vector2.ONE * 4.2
		stage.add_child(cell)
		var visual := CharacterVisual.new()
		cell.add_child(visual)
		visual.setup("cass")
		var cast := visual.cast_sprite as CastModel
		cast.apply_contact_locomotion(library)
		visual.set_weapon(DB.weapon(&"pistol"))
		visual.set_process(false)
		visual.set_aim(0.0)
		visual.update_move(Vector2.RIGHT * 20.0, 0.0, true, false)
		for frame in 24:
			cast.play_sample("armed_sneak", 1.0 / 60.0, (float(pose_index) + float(frame) / 24.0) / 4.0)
			visual._process_cast(0.0)
		var label := Label.new()
		label.text = "ARMED SNEAK  %d%%" % (pose_index * 25)
		label.position = Vector2(29 + pose_index * 256, 426)
		label.add_theme_font_size_override("font_size", 18)
		stage.add_child(label)
	for frame in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := stage.get_texture().get_image().save_png(OUTPUT)
	stage.queue_free()
	print("CASS ARMED SNEAK WEAPON CAPTURE ", "PASSED" if error == OK else "FAILED")
	get_tree().quit(0 if error == OK else 1)
