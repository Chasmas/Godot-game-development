extends Node

## Runtime regression review for the public Music transport.  It validates
## calm/combat swaps, cross-track cleanup, and stem-aligned jukebox seeking.

func _ready() -> void:
	await get_tree().process_frame
	Music.stop(0.0)
	Music.set_intensity(0, true)
	var failures := 0
	Music.play("motel", true, 0.0)
	for frame in 3: await get_tree().process_frame
	var calm_ok := Music.current_id == "motel_stealth" and Music._base_id == "motel"
	if not calm_ok: failures += 1
	print("PASS " if calm_ok else "FAIL ", "motel starts on its calm instrumental companion")
	Music.set_intensity(1, true)
	Music._calm_switch(.1)
	for frame in 3: await get_tree().process_frame
	var combat_ok := Music.current_id == "motel" and not Music._outgoing.is_empty()
	if not combat_ok: failures += 1
	print("PASS " if combat_ok else "FAIL ", "combat crossfades back to motel score")
	var source := Music._players[0]
	var extra := AudioStreamPlayer.new()
	extra.bus = "Music"
	extra.stream = source.stream
	Music.add_child(extra)
	extra.play()
	Music._players.append(extra)
	Music._targets.append(1.0)
	Music._levels.append(1.0)
	Music.seek_playback(1.25)
	for frame in 2: await get_tree().process_frame
	var seek_ok := absf(Music._players[0].get_playback_position() - Music._players[1].get_playback_position()) < .08
	if not seek_ok: failures += 1
	print("PASS " if seek_ok else "FAIL ", "jukebox seek keeps every active music stem aligned")
	Music.play("boss", true, .12)
	for frame in 2: await get_tree().process_frame
	var change_ok := Music.current_id == "boss" and not Music._outgoing.is_empty()
	if not change_ok: failures += 1
	print("PASS " if change_ok else "FAIL ", "cross-track transition retains an outgoing fade")
	# The calm-to-combat transition uses its production 0.35-second fade, so
	# wait beyond that longest outgoing envelope before asserting cleanup.
	await get_tree().create_timer(.5).timeout
	var cleanup_ok := Music._outgoing.is_empty() and Music.current_id == "boss"
	if not cleanup_ok: failures += 1
	print("PASS " if cleanup_ok else "FAIL ", "outgoing music players release after fade")
	Music.stop(0.0)
	# stop() frees players deferred; allow their queue_free notifications to run
	# before ending this isolated review so its shutdown stays clean.
	for frame in 2: await get_tree().process_frame
	print("MUSIC TRANSITION REVIEW: ", failures, " failures")
	get_tree().quit(1 if failures else 0)
