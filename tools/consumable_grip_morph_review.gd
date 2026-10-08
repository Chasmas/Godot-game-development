extends Node
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)
func capture(label: String) -> void:
	if OS.get_environment("CONSUMABLE_CAPTURE_LIFECYCLE")!="1":return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/consumable_lifecycle_visual")
	get_viewport().get_texture().get_image().save_png("res://build/consumable_lifecycle_visual/"+label+".png")
func _ready() -> void:
	await get_tree().process_frame
	var effects := Effects.new()
	add_child(effects)
	var cast := CastModel.new()
	var combined := OS.get_environment("CONSUMABLE_COMBINED_MODEL")
	check(cast.configure("guard",combined if combined!="" else "res://build/consumable_contact_v3_isolated/guard.glb"),"animated guard loads")
	var visual := CharacterVisual.new()
	add_child(visual)
	visual.setup("guard")
	visual.cast_sprite.free()
	visual.cast_sprite=cast
	visual.set_process(false)
	if OS.get_environment("CONSUMABLE_CAPTURE_LIFECYCLE")=="1":
		var camera:=Camera2D.new()
		camera.position=Vector2(0,-7)
		camera.zoom=Vector2.ONE*12
		add_child(camera)
	var rig := visual.rig
	rig.add_child(cast)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	check(document.append_from_file("res://build/consumable_grip_morph/guard_grip.glb",state)==OK,"morph GLB loads")
	var candidate := document.generate_scene(state)
	add_child(candidate)
	var replacement: MeshInstance3D
	for item in candidate.find_children("*","MeshInstance3D",true,false):
		if item.mesh.get_blend_shape_count()>0: replacement=item
	check(replacement!=null,"authored grip morph exists")
	if replacement==null:
		get_tree().quit(1)
		return
	var target: MeshInstance3D
	for item in cast._model.find_children("*","MeshInstance3D",true,false):
		if item.skin and item.skin.get_bind_count()==replacement.skin.get_bind_count(): target=item; break
	check(target!=null,"guard mesh has matching skin binding count")
	if target==null:
		get_tree().quit(1)
		return
	for bind in target.skin.get_bind_count():
		var original_pose := target.skin.get_bind_pose(bind)
		var new_pose := replacement.skin.get_bind_pose(bind)
		var error := original_pose.origin.distance_to(new_pose.origin)
		for axis in 3:
			error=maxf(error,original_pose.basis[axis].distance_to(new_pose.basis[axis]))
		print("BIND_ROUNDTRIP_ERROR ",bind," ",error)
		check(target.skin.get_bind_bone(bind)==replacement.skin.get_bind_bone(bind) and target.skin.get_bind_name(bind)==replacement.skin.get_bind_name(bind) and error < .002,"skin bone matches and native matrix roundtrip error below .002: %d"%bind)
	if failures:
		print("CONSUMABLE GRIP MORPH REVIEW: ",failures," failures; incompatible skin, mesh replacement stopped")
		get_tree().quit(1)
		return
	if combined=="":target.mesh=replacement.mesh
	cast._cache_activity_morphs()
	var morph := target.find_blend_shape_by_name("CanGrip")
	check(morph>=0,"CanGrip accessible in Godot")
	check(is_zero_approx(target.get_blend_shape_value(morph)),"normal hand is default")
	check(cast.attach_drink_prop("res://build/idle_consumables_candidate/can.glb"),"native can attaches to actual cast viewport")
	for heading in 8:
		rig.rotation=heading*PI*.25
		for phase in 24:
			cast.play_sample("drink",0.0,float(phase)/24.0)
			check(is_equal_approx(target.get_blend_shape_value(morph),1.0),"drink grip closes through full cycle")
			check(cast._drink_prop.visible,"native can visible during drink")
		for action in ["aim","walk","punch","smoke","eat"]:
			cast.play_sample("drink",0.0,.33)
			cast.play_sample(action,0.0,.25)
			check(is_zero_approx(target.get_blend_shape_value(morph)),"normal hand restored for "+action)
			check(not cast._drink_prop.visible,"native can hidden outside drink")
	var removed := cast._drink_prop
	cast.clear_drink_prop()
	check(cast._drink_prop==null and not removed.visible,"alert cleanup removes reference and hides can immediately")
	await get_tree().process_frame
	check(not is_instance_valid(removed),"native can freed after cleanup")
	visual.set_weapon(DB.weapon(&"pistol"),true)
	var activity := IdleActivity.new()
	rig.add_child(activity)
	activity.setup(visual,IdleActivity.Kind.DRINK,"native_review","res://build/idle_consumables_candidate/can.glb","res://build/idle_consumables_candidate/idle_can_floor.glb")
	activity.set_process(false)
	check(activity._native_drink and cast._drink_prop!=null,"real idle activity selects native prop")
	activity._t=activity._cycle*.33
	activity._process(0)
	visual._process_cast(0)
	check(cast._drink_prop.visible and not visual.weapon_sprite.visible and not visual.weapon_sprite2.visible,"real drink shows can and puts away both weapons")
	var drop_points:=cast.drink_drop_points()
	var drop_floor:=rig.to_global(drop_points[1])
	await capture("drink")
	activity.drop()
	# Let the real animation blend advance after the interruption. A zero-delta
	# snapshot leaves the former body pose visible while checking the new state.
	for frame in 12:
		visual._process(1.0/60.0)
		await get_tree().process_frame
	check(cast._drink_prop==null and is_zero_approx(target.get_blend_shape_value(morph)),"real alert removes prop and restores hand")
	check(visual.weapon_sprite.visible and visual.weapon_sprite2.visible,"real alert restores both weapons")
	await get_tree().process_frame
	var fallen: IdleActivity.DroppedProp
	for item in effects.get_children():
		if item is IdleActivity.DroppedProp:fallen=item
	check(fallen!=null and fallen._native_model!=null,"alert leaves the detailed native can on floor")
	if fallen:
		fallen.set_process(false)
		check(fallen.start_pos.distance_to(drop_floor)<.001,"native drop starts at actual floor projection")
		check(fallen.draw_lift.length()>1,"native drop retains visible hand height")
		check(fallen._native_model._viewport.render_target_update_mode==SubViewport.UPDATE_ONCE,"fallen can renders once instead of continuously")
		await capture("falling")
		fallen._process(.35)
		check(fallen._native_model.position.length()<.001,"native can settles to floor after fall")
		await capture("settled")
	for child in get_children():child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("CONSUMABLE GRIP MORPH REVIEW: ",failures," failures")
	get_tree().quit(1 if failures else 0)
