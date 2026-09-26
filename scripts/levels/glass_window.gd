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
	# a usable shard lands on the far side: a quick, fragile blade
	var wd: WeaponData = DB.weapon(&"glass_shard")
	var host := get_parent()
	if wd and host:
		var land := global_position + (dir if dir != Vector2.ZERO else Vector2.DOWN).normalized() * 12.0
		(func(): WeaponPickup.spawn(host, WeaponInstance.create(wd), land)).call_deferred()
	Events.noise.emit(global_position, 260.0, &"glass", null)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	if broken:
		# empty frame with jagged teeth of glass left along both edges
		draw_rect(r, Color(0.1, 0.1, 0.14, 0.9))
		var horiz := size.x > size.y
		var length := size.x if horiz else size.y
		var depth := (size.y if horiz else size.x) * 0.5
		var rng := RandomNumberGenerator.new()
		rng.seed = int(global_position.x * 7.0 + global_position.y)
		for side in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			var x := -length * 0.5
			while x < length * 0.5:
				var w := rng.randf_range(1.5, 4.0)
				var h := rng.randf_range(0.3, 1.0) * depth
				var a := Vector2(x, side * depth)
				var tip := Vector2(x + w * rng.randf_range(0.3, 0.7), side * (depth - h))
				var b := Vector2(minf(x + w, length * 0.5), side * depth)
				var tri := PackedVector2Array([a, tip, b]) if horiz else PackedVector2Array([Vector2(a.y, a.x), Vector2(tip.y, tip.x), Vector2(b.y, b.x)])
				draw_colored_polygon(tri, Color(0.6, 0.85, 1.0, 0.75))
				draw_line(tri[0], tri[1], Color(0.9, 0.97, 1.0, 0.9), 0.6)
				x += w
		return
	draw_rect(r, Color(0.45, 0.75, 0.95, 0.55))
	draw_rect(r, Color(0.85, 0.95, 1.0, 0.9), false, 1.0)
	var hl := Rect2(r.position + Vector2(2, 1), Vector2(maxf(2.0, r.size.x * 0.3), 1)) if size.x > size.y else Rect2(r.position + Vector2(1, 2), Vector2(1, maxf(2.0, r.size.y * 0.3)))
	draw_rect(hl, Color(1, 1, 1, 0.8))
