class_name Visual3DOverlay
extends CanvasLayer
## Lightweight 3D dressing layer rendered through a transparent SubViewport.
## It adds real low-poly geometry without replacing the fast 2D gameplay layer.

const PIXELS_PER_UNIT := 16.0
const VIEWPORT_SIZE := Vector2i(960, 540)

var level: Node2D
var follow_camera: Camera2D
var container: SubViewportContainer
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var props: Node3D
var _time := 0.0

var _materials: Dictionary = {}
var _mesh_cache: Dictionary = {}

func setup(p_level: Node2D, p_camera: Camera2D, level_data: Dictionary) -> void:
	level = p_level
	follow_camera = p_camera
	_build_viewport()
	_build_environment()
	_build_decor(level_data)
	set_process(true)

func _build_viewport() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	container = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.stretch = true
	add_child(container)

	viewport = SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.world_3d = World3D.new()
	container.add_child(viewport)

	world = Node3D.new()
	viewport.add_child(world)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.0
	camera.near = 0.05
	camera.far = 250.0
	world.add_child(camera)
	camera.current = true

	props = Node3D.new()
	props.name = "LowPolyDressing"
	world.add_child(props)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.light_energy = 1.7
	sun.light_color = Color(1.0, 0.78, 0.88)
	sun.shadow_enabled = false
	world.add_child(sun)

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.22, 0.40)
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	viewport.world_3d.environment = env

func _build_decor(level_data: Dictionary) -> void:
	var decor: Array = level_data.get("decor", [])
	for item in decor:
		var kind := str(item.get("type", ""))
		var pos := _cell_world(item.get("pos", [0, 0]))
		var size := float(item.get("size", 1.0))
		if kind == "palm":
			_add_model("palm", "res://assets/models/palm_tree.obj", pos, size)
		elif kind == "lamp":
			_add_model("lamp", "res://assets/models/street_lamp.obj", pos, size)
		elif kind == "arcade":
			_add_model("arcade", "res://assets/models/arcade_cabinet.obj", pos, size)
		elif kind == "dumpster":
			_add_model("dumpster", "res://assets/models/dumpster.obj", pos, size)

	# Bring some of the exterior parking geometry into 3D.
	var rows: Array = level_data.get("map", [])
	for y in rows.size():
		var row: String = str(rows[y])
		for x in row.length():
			var ch := row[x]
			if ch == "K":
				_add_model("car", "res://assets/models/retro_car.obj",
					Vector2(x * PIXELS_PER_UNIT + 8.0, y * PIXELS_PER_UNIT + 8.0), 1.0)
			elif ch == "j":
				var car := _add_model("wreck", "res://assets/models/retro_car.obj",
					Vector2(x * PIXELS_PER_UNIT + 8.0, y * PIXELS_PER_UNIT + 8.0), 1.0)
				if car:
					car.rotation.y = 0.15
			elif ch == "Q":
				_add_model("arcade", "res://assets/models/arcade_cabinet.obj",
					Vector2(x * PIXELS_PER_UNIT + 8.0, y * PIXELS_PER_UNIT + 8.0), 0.72)
			elif ch == "o":
				_add_model("lamp", "res://assets/models/street_lamp.obj",
					Vector2(x * PIXELS_PER_UNIT + 8.0, y * PIXELS_PER_UNIT + 8.0), 0.68)
			elif ch == "Z":
				_add_model("dumpster", "res://assets/models/dumpster.obj",
					Vector2(x * PIXELS_PER_UNIT + 8.0, y * PIXELS_PER_UNIT + 8.0), 0.9)

	# One dimensional neon sign tied to the motel exterior.
	for item in decor:
		if str(item.get("type", "")) == "neon":
			var pos := _cell_world(item.get("pos", [0, 0]))
			var text := str(item.get("text", ""))
			if text == "SUNSET PALMS":
				_add_model("sign", "res://assets/models/neon_motel_sign.obj", pos, 1.0)

func _cell_world(p: Variant) -> Vector2:
	var a: Array = p if p is Array else [0, 0]
	return Vector2(float(a[0]) * PIXELS_PER_UNIT + 8.0, float(a[1]) * PIXELS_PER_UNIT + 8.0)

func _mesh(path: String) -> Mesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var m := load(path) as Mesh
	if m:
		_mesh_cache[path] = m
	return m

func _material(kind: String) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.roughness = 0.62
	m.metallic = 0.08
	match kind:
		"palm":
			m.albedo_color = Color("#23613c")
			m.roughness = 0.9
		"car":
			m.albedo_color = Color("#b52c45")
			m.metallic = 0.35
			m.roughness = 0.32
		"wreck":
			m.albedo_color = Color("#574044")
			m.metallic = 0.18
			m.roughness = 0.8
		"sign":
			m.albedo_color = Color("#ff3d86")
			m.emission_enabled = true
			m.emission = Color("#ff246f")
			m.emission_energy_multiplier = 3.2
			m.roughness = 0.28
		"arcade":
			m.albedo_color = Color("#263b8f")
			m.metallic = 0.25
			m.roughness = 0.38
		"lamp":
			m.albedo_color = Color("#3d3d48")
			m.metallic = 0.65
			m.roughness = 0.3
		"dumpster":
			m.albedo_color = Color("#31594d")
			m.roughness = 0.85
	_materials[kind] = m
	return m

func _add_model(kind: String, path: String, world_pos: Vector2, scale_factor: float) -> Node3D:
	var mesh := _mesh(path)
	if mesh == null:
		return null
	var holder := Node3D.new()
	holder.name = kind
	holder.position = Vector3(world_pos.x / PIXELS_PER_UNIT, 0.0, world_pos.y / PIXELS_PER_UNIT)
	holder.scale = Vector3.ONE * scale_factor
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mi)
	if kind == "lamp":
		var lamp_light := OmniLight3D.new()
		lamp_light.light_color = Color("#ffb36b")
		lamp_light.light_energy = 2.2
		lamp_light.omni_range = 4.5
		lamp_light.shadow_enabled = false
		lamp_light.position = Vector3(0.45, 2.2, 0.0)
		holder.add_child(lamp_light)
	elif kind == "sign":
		var neon_light := OmniLight3D.new()
		neon_light.light_color = Color("#ff3d86")
		neon_light.light_energy = 2.0
		neon_light.omni_range = 5.0
		neon_light.shadow_enabled = false
		neon_light.position = Vector3(0.0, 0.8, 0.0)
		holder.add_child(neon_light)
	props.add_child(holder)
	return holder

func _process(delta: float) -> void:
	if follow_camera == null or not is_instance_valid(follow_camera) or camera == null:
		return
	_time += delta
	var c := follow_camera.global_position
	var target := Vector3(c.x / PIXELS_PER_UNIT, 0.0, c.y / PIXELS_PER_UNIT)
	camera.global_position = target + Vector3(0.0, 18.0, 4.5)
	camera.look_at(target, Vector3.UP)
	camera.size = 17.0 * (2.0 / maxf(follow_camera.zoom.y, 0.01))

	# Tiny living motion keeps the low-poly dressing from feeling static.
	for child in props.get_children():
		if child is Node3D and str(child.name) == "palm":
			child.rotation.y = sin(_time * 0.55 + child.position.x * 0.7) * 0.025
