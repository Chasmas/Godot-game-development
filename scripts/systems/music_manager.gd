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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://data/music.json", FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			tracks = parsed

func play(track_id: String, restart := false) -> void:
	if track_id == current_id and not restart and not _players.is_empty():
		_master_target = 1.0
		return
	stop(0.0)
	if not tracks.has(track_id):
		push_warning("Unknown music track %s" % track_id)
		return
	current_id = track_id
	var layers: Array = tracks[track_id].layers
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
	for p in _players:
		if p.stream:
			p.play()
	_master_fade = 1.0
	_master_target = 1.0
	set_intensity(0, true)

func stop(fade_time := 1.0) -> void:
	if fade_time <= 0.0:
		for p in _players:
			p.queue_free()
		_players.clear()
		_targets.clear()
		_levels.clear()
		current_id = ""
	else:
		_master_target = 0.0
		var t := get_tree().create_timer(fade_time, true, false, true)
		var id := current_id
		t.timeout.connect(func():
			if current_id == id and _master_target == 0.0:
				stop(0.0))

func set_intensity(level: int, instant := false) -> void:
	intensity = clampi(level, 0, 3)
	if current_id == "" or not tracks.has(current_id):
		return
	var t: Dictionary = tracks[current_id]
	if not t.has("intensity"):
		return
	var mix: Array = t.intensity[mini(intensity, t.intensity.size() - 1)]
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

func set_pitch(p: float) -> void:
	for pl in _players:
		pl.pitch_scale = p

func duck(amount: float) -> void:
	_master_target = amount

func _process(delta: float) -> void:
	if _players.is_empty():
		return
	_master_fade = move_toward(_master_fade, _master_target, delta * 1.2)
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
