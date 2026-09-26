class_name CameraController
extends Camera2D
## Top-down follow camera: smooth follow, aim look-ahead, trauma-based shake
## (scaled by the accessibility setting), zoom punches for executions and
## big moments, and a "zoom out" when the player holds the look key.

const BASE_ZOOM := 2.0
const LOOK_AHEAD := 0.32
const MAX_LOOK := 110.0

var target: Node2D
var _trauma := 0.0
var _punch := 1.0
var _punch_target := 1.0
var _punch_time := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var zoom_bias := 1.0
var _nudge := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	zoom = Vector2(BASE_ZOOM, BASE_ZOOM)
	ignore_rotation = false
	position_smoothing_enabled = false
	_noise.seed = 1988
	_noise.frequency = 0.9
	Events.camera_shake.connect(add_trauma)
	Events.camera_punch.connect(punch)
	Events.camera_nudge.connect(func(o: Vector2): _nudge += o * float(SaveManager.get_setting("screen_shake", 1.0)))
	make_current()

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount * 0.06, 0.0, 1.0)

func punch(z: float, duration: float) -> void:
	# a gunshot's tiny punch never cuts short a bigger one (executions)
	if _punch_time > 0.0 and z < _punch_target:
		return
	_punch_target = z
	_punch_time = duration

func snap_to_target() -> void:
	if target:
		global_position = target.global_position

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	# work in real time so hit-stop/slow-mo don't make the camera sluggish
	var rd := delta / maxf(Engine.time_scale, 0.03)
	rd = minf(rd, 0.05)
	_t += rd
	if target and is_instance_valid(target):
		var want := target.global_position
		if target is Player:
			var p := target as Player
			var look := (p.aim_point - p.global_position) * LOOK_AHEAD
			var peek := Input.is_action_pressed("sprint") and p.velocity.length() < 5.0
			if peek:
				look *= 2.4   # hold sprint while standing still: peek further
			want += look.limit_length(MAX_LOOK * (2.4 if peek else 1.0))
			want += p.velocity * 0.12
		global_position = global_position.lerp(want, 1.0 - exp(-rd * 9.0))
	# punch zoom
	if _punch_time > 0.0:
		_punch_time -= rd
		_punch = lerpf(_punch, _punch_target, 1.0 - exp(-rd * 12.0))
	else:
		_punch = lerpf(_punch, 1.0, 1.0 - exp(-rd * 6.0))
	var z := BASE_ZOOM * _punch * zoom_bias
	zoom = Vector2(z, z)
	# shake
	var scale_setting := float(SaveManager.get_setting("screen_shake", 1.0))
	_trauma = maxf(0.0, _trauma - rd * 1.6)
	var s := _trauma * _trauma * scale_setting
	_nudge = _nudge.lerp(Vector2.ZERO, 1.0 - exp(-rd * 16.0))
	offset = _nudge + Vector2(_noise.get_noise_2d(_t * 60.0, 0.0), _noise.get_noise_2d(0.0, _t * 60.0)) * 9.0 * s
	rotation = _noise.get_noise_2d(_t * 40.0, 99.0) * 0.03 * s
