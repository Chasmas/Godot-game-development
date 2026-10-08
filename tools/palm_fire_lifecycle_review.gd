extends Node2D
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _ready() -> void:
	Engine.set_meta("skip_tasks", true)
	await get_tree().process_frame
	var palm := Decor.PalmTree.new()
	add_child(palm)
	palm.set_process(false)
	palm.start_lightning_fire()
	palm._next_leaf = -1.0
	palm._tick_leaves(0.01)
	check(palm._leaves.is_empty(), "burning crown cannot emit fresh green leaves")
	palm._burn_t = 0.1
	palm._tick_leaves(0.01)
	check(palm._leaves.size() == palm.SECTORS, "consumed crown sectors shed charred fragments")
	palm._tick_leaves(0.01)
	check(palm._leaves.size() == palm.SECTORS, "each consumed sector sheds only once")
	var charred := true
	for fragment in palm._leaves: charred = charred and fragment.c.g < 0.2 and fragment.s < 0.5 * palm.size
	check(charred, "burn fragments are small and dark rather than fresh foliage")
	for frame in 240: palm._tick_leaves(1.0/30.0)
	check(palm._leaves.is_empty() and palm._ground._items.size() == palm.SECTORS, "charred fragments settle into bounded floor debris")
	palm._burn_t = 12.0
	var origin_ok := true
	for i in palm._burn_particles.size():
		origin_ok = origin_ok and palm._burn_particles[i].p.distance_to(palm.fire_anchor(i % palm.SECTORS)) <= 3.0 * palm.size
	check(origin_ok, "ignition embers originate on crown sectors")
	palm._burn_particles.clear()
	palm._burn_t = 0.1
	for sector in palm.SECTORS: palm._add_ember(sector)
	check(palm._burn_particles.is_empty(), "consumed foliage cannot emit fresh embers")
	palm._burn_t = 12.0
	palm._add_ember(0)
	var ember_position: Vector2 = palm._burn_particles[0].p
	palm._tick_burn_particles(0.1)
	check(palm._burn_particles[0].p != ember_position, "surviving embers travel independently from the crown")
	for frame in 120: palm._tick_smoke(1.0/30.0)
	check(not palm._smoke.is_empty() and palm._smoke.size() <= 6, "fire emits a bounded drifting smoke trail")
	palm._burn_t = 0.0
	palm._tick_smoke(3.1)
	check(palm._smoke.is_empty(), "residual smoke expires without new emission after burnout")
	palm._burn_t = 12.0
	var previous := PackedFloat32Array()
	for sector in palm.SECTORS: previous.append(1.0)
	var partial := false
	for elapsed in [0.0,3.0,6.0,9.0,11.9]:
		palm._burn_t = 12.0 - elapsed
		for sector in palm.SECTORS:
			var survival := palm.sector_survival(sector)
			check(survival <= previous[sector] + 0.00001, "frond consumption never reverses sector=%d t=%.1f" % [sector,elapsed])
			partial = partial or (survival > 0.0 and survival < 1.0)
			previous[sector] = survival
	check(partial and previous.count(0.0) == palm.SECTORS, "fronds progressively consume before the final state")
	palm._burn_t = 12.0
	palm._process(3.0)
	check(palm._burn_glow != null and palm._burn_glow.energy > 0.0, "fire light follows the same advanced burn clock")
	var glow := palm._burn_glow
	var remaining := palm._burn_t
	palm.start_lightning_fire()
	check(is_equal_approx(palm._burn_t, remaining), "repeated strike cannot restart an active canopy burn")
	palm._process(13.0)
	check(palm._canopy_burned and palm._burn_t == 0.0, "canopy burn reaches a permanent finished state")
	check(palm._burn_glow == null and glow.energy == 0.0, "fire finish immediately extinguishes and releases its light")
	palm._leaves.clear()
	palm._next_leaf = -1.0
	palm._tick_leaves(0.01)
	check(palm._leaves.is_empty(), "burned canopy cannot shed new green leaves")
	palm._process(2.0)
	check(palm._burn_particles.is_empty(), "burn particles expire after the fire ends")
	palm.start_lightning_fire()
	check(palm._burn_t == 0.0, "destroyed canopy cannot be reignited")
	palm.queue_free()
	for frame in 2: await get_tree().process_frame
	print("PALM FIRE LIFECYCLE REVIEW: ", failures, " failures")
	Game.request_quit(1 if failures else 0)
