class_name Crowd
extends Node
## Per-level crowd service, rebuilt once per physics tick before any actor
## moves (process_physics_priority is very low).
##  - Spatial hash of every living actor (enemies, NPCs, player): neighbour
##    queries are O(nearby) instead of every enemy scanning every enemy.
##  - Attack tokens: only a few shooters fire at the player at once and only
##    a few melee enemies close in; the rest hold positions around the fight.
##    Keeps big fights readable and fair without making anyone passive.
## Everything is validated each tick, so an actor freed mid-frame can never be
## handed back to a caller.

const CELL := 48.0

var level: Node
var _cells: Dictionary = {}          ## Vector2i -> Array[Node2D]
var _all: Array[Node2D] = []
var _shooters: Dictionary = {}       ## Enemy -> true
var _melee: Dictionary = {}          ## Enemy -> true
var _frame := -1

static func get_crowd(tree: SceneTree) -> Crowd:
	return tree.get_first_node_in_group("crowd") as Crowd if tree else null

func _ready() -> void:
	add_to_group("crowd")
	process_physics_priority = -1000
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _physics_process(_delta: float) -> void:
	rebuild()

func rebuild() -> void:
	_frame = Engine.get_physics_frames()
	_cells.clear()
	_all.clear()
	var tree := get_tree()
	for group in ["enemies", "npcs", "player"]:
		for n in tree.get_nodes_in_group(group):
			var a := n as Node2D
			if a == null or not is_instance_valid(a) or a.is_queued_for_deletion():
				continue
			if a.has_method("is_alive") and not a.is_alive():
				continue
			if "alive" in a and not a.alive:
				continue
			_all.append(a)
			var c := _cell(a.global_position)
			var bucket: Array = _cells.get(c, [])
			if bucket.is_empty():
				_cells[c] = bucket
			bucket.append(a)
	_prune_tokens(_shooters)
	_prune_tokens(_melee)

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

## Actors within radius of pos (optionally only one group). Appends to out.
func query(pos: Vector2, radius: float, out: Array, group := &"") -> void:
	if _frame != Engine.get_physics_frames():
		rebuild()
	var r2 := radius * radius
	var c0 := _cell(pos - Vector2(radius, radius))
	var c1 := _cell(pos + Vector2(radius, radius))
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var bucket: Array = _cells.get(Vector2i(cx, cy), [])
			for a in bucket:
				if not is_instance_valid(a):
					continue
				if group != &"" and not (a as Node).is_in_group(group):
					continue
				if (a as Node2D).global_position.distance_squared_to(pos) <= r2:
					out.append(a)

## Steering push away from nearby enemies (personal space). Cheap: only the
## actor's own and neighbouring cells are visited.
func separation(e: Node2D, space: float, strength: float) -> Vector2:
	var push := Vector2.ZERO
	var near: Array = []
	query(e.global_position, space, near, &"enemies")
	var i := 0
	for o in near:
		if o == e:
			continue
		var d: Vector2 = e.global_position - (o as Node2D).global_position
		var l := d.length()
		if l < 0.01:
			# exactly stacked: split them deterministically
			d = Vector2.from_angle(float(e.get_instance_id() % 628) / 100.0)
			l = 0.01
		push += d / l * (space - l) * strength
		i += 1
		if i >= 8:
			break
	return push

## How many enemies are within radius of pos (for spreading decisions).
func count_near(pos: Vector2, radius: float) -> int:
	var near: Array = []
	query(pos, radius, near, &"enemies")
	return near.size()

# ------------------------------------------------------------ attack tokens
## Ask to shoot at the player this tick. Holders keep their token while they
## stay in combat; the token frees itself when they die or calm down.
func request_shooter(e: Node) -> bool:
	return _request(_shooters, e, int(Difficulty.value("max_shooters")))

func request_melee(e: Node) -> bool:
	return _request(_melee, e, int(Difficulty.value("max_melee")))

func release(e: Node) -> void:
	_shooters.erase(e)
	_melee.erase(e)

func _request(pool: Dictionary, e: Node, cap: int) -> bool:
	if pool.has(e):
		return true
	if pool.size() < maxi(cap, 1):
		pool[e] = true
		return true
	return false

func _prune_tokens(pool: Dictionary) -> void:
	for k in pool.keys():
		if not is_instance_valid(k) or k.is_queued_for_deletion() or not k.is_alive() or not k.is_aware():
			pool.erase(k)
