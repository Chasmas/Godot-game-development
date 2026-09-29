extends Node
## Dev probe: the calm / combat switching of a level's music.
func _ready() -> void:
	await get_tree().process_frame
	Music.play("motel")
	for i in 30:
		await get_tree().process_frame
	print("PROBE start: ", Music.current_id)
	Music.set_intensity(1)
	for i in 60:
		await get_tree().process_frame
	print("PROBE combat: ", Music.current_id, " outgoing ", Music._outgoing.size())
	Music.set_intensity(0)
	var t0 := Time.get_ticks_msec()
	while Music.current_id != "motel_stealth" and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	print("PROBE calm again after %.1fs: %s" % [(Time.get_ticks_msec() - t0) / 1000.0, Music.current_id])
	Music.play("aftermath")
	await get_tree().process_frame
	print("PROBE aftermath: ", Music.current_id)
	get_tree().quit()
