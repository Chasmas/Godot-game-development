extends Node
## Ensures every music format used by data/music.json is configured to repeat.

func _ready() -> void:
	await get_tree().process_frame
	Music.stop(0.0)
	var failures := 0
	for track_id_variant in Music.tracks.keys():
		var track_id := str(track_id_variant)
		Music.play(track_id, true, 0.0)
		await get_tree().process_frame
		if Music._players.is_empty() or Music._players[0].stream == null:
			failures += 1
			push_error("%s did not create a music stream" % track_id)
			continue
		var stream := Music._players[0].stream
		var loops := (stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop) \
			or (stream is AudioStreamMP3 and (stream as AudioStreamMP3).loop) \
			or (stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED)
		if not loops:
			failures += 1
			push_error("%s is not configured to loop" % track_id)
		Music.stop(0.0)
	print("MUSIC LOOP REGRESSION: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
