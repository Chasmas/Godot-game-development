extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	print("PASS " if ok else "FAIL ", message)

func _ready() -> void:
	var rig := Node2D.new()
	add_child(rig)
	var model := CastModel.create("cass") as CastModel
	var source := OS.get_environment("COMBAT_REVIEW_MODEL")
	if source != "":
		model.free()
		model = CastModel.new()
		if not model.configure("cass", source):
			get_tree().quit(1)
			return
	rig.add_child(model)
	var clips := ["punch", "punch_left", "melee", "grab", "held"]
	if model.clips.has("stab"):
		clips.append("stab")
	for clip_name in clips:
		var left: bool = clip_name == "punch_left"
		var points: Array[Vector2] = []
		for i in 101:
			model.play_sample(clip_name, 1.0 / 60.0, float(i) / 100.0)
			points.append(model.grip(left))
		var reach := 0.0
		var peak := 0
		for i in points.size():
			var distance := points[i].distance_to(points[0])
			if distance > reach:
				reach = distance
				peak = i
		check(reach > 3.0, clip_name + " has a visible hand stroke")
		check(points[0].distance_to(points[-1]) < 1.0, clip_name + " recovers its starting hand pose")
		if clip_name.begins_with("punch"):
			# A held contact pose can have a later numerical maximum from tiny IK drift.
			# Validate actual extension at the damage frame, not the first maximum index.
			var contact_index := roundi(CharacterVisual.PUNCH_CONTACT * 100.0)
			var contact_reach := points[contact_index].distance_to(points[0])
			check(contact_reach >= reach * 0.98, clip_name + " is fully extended at damage contact")
		if clip_name == "stab":
			check(peak >= 57 and peak <= 67, "knife reaches contact at its damage timing")
		print(clip_name, " reach=", reach, " peak=", peak, " endpoint gap=", points[0].distance_to(points[-1]))
	for kind in ["punch", "knife", "bat"]:
		for direction in 8:
			var visual := CharacterVisual.new()
			rig.add_child(visual)
			visual.setup("cass")
			visual.set_process(false)
			visual.set_weapon(null if kind == "punch" else DB.weapon(StringName(kind)))
			var angle := direction * TAU / 8.0
			visual.set_aim(angle)
			if kind == "punch":
				visual.punch()
			else:
				visual.swing(false, kind == "knife")
			check(not visual._arm.visible, "attack start does not flash a fallback arm")
			visual.set_aim(angle + PI)
			visual._process_cast(0.0)
			check(absf(angle_difference(visual.rig.rotation, angle)) < 0.001, "%s %d: body preserves committed contact direction while aim changes" % [kind, direction])
			check(not visual._arm.visible, "authored attack has no fallback arm")
			var trail := Effects.SlashFX.new()
			trail.driver = visual
			trail.attack_serial = visual.attack_serial
			trail.driver_offset = Vector2(3, 0)
			rig.add_child(trail)
			trail.set_process(false)
			if kind == "punch":
				visual._punch_t = CharacterVisual.PUNCH_DURATION * 0.53
			else:
				visual._swing_t = visual._swing_dur * 0.62
			visual.position += Vector2(20, 10)
			trail._process(0.0)
			check(trail.attack_progress > 0.5 and trail.global_position.is_equal_approx(visual.global_position + trail.driver_offset), "trail follows attack phase and moving body")
			if kind == "bat":
				check(visual._swing_dir == 1.0, "trail direction matches authored Blender arc")
			visual.roll(Vector2.RIGHT, 0.3)
			visual._process_cast(0.0)
			check(not visual.is_swinging() and visual._punch_t < 0.0, "roll releases committed attack")
			trail._process(0.0)
			check(trail.is_queued_for_deletion(), "roll cancels the attack trail")
			visual.queue_free()
	model.queue_free()
	await get_tree().process_frame
	print("COMBAT ANIMATION REGRESSION: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
