class_name AnimatedProp
extends Sprite2D
## Small ambient motion for non-gameplay props (pool floats, signs, foliage accents).
@export var bob_amplitude := 1.2
@export var bob_speed := 1.1
@export var drift_amplitude := 0.0
@export var sway_amplitude := 0.025
var _base_position := Vector2.ZERO
var _phase := 0.0
func _ready() -> void:
	_base_position = position
	_phase = float(get_instance_id() % 97) * 0.17
func _process(delta: float) -> void:
	_phase += delta * bob_speed
	position.x = _base_position.x + sin(_phase * 0.61) * drift_amplitude
	position.y = _base_position.y + sin(_phase) * bob_amplitude
	rotation = sin(_phase * 0.73) * sway_amplitude
