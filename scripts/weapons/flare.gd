class_name Flare
extends Node2D
## Road flare equipment: throw it to light a room and pull enemies toward it.

var velocity := Vector2.ZERO
var life := 9.0
var light: PointLight2D
var _noise_t := 0.0

func _ready() -> void:
	add_to_group("flares")
	light = PointLight2D.new()
	light.texture = SpriteLib.light_texture(256)
	light.texture_scale = 0.9
	light.color = Color(1.0, 0.25, 0.2)
	light.energy = 1.4
	light.shadow_enabled = true
	add_child(light)
	z_index = 4

func _physics_process(delta: float) -> void:
	if velocity.length() > 5.0:
		var space := get_world_2d().direct_space_state
		var step := velocity * delta
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step, Layers.WORLD | Layers.DOOR | Layers.GLASS | Layers.PROP)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			position += step
		else:
			global_position = hit.position + hit.normal * 2.0
			velocity = velocity.bounce(hit.normal) * 0.3
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	life -= delta
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = 0.6
		Events.noise.emit(global_position, 220.0, &"thrown", self)
		Effects.smoke(global_position)
	light.energy = 1.2 + randf() * 0.4
	if life < 1.5:
		light.energy *= life / 1.5
	if life <= 0.0:
		queue_free()
	queue_redraw()

func light_level_at(p: Vector2) -> float:
	return clampf(1.0 - p.distance_to(global_position) / 110.0, 0.0, 1.0)

func _draw() -> void:
	draw_rect(Rect2(-3, -1, 6, 2), Color(0.8, 0.1, 0.1))
	draw_circle(Vector2(3, 0), 1.5 + randf(), Color(1, 0.9, 0.6))
