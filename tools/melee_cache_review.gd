extends Node
const Candidate = preload("res://tools/measured_melee_trail_candidate.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
func _ready() -> void:
	var baseline := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var retained: Array[Texture2D] = []
	var timings := []
	for index in [1, 5, 1, 9, 1]:
		var start := Time.get_ticks_usec()
		var frames := Candidate.cached_heading(index)
		var ms := (Time.get_ticks_usec() - start) / 1000.0
		timings.append(ms)
		print("Heading ", index, " load ms=", ms)
		check(frames.size() == 65 and frames.all(func(t): return t != null), "complete texture sequence")
		check(Candidate.heading_cache.size() <= 2, "cache retains at most two headings")
		if retained.is_empty():
			retained = frames
		await get_tree().process_frame
	check(timings[2] < 1.0 and timings[4] < 1.0, "cached heading access stays below one millisecond")
	check(Candidate.heading_cache.has(1) and Candidate.heading_cache.has(9) and not Candidate.heading_cache.has(5), "least recently used heading is evicted")
	Candidate.cached_heading(12)
	Candidate.cached_heading(13)
	check(not Candidate.heading_cache.has(1) and retained[32] != null, "live effect retains textures after cache eviction")
	await get_tree().process_frame
	print("Texture memory delta bytes=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) - baseline)
	print("MELEE CACHE REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
