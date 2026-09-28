class_name MaskPickup
extends Node2D
## A hidden mask lying somewhere nobody goes: the far end of the level from
## where she starts. Walk over it and it's hers (Masks.unlock).

var mask_id: StringName = &""
var _t := 0.0
var _tex: Texture2D
var _taken := false

## Puts the level's hidden mask (if it's still to be found) in the open cell
## furthest along the navigation grid from the start.
static func place(level: Node2D, mission_id: String, start: Vector2) -> void:
	var id := Masks.secret_for(mission_id)
	var nav: AStarGrid2D = level.get("nav")
	if id == &"" or nav == null:
		return
	var a := Vector2i(int(start.x / 16.0), int(start.y / 16.0))
	var r := nav.region
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(mission_id)
	var best := Vector2i(-1, -1)
	var best_len := 0
	for i in 160:
		var c := Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 2), rng.randi_range(r.position.y + 1, r.end.y - 2))
		if nav.is_point_solid(c) or nav.is_point_solid(c + Vector2i(1, 0)) or nav.is_point_solid(c - Vector2i(1, 0)) \
				or nav.is_point_solid(c + Vector2i(0, 1)) or nav.is_point_solid(c - Vector2i(0, 1)):
			continue
		var n := nav.get_id_path(a, c).size()
		if n > best_len:
			best_len = n
			best = c
	if best.x < 0:
		return
	var mp := MaskPickup.new()
	mp.mask_id = id
	mp.position = Vector2(best) * 16.0 + Vector2(8, 8)
	level.add_child(mp)

func _ready() -> void:
	z_index = 20
	_tex = Masks.icon(mask_id)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _taken:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and p.global_position.distance_to(global_position) < 11.0:
		_taken = true
		Masks.unlock(mask_id)
		Audio.play("upgrade")
		PostFX.flash(UIStyle.GOLD, 0.3)
		Effects.popup(tr("MASK FOUND"), global_position + Vector2(0, -10), UIStyle.GOLD)
		var tw := create_tween().set_parallel()
		tw.tween_property(self, "scale", Vector2.ONE * 2.2, 0.5)
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(queue_free)

func _draw() -> void:
	var bob := sin(_t * 2.2) * 2.0
	# a faint shaft of light it lies in, so a curious eye can spot it
	draw_circle(Vector2.ZERO, 12.0 + sin(_t * 3.0), Color(1, 0.8, 0.4, 0.08))
	draw_circle(Vector2.ZERO, 7.0, Color(1, 0.85, 0.5, 0.12))
	if _tex:
		draw_set_transform(Vector2(0, bob), sin(_t * 1.3) * 0.15, Vector2.ONE)
		draw_texture_rect(_tex, Rect2(-8, -8, 16, 16), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a glint now and then
	var g := fmod(_t, 2.6)
	if g < 0.25:
		var k := g / 0.25
		draw_line(Vector2(-5, -5 + bob) * (1 - k), Vector2(5, 5 + bob) * (1 - k), Color(1, 1, 1, 1 - k), 1.0)
