extends Node2D

func _ready() -> void:
	var model := CastModel.create("cass") as CastModel
	assert(model != null)
	add_child(model)
	model.apply_contact_locomotion(load("res://build/locomotion_candidates/cass/cass_moderate_sneak_staging.res") as AnimationLibrary)
	model._viewport.size = Vector2i(512, 512)
	model.crouch_pistol_pose = true
	DirAccess.make_dir_recursive_absolute("res://build/cass_moderate_sneak_review")
	for phase in [0.0, 0.25, 0.5, 0.75]:
		model.play_sample("armed_sneak", 0.2, phase)
		await RenderingServer.frame_post_draw
		model._viewport.get_texture().get_image().save_png("res://build/cass_moderate_sneak_review/armed_sneak_%02d.png" % roundi(phase * 100.0))
	print("CASS MODERATE SNEAK ARMED CAPTURE PASSED")
	Game.request_quit()
