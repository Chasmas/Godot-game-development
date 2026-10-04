class_name Furniture
extends StaticBody2D
## Static furniture drawn procedurally. Low pieces (tables, beds, counters,
## loungers) block walking but not bullets and can be vaulted with a dash.
## Cars are full cover.

var kind := "table"
var rect_size := Vector2(16, 16)
var tint := Color.WHITE
var variant := 0
var style := ""

func setup(p_kind: String, rect: Rect2, p_variant := 0) -> void:
	kind = p_kind
	position = rect.get_center()
	rect_size = rect.size
	variant = p_variant

var _shadow_t := 0.0
var _lights_sig := 0

func _process(delta: float) -> void:
	# lights go out (fuse boxes, the boss): re-throw the shadow when they do
	_shadow_t -= delta
	if _shadow_t <= 0.0:
		_shadow_t = 0.5
		var sig := 0
		for l in get_tree().get_nodes_in_group("lights"):
			if l.on and (l as Node2D).global_position.distance_to(global_position) < l.radius_px:
				sig += 1 + int(l.get_instance_id() % 97)
		if sig != _lights_sig:
			_lights_sig = sig
			queue_redraw()

func _ready() -> void:
	add_to_group("furniture")
	var solid := kind == "car" or kind == "wreck"
	collision_layer = Layers.WORLD if solid else Layers.LOW
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect_size - Vector2(2, 2)
	cs.shape = r
	add_child(cs)
	z_index = -1 if not solid else 1
	if solid:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		var h := rect_size * 0.5 - Vector2(2, 2)
		poly.polygon = PackedVector2Array([-h, Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
		occ.occluder = poly
		add_child(occ)

func _shadow(r: Rect2, off := Vector2(3, 4)) -> void:
	draw_rect(Rect2(r.position + off, r.size), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(r.position + off * 0.5, r.size), Color(0, 0, 0, 0.18))

## 2-tone cel box: base, lit top band, shaded bottom band, ink outline.
func _cel_box(r: Rect2, c: Color, ink: Color) -> void:
	draw_rect(r, c)
	draw_rect(Rect2(r.position, Vector2(r.size.x, maxf(1.0, r.size.y * 0.22))), c.lightened(0.18))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.8), Vector2(r.size.x, r.size.y * 0.2)), c.darkened(0.22))
	draw_rect(r, ink, false, 1.0)

## Painted sprite for this piece, if there is one (see ArtLib).
func _painted() -> Texture2D:
	match kind:
		"car":
			return ArtLib.sprite(ArtLib.CARS[variant % ArtLib.CARS.size()])
		"table":
			return ArtLib.sprite("table_" + style if style != "" else "table")
		"wreck", "bed", "lounger", "washer", "crate", "desk", "cage":
			return ArtLib.sprite(kind)
	return null

## Long runs of table / desk / kennel are several pieces side by side, each
## the painting's own shape, not one painting stretched along the run.
func _pieces(fr: Rect2, pt: Texture2D) -> Array:
	if not kind in ["table", "desk", "cage"]:
		return [fr]
	var tall := fr.size.y > fr.size.x
	var long := fr.size.y if tall else fr.size.x
	var short := fr.size.x if tall else fr.size.y
	var ta := float(pt.get_width()) / float(pt.get_height())
	var n := maxi(1, int(round(long / (short * ta))))
	var out := []
	for i in n:
		if tall:
			out.append(Rect2(fr.position + Vector2(0, fr.size.y * i / n), Vector2(fr.size.x, fr.size.y / n)))
		else:
			out.append(Rect2(fr.position + Vector2(fr.size.x * i / n, 0), Vector2(fr.size.x / n, fr.size.y)))
	return out

func _draw() -> void:
	var r := Rect2(-rect_size * 0.5 + Vector2(1, 1), rect_size - Vector2(2, 2))
	var ink := Color(0.06, 0.03, 0.08)
	var h := absi(int(position.x * 7.0 + position.y * 13.0))
	var pt := _painted()
	if pt:
		var solid := kind == "car" or kind == "wreck"
		var fr := r.grow(1.5) if solid else r.grow(0.5)
		# its own silhouette, thrown away from the lamps around it
		for pr in LightProbe.sample(get_tree(), global_position, 2):
			var dir: Vector2 = pr.dir
			var off := dir * ((5.0 if solid else 3.0) + 6.0 * float(pr.far))
			var col := Color(0.0, 0.0, 0.03, clampf(0.14 + 0.3 * float(pr.k), 0.0, 0.42))
			draw_set_transform(off, 0.0, Vector2.ONE)
			for pc in _pieces(fr, pt):
				ArtLib.draw_fitted(self, pt, pc, h % 2 == 0 and solid, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# parked cars face either way; crates and washers turn a little
		var pi := 0
		for pc in _pieces(fr, pt):
			ArtLib.draw_fitted(self, pt, pc, (h + pi) % 2 == 0 and (solid or kind in ["table", "desk"]))
			pi += 1
		return
	match kind:
		"table":
			_shadow(r)
			_cel_box(r, Color(0.55, 0.32, 0.16), ink)
			for i in int(r.size.y / 4.0):
				draw_line(r.position + Vector2(2, i * 4 + 2), r.position + Vector2(r.size.x - 2, i * 4 + 2.5), Color(0.42, 0.24, 0.11), 1.0)
			# clutter: ashtray, bottle, cards, cash
			var c := r.get_center()
			if h % 3 == 0:
				draw_circle(c + Vector2(-3, 1), 2.2, Color(0.75, 0.75, 0.8))
				draw_circle(c + Vector2(-3, 1), 1.2, Color(0.2, 0.2, 0.22))
			if h % 2 == 0:
				draw_circle(c + Vector2(4, -2), 1.6, Color(0.2, 0.55, 0.3))
				draw_circle(c + Vector2(4, -2), 0.7, Color(0.8, 1, 0.8))
			if h % 5 < 2:
				for k in 3:
					draw_set_transform(c + Vector2(k * 2.0 - 1.0, 2), 0.3 * k - 0.3, Vector2.ONE)
					draw_rect(Rect2(-1.5, -2, 3, 4), Color(0.95, 0.95, 0.9))
					draw_rect(Rect2(-0.5, -1, 1, 1), Color(0.8, 0.1, 0.15))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"counter":
			_shadow(r, Vector2(2, 3))
			_cel_box(r, Color(0.78, 0.72, 0.62), ink)
			# a varnished wood top from the painted floor wood, a laminate lip
			var wood := ArtLib.floor_tex("_")
			if wood:
				var kk := float(wood.get_width()) / 128.0
				draw_texture_rect_region(wood, r.grow(-1.0), Rect2(fposmod(position.x * kk, 256.0), fposmod(position.y * kk, 256.0), r.size.x * kk, r.size.y * kk), Color(0.95, 0.82, 0.7))
				draw_rect(r.grow(-1.0), Color(0.06, 0.03, 0.02, 0.12))
				draw_rect(r, ink, false, 1.0)
				draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), Color(0.35, 0.2, 0.12))
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(0.98, 0.94, 0.85))
			if r.size.x > r.size.y:
				draw_rect(Rect2(r.position + Vector2(4, 3), Vector2(6, 3)), Color(0.2, 0.2, 0.25))     # register
				draw_rect(Rect2(r.position + Vector2(5, 3.5), Vector2(4, 1)), Color(0.4, 1.0, 0.5))
				draw_circle(r.position + Vector2(r.size.x - 8, r.size.y * 0.5), 1.8, Color(0.9, 0.8, 0.2))  # bell
		"bed":
			_shadow(r)
			var sheet: Color = [Color(0.85, 0.3, 0.45), Color(0.3, 0.55, 0.75), Color(0.85, 0.7, 0.35)][variant % 3]
			draw_rect(r, Color(0.3, 0.2, 0.35))
			var mat := r.grow(-1)
			draw_rect(mat, sheet)
			# blanket folds (cel bands) + pattern
			for i in 3:
				var x := mat.position.x + mat.size.x * (0.35 + i * 0.2)
				draw_line(Vector2(x, mat.position.y + 1), Vector2(x + 2, mat.end.y - 1), sheet.darkened(0.25), 1.0)
				draw_line(Vector2(x + 1, mat.position.y + 1), Vector2(x + 3, mat.end.y - 1), sheet.lightened(0.2), 1.0)
			draw_rect(Rect2(mat.position + Vector2(mat.size.x * 0.3, 0), Vector2(2, mat.size.y)), sheet.lightened(0.35))
			var pillow := Rect2(r.position + Vector2(1.5, 1.5), Vector2(5.0, r.size.y - 3))
			draw_rect(pillow, Color(0.95, 0.93, 0.88))
			draw_rect(Rect2(pillow.position + Vector2(3.5, 0), Vector2(1.5, pillow.size.y)), Color(0.78, 0.76, 0.72))
			draw_rect(r, ink, false, 1.0)
		"lounger":
			_shadow(r, Vector2(2, 3))
			draw_rect(r, Color(0.95, 0.95, 0.95))
			for i in int(r.size.x / 3.0):
				draw_line(r.position + Vector2(i * 3 + 1, 0), r.position + Vector2(i * 3 + 1, r.size.y), Color(0.3, 0.75, 0.8), 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(0.85, 0.85, 0.9))
			draw_rect(r, ink, false, 1.0)
			if h % 2 == 0:
				draw_rect(Rect2(r.get_center() + Vector2(-2, 1), Vector2(4, 3)), Color(1, 0.5, 0.7))   # towel
		"desk":
			_shadow(r)
			_cel_box(r, Color(0.35, 0.2, 0.12), ink)
			draw_rect(Rect2(r.get_center() + Vector2(-5, -3), Vector2(7, 5)), Color(0.9, 0.88, 0.8))
			draw_rect(Rect2(r.get_center() + Vector2(-4, -2), Vector2(5, 0.6)), Color(0.4, 0.4, 0.4))
			draw_rect(Rect2(r.get_center() + Vector2(3, -2), Vector2(3, 3)), Color(0.15, 0.15, 0.18))   # phone
			draw_circle(r.get_center() + Vector2(-8, 1), 1.5, Color(0.95, 0.9, 0.6))                  # lamp
		"washer":
			_shadow(r, Vector2(2, 2))
			_cel_box(r, Color(0.9, 0.9, 0.92), ink)
			var cc := r.get_center()
			var rr := minf(r.size.x, r.size.y) * 0.32
			draw_circle(cc, rr + 1.0, Color(0.55, 0.58, 0.62))
			draw_circle(cc, rr, Color(0.25, 0.35, 0.5))
			draw_arc(cc, rr * 0.6, -1.2, 0.6, 6, Color(0.7, 0.85, 1.0, 0.8), 1.0)
		"crate":
			_shadow(r, Vector2(2, 3))
			var wood := Color(0.62, 0.45, 0.25) if variant % 2 == 0 else Color(0.5, 0.38, 0.22)
			_cel_box(r, wood, ink)
			var inner := r.grow(-2)
			draw_rect(inner, wood.darkened(0.12), false, 1.0)
			draw_line(inner.position, inner.end, wood.darkened(0.3), 1.5)
			draw_line(Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), wood.darkened(0.3), 1.5)
			for i in int(r.size.y / 5.0):
				draw_line(r.position + Vector2(1, i * 5 + 3), r.position + Vector2(r.size.x - 1, i * 5 + 3), wood.lightened(0.1), 1.0)
			if h % 3 == 0:
				draw_string(UIStyle.font_bold(), r.get_center() + Vector2(-6, 2), "FRAGILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color(0.7, 0.1, 0.1, 0.8))
		"cage":
			# kennel run: steel frame, chain-link you can see (and shoot) through
			var fr := Color(0.55, 0.58, 0.62)
			draw_rect(r, Color(0.08, 0.06, 0.08, 0.35))
			for gx in range(0, int(r.size.x), 3):
				draw_line(r.position + Vector2(gx, 0), r.position + Vector2(gx + 3, r.size.y), Color(fr, 0.55), 1.0)
				draw_line(r.position + Vector2(gx + 3, 0), r.position + Vector2(gx, r.size.y), Color(fr, 0.4), 1.0)
			draw_rect(r, ink, false, 2.0)
			draw_rect(r.grow(-0.5), fr, false, 1.0)
			# food bowl + bone
			var bc := r.position + Vector2(4, r.size.y - 4)
			draw_circle(bc, 2.2, Color(0.75, 0.15, 0.18))
			draw_circle(bc, 1.4, Color(0.45, 0.3, 0.15))
		"car", "wreck":
			var body: Color = [Color(0.85, 0.15, 0.2), Color(0.15, 0.3, 0.7), Color(0.9, 0.85, 0.75), Color(0.1, 0.1, 0.12), Color(0.2, 0.6, 0.5)][variant % 5]
			if kind == "wreck":
				body = [Color(0.45, 0.26, 0.16), Color(0.36, 0.38, 0.4), Color(0.5, 0.42, 0.3), Color(0.3, 0.22, 0.2)][variant % 4]
			var horiz := rect_size.x > rect_size.y
			_shadow(r.grow(2), Vector2(4, 5))
			# wheels peeking out
			var wheel := Color(0.05, 0.05, 0.07)
			if horiz:
				for wx in [r.position.x + 5, r.end.x - 9]:
					draw_rect(Rect2(wx, r.position.y - 1.5, 5, 2), wheel)
					draw_rect(Rect2(wx, r.end.y - 0.5, 5, 2), wheel)
			else:
				for wy in [r.position.y + 5, r.end.y - 9]:
					draw_rect(Rect2(r.position.x - 1.5, wy, 2, 5), wheel)
					draw_rect(Rect2(r.end.x - 0.5, wy, 2, 5), wheel)
			draw_rect(r, body)
			# cel body shading: lit centre spine, shaded flanks
			if horiz:
				draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.35), Vector2(r.size.x, r.size.y * 0.3)), body.lightened(0.15))
				draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), body.darkened(0.25))
				draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), body.darkened(0.3))
			else:
				draw_rect(Rect2(r.position + Vector2(r.size.x * 0.35, 0), Vector2(r.size.x * 0.3, r.size.y)), body.lightened(0.15))
				draw_rect(Rect2(r.position, Vector2(2, r.size.y)), body.darkened(0.25))
				draw_rect(Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y)), body.darkened(0.3))
			draw_rect(r, ink, false, 1.0)
			if horiz:
				var cab := Rect2(r.position + Vector2(r.size.x * 0.3, 2), Vector2(r.size.x * 0.4, r.size.y - 4))
				draw_rect(cab, body.darkened(0.3))
				draw_rect(Rect2(cab.position + Vector2(1, 1), Vector2(3, cab.size.y - 2)), Color(0.5, 0.75, 0.9, 0.85))
				draw_line(cab.position + Vector2(1.5, 2), cab.position + Vector2(3.5, 5), Color(1, 1, 1, 0.7), 1.0)
				draw_rect(Rect2(cab.end - Vector2(4, cab.size.y - 1), Vector2(3, cab.size.y - 2)), Color(0.4, 0.6, 0.75, 0.85))
				draw_rect(Rect2(cab.position + Vector2(4, 1), Vector2(cab.size.x - 8, 1)), body.lightened(0.35))
				draw_rect(Rect2(r.end - Vector2(2, r.size.y - 2), Vector2(1.5, 3)), Color(1, 0.95, 0.7))
				draw_rect(Rect2(r.end - Vector2(2, 5), Vector2(1.5, 3)), Color(1, 0.95, 0.7))
				draw_rect(Rect2(r.position + Vector2(0.5, 2), Vector2(1, 2)), Color(0.9, 0.1, 0.15))
				draw_rect(Rect2(r.position + Vector2(0.5, r.size.y - 4), Vector2(1, 2)), Color(0.9, 0.1, 0.15))
			else:
				var cab2 := Rect2(r.position + Vector2(2, r.size.y * 0.3), Vector2(r.size.x - 4, r.size.y * 0.4))
				draw_rect(cab2, body.darkened(0.3))
				draw_rect(Rect2(cab2.position + Vector2(1, 1), Vector2(cab2.size.x - 2, 3)), Color(0.5, 0.75, 0.9, 0.85))
				draw_line(cab2.position + Vector2(2, 1.5), cab2.position + Vector2(5, 3.5), Color(1, 1, 1, 0.7), 1.0)
				draw_rect(Rect2(cab2.position + Vector2(1, cab2.size.y - 4), Vector2(cab2.size.x - 2, 3)), Color(0.4, 0.6, 0.75, 0.85))
				draw_rect(Rect2(cab2.position + Vector2(1, 4), Vector2(1, cab2.size.y - 8)), body.lightened(0.35))
				draw_rect(Rect2(r.position + Vector2(1, 0), Vector2(3, 1.5)), Color(1, 0.95, 0.7))
				draw_rect(Rect2(Vector2(r.end.x - 4, r.position.y), Vector2(3, 1.5)), Color(1, 0.95, 0.7))
				draw_rect(Rect2(r.position + Vector2(1, r.size.y - 1.5), Vector2(3, 1)), Color(0.9, 0.1, 0.15))
				draw_rect(Rect2(Vector2(r.end.x - 4, r.end.y - 1.5), Vector2(3, 1)), Color(0.9, 0.1, 0.15))
			if kind == "wreck":
				# rust blooms, dents, smashed glass, missing wheel
				var rng := RandomNumberGenerator.new()
				rng.seed = h
				for i in 6:
					var rp := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
					draw_circle(rp, rng.randf_range(1.5, 3.5), Color(0.55, 0.25, 0.1, 0.8))
					draw_circle(rp + Vector2(0.5, 0.5), rng.randf_range(0.6, 1.4), Color(0.3, 0.12, 0.05, 0.9))
				for i in 3:
					var dp := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
					draw_arc(dp, 2.5, 0.0, PI, 5, body.darkened(0.45), 1.0)
				var cc := r.get_center()
				for i in 5:
					draw_line(cc, cc + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2, 6), Color(0.85, 0.95, 1.0, 0.6), 1.0)
