class_name Ambience
extends Node
## Background sound per area: the zone the player is in picks a bed (motel
## interior hum, night exterior, industrial machinery, kennels), crossfaded
## over a second. Beds start at random offsets and loop seamlessly; now and
## then a distant one-shot (a car on the road, a dog far off) plays through
## the far bus so the loop never becomes the only thing you hear.

const BEDS := ["amb_interior", "amb_exterior", "amb_industrial", "amb_kennel"]
const VOLUME_DB := -17.0

var level: Level
var _players: Dictionary = {}     ## bed -> AudioStreamPlayer
var _current := ""
var _event_t := 8.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for bed in BEDS:
		var src := Audio.get_stream(bed) as AudioStreamWAV
		if src == null:
			continue
		var st := src.duplicate() as AudioStreamWAV
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = st.data.size() / 2   # 16-bit mono: bytes / 2 = frames
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.bus = "Ambience"
		p.volume_db = -60.0
		add_child(p)
		_players[bed] = p

## Which bed fits a zone. Level files can override with "ambience": {zone: bed}.
func bed_for(zone: String) -> String:
	var over: Dictionary = level.data.get("ambience", {}) if level else {}
	if over.has(zone):
		return str(over[zone])
	if zone.begins_with("exterior") or zone == "courtyard" or zone == "default":
		return "amb_exterior"
	if zone in ["warehouse", "shed", "boiler"]:
		return "amb_industrial"
	if zone == "kennels":
		return "amb_kennel"
	return "amb_interior"

func _process(delta: float) -> void:
	if level == null or level.player == null or not is_instance_valid(level.player):
		return
	var want := bed_for(level.zone_at(level.player.global_position))
	if want != _current and _players.has(want):
		_current = want
		var p: AudioStreamPlayer = _players[want]
		if not p.playing:
			p.play(randf() * maxf(0.0, p.stream.get_length() - 2.0))
	for bed in _players.keys():
		var pl: AudioStreamPlayer = _players[bed]
		var target := VOLUME_DB if bed == _current else -60.0
		pl.volume_db = move_toward(pl.volume_db, target, delta * 40.0)
		if bed != _current and pl.playing and pl.volume_db <= -59.0:
			pl.stop()
	_event_t -= delta
	if _event_t <= 0.0:
		_event_t = randf_range(10.0, 24.0)
		_distant_event()

func _distant_event() -> void:
	var p := level.player
	var at := p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(420.0, 700.0)
	if _current == "amb_exterior" or randf() < 0.3:
		Audio.play_at("car_pass", at, -14.0, 0.15)
	elif _current == "amb_kennel" or level.mission.id == &"m02_dog_days":
		Audio.play_at("bark", at, -20.0, 0.2)
