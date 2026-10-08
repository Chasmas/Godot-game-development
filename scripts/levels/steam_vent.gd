extends Node2D
## Textured intermittent vapor; integration waits for a real-map review.
@export var texture: Texture2D
@export var cycle := 9.0
@export var plume_size := Vector2(34, 40)
var elapsed := 0.0
func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
func _draw() -> void:
	if texture == null: return
	for i in 3:
		var age := fposmod(elapsed - float(i) * 0.85, cycle)
		if age > 4.0: continue
		var life := age / 4.0
		var alpha := 0.16 * smoothstep(0.0, 0.2, life) * (1.0 - smoothstep(0.45, 1.0, life))
		var drift := Vector2(9.0 + age * 2.0 + sin(age * 1.2 + i) * 1.5, -14.0 - age * 2.8)
		var growth := 0.75 + life * 0.45
		draw_set_transform(drift, sin(age * 0.7 + i) * 0.08, Vector2.ONE * growth)
		draw_texture_rect(texture, Rect2(-plume_size * 0.5, plume_size), false, Color(0.8, 0.9, 1.0, alpha))
	draw_set_transform(Vector2.ZERO)
