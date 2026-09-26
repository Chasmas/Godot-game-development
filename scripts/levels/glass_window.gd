class_name GlassWindow
extends StaticBody2D
## Window pane: blocks walking and bullets until it breaks (noisy!).
## Broken windows can be dived through with a dash.

var size := Vector2(16, 4)
var broken := false
var hit_radius := 8.0

func setup(rect: Rect2) -> void:
	position = rect.get_center()
	size = rect.size

func _ready() -> void:
	add_to_group("glass")
	add_to_group("damageable")
	collision_layer = Layers.GLASS
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	add_child(cs)
	z_index = 3

func hit_point(from: Vector2) -> Vector2:
	var half := size * 0.5
	var local := (from - global_position).clamp(-half, half)
	return global_position + local

func take_damage(info: DamageInfo) -> String:
	if broken:
		return "pass"
	shatter(info.dir)
	return "pass"

func shatter(dir: Vector2) -> void:
	if broken:
		return
	broken = true
	collision_layer = Layers.LOW      # frame remains: vault/dive through it
	remove_from_group("glass")
	Audio.play_at("glass", global_position)
	Effects.glass(global_position, dir)
	Events.noise.emit(global_position, 260.0, &"glass", null)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	if broken:
		draw_rect(r, Color(0.1, 0.1, 0.14, 0.9))
		var n := 5
		for i in n:
			var t := (i + 0.5) / n
			var p := r.position + Vector2(r.size.x * t, r.size.y * 0.5) if size.x > size.y else r.position + Vector2(r.size.x * 0.5, r.size.y * t)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-2, -1), p + Vector2(1, -2), p + Vector2(2, 1)]), Color(0.7, 0.9, 1.0, 0.8))
		return
	draw_rect(r, Color(0.45, 0.75, 0.95, 0.55))
	draw_rect(r, Color(0.85, 0.95, 1.0, 0.9), false, 1.0)
	var hl := Rect2(r.position + Vector2(2, 1), Vector2(maxf(2.0, r.size.x * 0.3), 1)) if size.x > size.y else Rect2(r.position + Vector2(1, 2), Vector2(1, maxf(2.0, r.size.y * 0.3)))
	draw_rect(hl, Color(1, 1, 1, 0.8))
