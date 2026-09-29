extends Node
## Dynamic layered music. A track is a set of equal-length stems that start
## together; gameplay sets an intensity (0 explore, 1 combat, 2 high combo,
## 3 danger/near death) and layers crossfade to that intensity's mix.
## Tracks are defined in res://data/music.json.

const FADE_SPEED := 1.6       # volume units / sec for layer crossfades
const SILENT_DB := -60.0

var tracks: Dictionary = {}
var current_id := ""
var intensity := 0
var _players: Array[AudioStreamPlayer] = []
var _targets: Array[float] = []
var _levels: Array[float] = []
var _master_fade := 1.0
var _master_target := 1.0
var _last_beat := -1

## Fires on every beat of the current track (for HUD pulses).
signal beat(index: int)
var synthwave: ProceduralSynthwave

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	synthwave = ProceduralSynthwave.new()
	synthwave.name = "ProceduralSynthwave"
	add_child(synthwave)
	var f := FileAccess.open("res://data/music.json", FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			tracks = parsed

## The track the game asked for. With a "calm" companion (music.json) the
## companion plays while nobody is hunting you and the asked-for track
## takes over the moment somebody is - crossfaded, never cut.
var _base_id := ""
var _calm_t := 0.0
var _fade_speed := 1.2
var _outgoing: Array = []          ## [players, level] fading out
var _resume: Dictionary = {}       ## track id -> where it was left

func play(track_id: String, restart := false, fade := 0.8) -> void:
	if OS.has_environment("AUDIO_LOG"):
		print("[music] ", track_id)
	if track_id == _base_id and not restart and not _players.is_empty():
		_master_target = 1.0
		return
	if not tracks.has(track_id):
		push_warning("Unknown music track %s" % track_id)
		return
	_base_id = track_id
	_calm_t = 0.0
	var start_id := track_id
	var calm := str(tracks[track_id].get("calm", ""))
	if calm != "" and tracks.has(calm) and intensity == 0:
		start_id = calm
	if restart:
		_resume.erase(start_id)
	_switch(start_id, fade, false)

## Crossfade from whatever is playing to `id`. `resume`: pick it up where
## it was last left (a combat track coming back after a quiet spell).
func _switch(id: String, fade: float, resume: bool) -> void:
	if not _players.is_empty():
		if current_id != "":
			_resume[current_id] = _players[0].get_playback_position()
		if fade > 0.0:
			_outgoing.append([_players.duplicate(), _levels.duplicate(), _master_fade, 1.0 / fade])
		else:
			for p in _players:
				p.queue_free()
		_players.clear()
		_targets.clear()
		_levels.clear()
	current_id = id
	if synthwave:
		# the runtime bed is opt-in per track ("procedural_bed": true in
		# music.json) and always locked to that track's own tempo: under an
		# authored score at a different bpm it would fight the beat grid
		if bool(tracks[id].get("procedural_bed", false)):
			synthwave.start(float(tracks[id].get("bpm", 110.0)))
		else:
			synthwave.stop()
	var layers: Array = tracks[id].layers
	for i in layers.size():
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		var path: String = layers[i]
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			if s is AudioStreamOggVorbis:
				s.loop = true
			elif s is AudioStreamWAV:
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			p.stream = s
		add_child(p)
		_players.append(p)
		_targets.append(1.0 if i == 0 else 0.0)
		_levels.append(1.0 if i == 0 else 0.0)
		p.volume_db = 0.0 if i == 0 else SILENT_DB
	var at := float(_resume.get(id, 0.0)) if resume else 0.0
	for p in _players:
		if p.stream:
			p.play(at)
	_master_fade = 0.0 if fade > 0.0 else 1.0
	_fade_speed = 1.0 / fade if fade > 0.0 else 1.2
	_master_target = 1.0
	set_intensity(intensity, true)

func stop(fade_time := 1.0) -> void:
	_base_id = ""
	if fade_time <= 0.0:
		for p in _players:
			p.queue_free()
		_players.clear()
		_targets.clear()
		_levels.clear()
		if synthwave:
			synthwave.stop()
		current_id = ""
	elif not _players.is_empty():
		_outgoing.append([_players.duplicate(), _levels.duplicate(), _master_fade, 1.0 / fade_time])
		_players.clear()
		_targets.clear()
		_levels.clear()
		current_id = ""
		if synthwave:
			synthwave.stop()

func set_intensity(level: int, instant := false) -> void:
	intensity = clampi(level, 0, 3)
	if current_id == "" or not tracks.has(current_id):
		return
	var t: Dictionary = tracks[current_id]
	if not t.has("intensity"):
		return
	var mix: Array = t.intensity[mini(intensity, t.intensity.size() - 1)]
	if synthwave:
		synthwave.set_intensity(intensity)
	for i in _targets.size():
		_targets[i] = float(mix[i]) if i < mix.size() else 0.0
		if instant:
			_levels[i] = _targets[i]

## Seconds per beat of the current track (0 if there's no music).
func beat_length() -> float:
	if current_id == "" or not tracks.has(current_id) or _players.is_empty():
		return 0.0
	var bpm := float(tracks[current_id].get("bpm", 0))
	return 60.0 / bpm if bpm > 0.0 else 0.0

## Where we are in the beat: 0 on the beat, 0.5 halfway to the next. Uses
## the audible position (playback minus output latency).
func beat_phase() -> float:
	var spb := beat_length()
	if spb <= 0.0 or not _players[0].playing:
		return -1.0
	var pos := _players[0].get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return fposmod(pos, spb) / spb

## Seconds from the nearest beat (large if there's no music).
func beat_distance() -> float:
	var ph := beat_phase()
	if ph < 0.0:
		return 99.0
	return minf(ph, 1.0 - ph) * beat_length()

## A boss's later phase: its own collapse theme ("phase2" in music.json),
## crossfaded in. Safe to call every frame.
func boss_phase2() -> void:
	if _base_id == "" or not tracks.has(_base_id):
		return
	var nxt := str(tracks[_base_id].get("phase2", ""))
	if nxt != "" and tracks.has(nxt):
		play(nxt, false, 1.2)

## Quiet for a while: the calm companion, slowly. Anyone hunting: the
## asked-for track, fast, picked up where it was left.
func _calm_switch(delta: float) -> void:
	if _base_id == "" or not tracks.has(_base_id):
		return
	var calm := str(tracks[_base_id].get("calm", ""))
	if calm == "" or not tracks.has(calm):
		return
	if intensity == 0:
		_calm_t += delta
		if current_id != calm and _calm_t > float(tracks[_base_id].get("calm_after", 8.0)):
			_switch(calm, 3.0, true)
	else:
		_calm_t = 0.0
		if current_id != _base_id:
			_switch(_base_id, 0.35, true)

func set_pitch(p: float) -> void:
	for pl in _players:
		pl.pitch_scale = p

func duck(amount: float) -> void:
	_master_target = amount

func _process(delta: float) -> void:
	for o in _outgoing:
		o[2] = maxf(0.0, float(o[2]) - delta * float(o[3]))
		for i in (o[0] as Array).size():
			var lin: float = float(o[1][i]) * float(o[2])
			(o[0][i] as AudioStreamPlayer).volume_db = linear_to_db(lin) if lin > 0.001 else SILENT_DB
	for o in _outgoing.filter(func(q): return float(q[2]) <= 0.0):
		for p in o[0]:
			(p as Node).queue_free()
	_outgoing = _outgoing.filter(func(q): return float(q[2]) > 0.0)
	_calm_switch(delta)
	if _players.is_empty():
		return
	_master_fade = move_toward(_master_fade, _master_target, delta * (_fade_speed if _master_target > _master_fade else 1.2))
	for i in _players.size():
		_levels[i] = move_toward(_levels[i], _targets[i], delta * FADE_SPEED)
		var lin := _levels[i] * _master_fade
		_players[i].volume_db = linear_to_db(lin) if lin > 0.001 else SILENT_DB
	var ph := beat_phase()
	if ph >= 0.0:
		var idx := int(floor((_players[0].get_playback_position()) / beat_length()))
		if idx != _last_beat:
			_last_beat = idx
			beat.emit(idx)
	# keep stems locked together (ogg decoders can drift after long sessions)
	if _players.size() > 1 and Engine.get_process_frames() % 240 == 0:
		var ref := _players[0].get_playback_position()
		for i in range(1, _players.size()):
			if absf(_players[i].get_playback_position() - ref) > 0.05:
				_players[i].seek(ref)
