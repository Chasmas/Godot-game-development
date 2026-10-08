extends SceneTree
func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/mom_voice_older/manifest.json"))
	var failures := 0
	for row in manifest.lines:
		var stream := AudioStreamMP3.load_from_file("res://" + str(row.file).replace("\\", "/"))
		if stream == null or stream.get_length() <= 0.5:
			failures += 1
		else:
			row["duration"] = stream.get_length()
			print(row.dialogue, "/", row.node, " duration=", stream.get_length())
	manifest["decode_failures"] = failures
	var output := FileAccess.open("res://build/mom_voice_older/decode_review.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest, "  "))
	print("MOTHER VOICE DECODE REVIEW: ", failures, " failures")
	quit(1 if failures else 0)
