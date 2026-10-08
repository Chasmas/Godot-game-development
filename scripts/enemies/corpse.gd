class_name Corpse
extends Node2D
## A body on the floor. Enemies who see one become suspicious and search.
## Leaves a spreading pool of blood once it stops sliding. `missing` marks
## a lost head / arm (the stump is painted into the sprite). Dogs draw
## themselves (see Dog.draw_dead).

var _cast: CastSprite
var _cast_time := 0.0
var _death_clip := "death"
var discovered := false
var is_player := false
var is_dog := false
var dog_colors: Dictionary = {}
var sprite: Sprite2D
var missing := ""
var _slide := Vector2.ZERO
var _pooled := false
var _twitch := 0.0
var _settle_t := 0.32
var _settle_rot := 0.0
var _bleed_left := 2.8
var _bleed_wait := 0.18
var _bleed_dir := Vector2.RIGHT

func setup(palette: String, dir: Vector2, player := false, p_missing := "", facing := 0.0) -> void:
	_bleed_dir = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	is_player = player
	missing = p_missing
	_slide = dir.normalized() * 70.0
	_settle_rot = randf_range(-0.18, 0.18)
	# Prefer the animated model before generating a painted fallback corpse.
	var cast_id := SpriteForge.base_name(palette)
	if player or cast_id != "cass":
		var candidate := CastModel.create(cast_id)
		if candidate and not missing.is_empty() and candidate.sever_part(missing) == 0:
			candidate.free()
			candidate = null
		if candidate:
			_cast = candidate
			sprite = candidate
			if candidate.is_oblique():
				var pivot := Node2D.new()
				pivot.rotation = facing if player else (-dir).angle()
				add_child(pivot)
				pivot.add_child(sprite)
				if not player and candidate.clips.has("death_back"):
					_death_clip = "death_back"
			else:
				add_child(sprite)
				sprite.rotation = facing
			_cast.play_sample(_death_clip, 0.0, 0.0)
			return
	sprite = Sprite2D.new()
	sprite.texture = SpriteLib.corpse(palette, missing, randi() % 4)
	sprite.scale = Vector2(0.5, 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.rotation = dir.angle() + randf_range(-0.4, 0.4)
	add_child(sprite)

func setup_dog(colors: Dictionary, dir: Vector2, p_missing := "") -> void:
	_bleed_dir = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	is_dog = true
	dog_colors = colors
	missing = p_missing
	rotation = dir.angle() + randf_range(-0.5, 0.5)
	_slide = dir.normalized() * 80.0
	_twitch = 1.2

func _ready() -> void:
	add_to_group("corpses")
	z_index = -4

func _process(delta: float) -> void:
	if _bleed_left > 0.0:
		_bleed_left = maxf(0.0, _bleed_left - delta)
		_bleed_wait -= delta
		if _bleed_wait <= 0.0 and Gore.level() > 0:
			_bleed_wait = lerpf(0.65, 0.28, _bleed_left / 2.8)
			var strength := lerpf(0.12, 0.38, _bleed_left / 2.8)
			Gore.spray(global_position + _bleed_dir * 3.0, _bleed_dir.rotated(randf_range(-0.5, 0.5)), 0.18, strength)
	if _cast:
		_cast_time += delta
		_cast.play_sample(_death_clip, delta, minf(_cast_time / 0.75, 1.0))
	if _settle_t > 0.0 and sprite and not _cast:
		_settle_t -= delta
		var k := clampf(1.0 - _settle_t / 0.32, 0.0, 1.0)
		sprite.scale = Vector2(0.5 + sin(k * PI) * 0.035, 0.5 - sin(k * PI) * 0.045)
		sprite.rotation += _settle_rot * delta * (1.0 - k)
	if _slide.length() > 1.0:
		position += _slide * delta
		_slide = _slide.move_toward(Vector2.ZERO, 400.0 * delta)
		return
	if not _pooled:
		_pooled = true
		Gore.pool(global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2)), randf_range(8.0, 12.0) if not is_dog else 8.0, 0.2)
	if is_dog and _twitch > 0.0:
		_twitch -= delta
		queue_redraw()
		return
	if _bleed_left <= 0.0 and (not _cast or _cast_time >= 0.75):
		set_process(false)

func _draw() -> void:
	if is_dog:
		Dog.draw_dead(self, dog_colors, _twitch, missing)
