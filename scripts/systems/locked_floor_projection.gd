extends RefCounted
## Coordinate bridge for a locked 3D visual camera over existing 2D gameplay.
## Callers retain authority over input, physics and whether the bridge is active.

static func to_world(map_point: Vector2, map_origin: Vector2, pixels_per_metre: float = 16.0) -> Vector3:
	assert(pixels_per_metre>0)
	var floor := (map_point-map_origin)/pixels_per_metre
	return Vector3(floor.x,0,floor.y)

static func screen_to_map(camera: Camera3D, screen_point: Vector2, map_origin: Vector2, pixels_per_metre: float = 16.0) -> Variant:
	assert(pixels_per_metre>0)
	var origin := camera.project_ray_origin(screen_point)
	var ray := camera.project_ray_normal(screen_point)
	if absf(ray.y)<.00001:return null
	var distance := -origin.y/ray.y
	if distance<0:return null
	var ground := origin+ray*distance
	return Vector2(ground.x,ground.z)*pixels_per_metre+map_origin

static func screen_direction_to_map(camera: Camera3D, actor_map_point: Vector2, screen_direction: Vector2, map_origin: Vector2, pixels_per_metre: float = 16.0) -> Vector2:
	if screen_direction.is_zero_approx():return Vector2.ZERO
	var actor_screen := camera.unproject_position(to_world(actor_map_point,map_origin,pixels_per_metre))
	var destination: Variant=screen_to_map(camera,actor_screen+screen_direction.normalized()*32,map_origin,pixels_per_metre)
	if destination==null:return Vector2.ZERO
	return (destination-actor_map_point).normalized()
