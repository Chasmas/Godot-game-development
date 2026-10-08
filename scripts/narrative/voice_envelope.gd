class_name VoiceEnvelope
extends RefCounted
## Measured loudness guides mouth closure; this is not phoneme recognition.
static var _data: Dictionary = {}
static func sample(path: String, seconds: float) -> float:
	if _data.is_empty():
		var file := "res://assets/audio/voice/mouth_envelopes.json"
		if not FileAccess.file_exists(file): return -1.0
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
		if not parsed is Dictionary: return -1.0
		_data = parsed
	var values: Array = _data.get("clips", {}).get(path, [])
	if values.is_empty(): return -1.0
	var index := int(maxf(0.0,seconds)/float(_data.get("step",0.02)))
	return float(values[index]) if index < values.size() else 0.0
