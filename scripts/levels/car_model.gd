class_name CarModel
extends Sprite2D
## The hero car in 3D, through the cast's own camera and lights
## (CastModel.dress_stage): the same 50-degree view and pixel density as every
## character. Its driver is posed in the SAME viewport, so the doors and dash hide
## her legs and she climbs out past a door that really swings.
## Built by tools/art/prep_car.py: nodes "Body", "Door" (origin on the hinge) and
## the empty "DriverSeat". Faces +Z like the cast; HeroCar yaws it to its heading.

const PATH := "res://assets/art/cast3d_rt/eldorado/eldorado.glb"
const PX := 384
const DOOR_SWING := 1.3             ## radians open (about 75 degrees: clear of her path)
const OUT_STEP := 0.92              ## metres out from the seat to where she stands
const BACK_STEP := 0.48             ## ...and back along the car: she clears the door's swing
const ENERGY := 0.38                ## restrained against the level's actor/props boost

var viewport: SubViewport
var camera: Camera3D
var pivot: Node3D                   ## yawed to the car's heading
var car: Node3D
var door: Node3D
var seat_at := Vector3(0.34, 0.025, 0.0)
var driver: Node3D
var _driver_anim: AnimationPlayer
var _origin := Vector2.ZERO
var _px_per_m := float(CastModel.PX) / CastModel.METERS

static func available() -> bool:
	return ResourceLoader.exists(PATH) and OS.get_environment("CAST_BAKED") != "1"

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(PX, PX)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	# glossy red paint under the props layer's boost: about half the cast's light
	camera = CastModel.dress_stage(viewport, PX / _px_per_m, 0.4, ENERGY)
	pivot = Node3D.new()
	viewport.add_child(pivot)
	car = (load(PATH) as PackedScene).instantiate()
	pivot.add_child(car)
	door = car.find_child("Door", true, false) as Node3D
	var seat := car.find_child("DriverSeat", true, false) as Node3D
	if seat:
		seat_at = seat.position
	texture = viewport.get_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * 16.0 / _px_per_m
	material = CastModel._outline_material(1.0)
	light_mask = 2   # like the cast: the car's own headlights must not blow it out
	_origin = camera.unproject_position(Vector3.ZERO)
	offset = Vector2(PX * 0.5, PX * 0.5) - _origin

## Heading in the game's 2D frame (0 = screen right); the picture stays upright.
func set_heading(angle: float) -> void:
	if pivot:
		pivot.rotation.y = PI * 0.5 - angle
	global_rotation = 0.0

## 0 shut .. 1 open: it swings out on its front hinge.
func set_door(k: float) -> void:
	if door:
		door.rotation.y = -DOOR_SWING * clampf(k, 0.0, 1.5)

## Seats `look`'s real-time body at the wheel (CastModel's GLB).
func add_driver(look := "cass") -> bool:
	if driver:
		return true
	var scene := load(CastModel.RT_PATH % [look, look]) as PackedScene
	if scene == null:
		return false
	driver = scene.instantiate()
	car.add_child(driver)
	_driver_anim = driver.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["drive"]:
		if _driver_anim.has_animation(n):
			_driver_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	pose_driver("drive", -1.0, 0.0, 0.0)
	return true

func remove_driver() -> void:
	if driver:
		driver.queue_free()
		driver = null

## `clip` at `progress` (0..1, or -1 to loop), `out` metres from the seat toward the
## door (0 seated .. 1 standing outside), `turn` 0 facing ahead .. 1 facing the door.
func pose_driver(clip: String, progress: float, out: float, turn: float) -> void:
	if driver == null or not _driver_anim.has_animation(clip):
		return
	if progress >= 0.0:
		# driven frame by frame: straight to that frame, no cross-fade and no
		# playing on by itself (a finished clip would otherwise restart from its
		# first frame - seated - and the fade would show that, not the seek)
		if _driver_anim.assigned_animation != clip:
			_driver_anim.play(clip, 0.0)
		_driver_anim.speed_scale = 0.0
		# never exactly the end: imported clips loop, and the end wraps to frame 0
		_driver_anim.seek(clampf(progress, 0.0, 0.995) * _driver_anim.get_animation(clip).length, true)
	else:
		_driver_anim.speed_scale = 1.0
		if _driver_anim.current_animation != clip:
			_driver_anim.play(clip, 0.12)
	driver.position = _out_point(out)
	# the car faces +Z and its left (the door side) is +X
	driver.rotation.y = PI * 0.5 * turn

## Seat -> outside: first straight out through the opening, then a step back
## along the car, behind the open door (the car faces +Z, its door side is +X).
func _out_point(out: float) -> Vector3:
	var back := clampf((out - 0.55) / 0.45, 0.0, 1.0)
	return seat_at + Vector3(OUT_STEP * out, 0.0, -BACK_STEP * back * back)

## Where (global 2D) a point `out` of the way from the seat to the door shows on
## screen: hand the driver over to the player there so nothing jumps.
func driver_screen_global(out: float) -> Vector2:
	var p := car.to_global(_out_point(out))
	return global_position + (camera.unproject_position(p) - _origin) * scale

## Match the controller to the authored exit, including its reversed entry.
func exit_duration() -> float:
	if _driver_anim and _driver_anim.has_animation("car_exit"):
		return clampf(_driver_anim.get_animation("car_exit").length, 0.6, 2.0)
	return 0.9

func has_driver_clip(clip: String) -> bool:
	return _driver_anim != null and _driver_anim.has_animation(clip)

func driver_clip_duration(clip: String, fallback := 0.85) -> float:
	if has_driver_clip(clip):
		return clampf(_driver_anim.get_animation(clip).length,0.1,2.0)
	return fallback
