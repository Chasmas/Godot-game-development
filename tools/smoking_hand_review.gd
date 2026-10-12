extends Node
func _ready() -> void:
	var report: Array=[]
	DirAccess.make_dir_recursive_absolute("res://build/smoking_review")
	for id in DirAccess.get_directories_at("res://assets/art/cast3d_rt"):
		if id=="eldorado":continue
		var model:=CastModel.create(id) as CastModel
		if model==null:continue
		var rig:=Node2D.new()
		add_child(rig)
		rig.add_child(model)
		if not model._player.has_animation("smoke"):model.queue_free();continue
		var best: Array=[INF,INF]
		for step in 33:
			model.play_sample("smoke",0,step/33.0)
			model._skeleton.force_update_all_bone_transforms()
			var head:=model._skeleton.get_bone_global_pose(model._head).origin
			for hand in 2:
				var point:=model._skeleton.get_bone_global_pose(model._hand_bones[hand]).origin
				best[hand]=minf(best[hand],point.distance_to(head)*.01)
		report.append({"cast":id,"nearest_head_metres":best,"left_active":best[1]<best[0]})
		if id=="guard":
			for facing in 8:
				model.get_parent().rotation=facing*PI/4
				model.play_sample("smoke",0,.7)
				await RenderingServer.frame_post_draw
				model._viewport.get_texture().get_image().save_png("res://build/smoking_review/guard_%d.png" % facing)
		model.queue_free()
	var file:=FileAccess.open("res://build/smoking_hand_review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("SMOKING HAND REVIEW ",report)
	Game.request_quit(0)
