class_name Corpse
extends Node2D
## A body on the floor. Enemies who see one become suspicious and search.
## Leaves a spreading pool of blood once it stops sliding. `missing` marks
## a lost head / arm (the stump is painted into the sprite). Dogs draw
## themselves (see Dog.draw_dead).

var discovered := false
var is_player := false
var is_dog := false
var dog_colors: Dictionary = {}
var sprite: Sprite2D
var missing := ""
var _slide := Vector2.ZERO
var _pooled := false
var _twitch := 0.0

func setup(palette: String, dir: Vector2, player := false, p_missing := "") -> void:
	is_player = player
	missing = p_missing
	sprite = Sprite2D.new()
	sprite.texture = SpriteLib.corpse(palette, missing)
	sprite.scale = Vector2(0.5, 0.5)
	sprite.rotation = dir.angle() + randf_range(-0.4, 0.4)
	add_child(sprite)
	_slide = dir.normalized() * 70.0

func setup_dog(colors: Dictionary, dir: Vector2, p_missing := "") -> void:
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
	set_process(false)

func _draw() -> void:
	if is_dog:
		Dog.draw_dead(self, dog_colors, _twitch, missing)
