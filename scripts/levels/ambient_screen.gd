class_name AmbientScreen
extends Sprite2D
## Low-cost CRT glow variation for decorative screens. No physics or collision.
@export var pulse_speed := 2.7
@export var pulse_amount := 0.08
var _phase := 0.0
var _base_modulate := Color.WHITE

func _ready() -> void:
	_phase = float(get_instance_id() % 41) * 0.37
	_base_modulate = modulate

func _process(delta: float) -> void:
	_phase += delta * pulse_speed
	var wave := sin(_phase) * pulse_amount + sin(_phase * 2.71) * pulse_amount * 0.35
	modulate = Color(_base_modulate.r + wave, _base_modulate.g + wave, _base_modulate.b + wave, _base_modulate.a)
