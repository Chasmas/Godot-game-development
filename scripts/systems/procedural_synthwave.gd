class_name ProceduralSynthwave
extends Node
## Original runtime-generated 80s synthwave bed. No external audio dependency.
## Designed as a subtle musical layer underneath the authored stems.

var player: AudioStreamPlayer
var generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var sample_rate := 22050.0
var sample_clock := 0.0
var bpm := 110.0
var intensity := 0
var active := false
var _phase: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start(p_bpm := 110.0) -> void:
	stop()
	bpm = p_bpm
	generator = AudioStreamGenerator.new()
	generator.mix_rate = sample_rate
	generator.buffer_length = 0.65
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	player.stream = generator
	player.volume_db = -15.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	sample_clock = 0.0
	active = true
	_phase.clear()
	_fill()

func stop() -> void:
	active = false
	if player:
		player.stop()
		player.queue_free()
	player = null
	playback = null
	generator = null

func set_intensity(v: int) -> void:
	intensity = clampi(v, 0, 3)

func set_volume_db(v: float) -> void:
	if player:
		player.volume_db = v

func _process(_delta: float) -> void:
	if active and playback:
		_fill()

func _fill() -> void:
	if playback == null:
		return
	var frames := playback.get_frames_available()
	if frames <= 0:
		return
	frames = mini(frames, 4096)
	var out := PackedVector2Array()
	out.resize(frames)
	var beat_len := 60.0 / bpm
	var step_len := beat_len / 4.0
	var roots: Array[float] = [55.0, 65.41, 73.42, 49.0, 55.0, 69.30, 73.42, 43.65]
	var arp: Array[float] = [220.0, 261.63, 329.63, 392.0, 329.63, 261.63, 246.94, 329.63]
	for i in frames:
		var t := sample_clock + float(i) / sample_rate
		var beat := t / beat_len
		var bar := int(floor(beat / 4.0))
		var step := int(floor(t / step_len))
		var root: float = roots[bar % roots.size()]
		var note: float = arp[step % arp.size()] * (0.5 if int(bar / 2) % 2 == 1 else 1.0)

		# Warm Juno-style bass: fundamental + octave + slight detune.
		var bass_phase := 2.0 * PI * root * t
		var bass := sin(bass_phase) * 0.16 + sin(bass_phase * 2.0) * 0.045
		bass *= 0.65 + 0.35 * (0.5 + 0.5 * sin(2.0 * PI * beat))

		# Soft saw-ish arpeggio made from harmonics.
		var ap := 2.0 * PI * note * t
		var arp_sig := (sin(ap) + 0.45 * sin(ap * 2.0) + 0.22 * sin(ap * 3.0)) * 0.028
		var gate := 0.5 + 0.5 * sin(2.0 * PI * t / step_len)
		arp_sig *= 0.55 + gate * 0.45

		# Slow pad movement.
		var pad_freq := root * 2.0
		var pad := (sin(2.0 * PI * pad_freq * t) + 0.35 * sin(2.0 * PI * pad_freq * 1.4983 * t)) * 0.018

		# Punchy electronic drums.
		var beat_index := int(floor(beat))
		var beat_pos := fmod(t, beat_len)
		var kick_on := beat_index % 2 == 0
		var kick_env := exp(-beat_pos * 34.0) if kick_on else 0.0
		var kick := sin(2.0 * PI * (42.0 + 78.0 * exp(-beat_pos * 26.0)) * t) * kick_env * 0.28
		var snare_on := beat_index % 4 == 1 or beat_index % 4 == 3
		var snare_env := exp(-beat_pos * 48.0) if snare_on else 0.0
		var snare := sin(2.0 * PI * 180.0 * t) * snare_env * 0.055
		var hat_phase := fmod(t, beat_len / 2.0)
		var hat_env := exp(-hat_phase * 90.0)
		var hat := sin(2.0 * PI * 7200.0 * t) * hat_env * 0.018

		var energy := 1.0 + float(intensity) * 0.12
		var lead := arp_sig * (1.0 + float(intensity) * 0.45)
		var left := (bass + pad + lead + kick + snare + hat) * energy
		var right := (bass * 0.96 + pad + lead * 1.08 + kick + snare * 0.92 + hat * 1.05) * energy
		out[i] = Vector2(left, right)

	sample_clock += float(frames) / sample_rate
	playback.push_buffer(out)
