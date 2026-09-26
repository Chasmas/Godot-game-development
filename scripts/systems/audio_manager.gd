extends Node
## Sound effects: pooled positional + non-positional players, bus setup,
## volume settings. Sounds are addressed by name ("pistol", "glass" ...) and
## loaded from res://assets/audio/sfx/<name>.wav (swap files to replace).

const SFX_DIR := "res://assets/audio/sfx/"
const POOL_2D := 32
const POOL_UI := 8

var _cache: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer2D] = []
var _pool_ui: Array[AudioStreamPlayer] = []
var _i2d := 0
var _iui := 0
var _last_play: Dictionary = {}   # name -> msec, avoids stacking identical sounds in one frame
var music_lowpass: AudioEffectLowPassFilter

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_2D:
		var p := AudioStreamPlayer2D.new()
		p.bus = "SFX"
		p.max_distance = 900.0
		p.attenuation = 1.6
		p.panning_strength = 0.8
		add_child(p)
		_pool2d.append(p)
	for i in POOL_UI:
		var u := AudioStreamPlayer.new()
		u.bus = "SFX"
		add_child(u)
		_pool_ui.append(u)
	Events.settings_changed.connect(apply_volumes)
	apply_volumes()

## Sounds further than this from the listener go through the SFX_Far bus
## (low-passed, a little reverb) so a distant gunshot sounds distant, not
## just quieter.
const FAR_DIST := 340.0

func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "Dialogue", "SFX_Far", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var mi := AudioServer.get_bus_index("Music")
	music_lowpass = AudioEffectLowPassFilter.new()
	music_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(mi, music_lowpass)
	var comp := AudioEffectCompressor.new()
	comp.threshold = -8.0
	comp.ratio = 3.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), comp)
	var fi := AudioServer.get_bus_index("SFX_Far")
	AudioServer.set_bus_send(fi, "SFX")
	var flp := AudioEffectLowPassFilter.new()
	flp.cutoff_hz = 1500.0
	AudioServer.add_bus_effect(fi, flp)
	var frv := AudioEffectReverb.new()
	frv.room_size = 0.55
	frv.damping = 0.6
	frv.wet = 0.25
	frv.dry = 0.85
	AudioServer.add_bus_effect(fi, frv)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Ambience"), "SFX")

func apply_volumes() -> void:
	_set_bus("Master", SaveManager.get_setting("master_volume", 0.9))
	_set_bus("Music", SaveManager.get_setting("music_volume", 0.8))
	_set_bus("SFX", SaveManager.get_setting("sfx_volume", 0.9))
	_set_bus("Dialogue", SaveManager.get_setting("dialogue_volume", 0.9))

func _set_bus(bus_name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(v), 0.0001)))
		AudioServer.set_bus_mute(i, float(v) <= 0.001)

func get_stream(sfx_name: String) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var path := SFX_DIR + sfx_name + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[sfx_name] = s
	return s

func _throttled(sfx_name: String) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sfx_name, -1000)) < 25:
		return true
	_last_play[sfx_name] = now
	return false

## Positional sound in the world.
func play_at(sfx_name: String, pos: Vector2, volume_db := 0.0, pitch_var := 0.08) -> void:
	var s := get_stream(sfx_name)
	if s == null or _throttled(sfx_name):
		return
	var p := _pool2d[_i2d]
	_i2d = (_i2d + 1) % POOL_2D
	p.stream = s
	p.global_position = pos
	var far := listener_pos().distance_to(pos) > FAR_DIST
	p.bus = "SFX_Far" if far else "SFX"
	p.volume_db = volume_db - (3.0 if far else 0.0)
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var) * Engine.time_scale ** 0.35
	p.play()

## Where the ears are: the centre of the camera's view (the player is
## roughly there, but the camera leads toward the aim).
func listener_pos() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	return vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size * 0.5)

## Flat UI / player-centric sound.
func play(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := get_stream(sfx_name)
	if s == null or _throttled(sfx_name):
		return
	var p := _pool_ui[_iui]
	_iui = (_iui + 1) % POOL_UI
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()

func set_music_muffled(muffled: bool) -> void:
	if music_lowpass:
		var tw := create_tween()
		tw.tween_property(music_lowpass, "cutoff_hz", 900.0 if muffled else 20000.0, 0.3)
