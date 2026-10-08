class_name FoamSpray
extends Node2D
## The fire extinguisher in her hands: a few seconds of white foam jetting
## where she aims. The first time the jet reaches the target it lands one foam
## hit (DamageInfo meta "foam"); the cloud keeps spraying so the moment reads.

const LIFE := 2.5
const RANGE := 130.0
const CONE := 0.45          ## half-angle (radians) the jet covers

var player: Node2D
var target: Node2D
var _t := 0.0
var _hit := false
var _blobs: Array = []      ## [pos, vel, age, size]

func _ready() -> void:
	z_index = 22
	top_level = true

func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(player):
		queue_free()
		return
	var aim: Vector2 = player.get("aim_dir") if player.get("aim_dir") != null else Vector2.RIGHT
	var vis = player.get("visual")
	var from: Vector2 = vis.muzzle_tip_global() if vis is CharacterVisual else player.global_position
	if _t < LIFE:
		for i in 3:
			var d := aim.rotated(randf_range(-CONE, CONE) * 0.6)
			_blobs.append([from, d * randf_range(160.0, 240.0), 0.0, randf_range(2.0, 4.5)])
		if not _hit and is_instance_valid(target) and target.has_method("take_damage"):
			var to := target.global_position - player.global_position
			if to.length() < RANGE and absf(angle_difference(aim.angle(), to.angle())) < CONE:
				_hit = true
				var info := DamageInfo.make(DamageInfo.Type.MELEE, player, target.global_position, to.normalized(), &"extinguisher", &"environment")
				info.from_player = true
				info.set_meta("foam", true)
				target.take_damage(info)
	for b in _blobs:
		b[2] += delta
		b[1] *= pow(0.08, delta)          # foam slows fast
		b[0] += b[1] * delta
		b[3] += delta * 9.0               # and swells
	_blobs = _blobs.filter(func(b): return b[2] < 0.9)
	if _t >= LIFE and _blobs.is_empty():
		queue_free()
	queue_redraw()

func _draw() -> void:
	for b in _blobs:
		var a: float = clampf(1.0 - b[2] / 0.9, 0.0, 1.0)
		draw_circle(b[0], b[3] + 1.0, Color(0.55, 0.65, 0.75, 0.25 * a))
		draw_circle(b[0], b[3], Color(0.95, 0.97, 1.0, 0.75 * a))
