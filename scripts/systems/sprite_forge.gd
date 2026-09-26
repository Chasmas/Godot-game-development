class_name SpriteForge
extends RefCounted
## High-detail, cel-shaded character painter (v2 art).
## Characters are built from shapes (ellipses / capsules / circles) and
## rendered per-pixel into a 2x-resolution texture with a 3-tone cel ramp
## (highlight / base / shade) and a dark ink outline. Lighting is radial
## (top-down), so it stays correct as the sprite rotates to aim.
## Textures are 2x; CharacterVisual draws them at 0.5 scale.

const S := 2.0                  # texture pixels per world pixel
const SIZE := 32                # character canvas (16 world px)
const INK := Color("0b0710")

## Per-palette look: hair style + extras.
const STYLES := {
	"cass":    {"hair": "ponytail", "build": 1.0, "extras": ["star", "jacket_collar"]},
	"guard":   {"hair": "short", "build": 1.0, "extras": ["radio"]},
	"gunner":  {"hair": "slick", "build": 1.0, "extras": ["shades", "chain"]},
	"hunter":  {"hair": "bandana", "build": 1.05, "extras": []},
	"heavy":   {"hair": "bald", "build": 1.3, "extras": ["vest"]},
	"scout":   {"hair": "mullet", "build": 0.95, "extras": ["hawaii"]},
	"riot":    {"hair": "helmet", "build": 1.1, "extras": ["pads"]},
	"boss":    {"hair": "silver", "build": 1.1, "extras": ["tie"]},
	"civilian":{"hair": "short", "build": 1.0, "extras": []},
	"shadow":  {"hair": "short", "build": 1.0, "extras": []},
}

static var _cache: Dictionary = {}
const BAKE_DIR := "res://assets/characters/baked/"

static func _baked(key: String) -> Texture2D:
	var path := BAKE_DIR + key.replace("|", "_") + ".png"
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		_cache[key] = t
		return t
	return null

static func _pal(name: String) -> Dictionary:
	var p: Dictionary = SpriteLib.PALETTES.get(name, SpriteLib.PALETTES["guard"])
	var out := {}
	for k in p.keys():
		out[k] = Color.html("#" + str(p[k]))
	return out

# ---------------------------------------------------------------- shapes
class Shape:
	var kind := 0          # 0 ellipse, 1 capsule, 2 circle
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var r := Vector2.ONE
	var color := Color.WHITE
	var shade := true
	var outline := true
	var pattern := ""
	var bb := Rect2()

	func finish() -> void:
		var lo := Vector2(minf(a.x, b.x if kind == 1 else a.x), minf(a.y, b.y if kind == 1 else a.y)) - r - Vector2.ONE
		var hi := Vector2(maxf(a.x, b.x if kind == 1 else a.x), maxf(a.y, b.y if kind == 1 else a.y)) + r + Vector2.ONE
		bb = Rect2(lo, hi - lo)

	func sdf(p: Vector2) -> float:
		match kind:
			1:
				var pa := p - a
				var ba := b - a
				var h := clampf(pa.dot(ba) / maxf(ba.dot(ba), 0.0001), 0.0, 1.0)
				return (pa - ba * h).length() - r.x
			_:
				var q := (p - a) / r
				return (q.length() - 1.0) * minf(r.x, r.y)

	## 0 at the shape's core, 1 at its rim (for radial cel shading)
	func rim(p: Vector2) -> float:
		match kind:
			1:
				var pa := p - a
				var ba := b - a
				var h := clampf(pa.dot(ba) / maxf(ba.dot(ba), 0.0001), 0.0, 1.0)
				return clampf((pa - ba * h).length() / r.x, 0.0, 1.0)
			_:
				return clampf(((p - a) / r).length(), 0.0, 1.0)

static func ell(c: Vector2, r: Vector2, col: Color, shade := true) -> Shape:
	var s := Shape.new()
	s.kind = 0
	s.a = c
	s.r = r
	s.color = col
	s.shade = shade
	return s

static func cap(a: Vector2, b: Vector2, rad: float, col: Color) -> Shape:
	var s := Shape.new()
	s.kind = 1
	s.a = a
	s.b = b
	s.r = Vector2(rad, rad)
	s.color = col
	return s

## Render shapes (painter's order) into an image with cel shading + outline.
static func _render(shapes: Array, w: int, h: int) -> Image:
	for sh in shapes:
		(sh as Shape).finish()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var owner := PackedInt32Array()
	owner.resize(w * h)
	owner.fill(-1)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			for i in range(shapes.size() - 1, -1, -1):
				var s: Shape = shapes[i]
				if not s.bb.has_point(p):
					continue
				if s.sdf(p) <= 0.0:
					owner[y * w + x] = i
					var c := s.color
					if s.shade:
						var rim := s.rim(p)
						# 3-tone cel ramp: highlight core, base, shade rim
						if rim < 0.38:
							c = c.lightened(0.22)
						elif rim > 0.78:
							c = c.darkened(0.28)
					if s.pattern == "hawaii" and ((x / 3 + y / 3) % 3 == 0):
						c = Color("e05a8a") if (x + y) % 2 == 0 else Color("30b0e0")
					img.set_pixel(x, y, c)
					break
	# ink outline: any empty pixel touching a filled one, plus internal
	# edges between different shapes (gives the cel "line art" look)
	var out := img.duplicate()
	for y in h:
		for x in w:
			var o := owner[y * w + x]
			var edge := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				var no := -1 if (nx < 0 or ny < 0 or nx >= w or ny >= h) else owner[ny * w + nx]
				if o == -1 and no != -1 and (shapes[no] as Shape).outline:
					edge = true
				elif o != -1 and no != -1 and no != o and o > no and (shapes[o] as Shape).outline:
					edge = true
			if edge:
				out.set_pixel(x, y, INK if o == -1 else img.get_pixel(x, y).darkened(0.55))
	return out

# ---------------------------------------------------------------- characters
static func torso(pose: String, palette: String) -> Texture2D:
	var key := "t|%s|%s" % [palette, pose]
	if _cache.has(key):
		return _cache[key]
	var bk := _baked(key)
	if bk:
		return bk
	var P := _pal(palette)
	var st: Dictionary = STYLES.get(palette, STYLES["guard"])
	var bw: float = st.build
	var c := Vector2(15, 16)
	var shapes: Array = []
	var top: Color = P.get("j", Color.GRAY)
	var skin: Color = P.get("s", Color.BISQUE)
	var sleeve: Color = P.get("J", top.darkened(0.2))
	var extras: Array = st.extras
	# arm targets (texture space, facing +x) per pose
	var sh_l := c + Vector2(0, -8.5 * bw)     # left shoulder (screen up when facing right)
	var sh_r := c + Vector2(0, 8.5 * bw)
	var hand_l := c + Vector2(6, -7)
	var hand_r := c + Vector2(6, 7)
	match pose:
		"aim_one":
			hand_l = c + Vector2(3, -9)
			hand_r = c + Vector2(12, 3)
		"aim_two":
			hand_l = c + Vector2(9, -2)
			hand_r = c + Vector2(11, 3)
		"aim_dual":
			# both arms out, a gun in each hand
			hand_l = c + Vector2(12, -4)
			hand_r = c + Vector2(12, 4)
		"melee":
			hand_l = c + Vector2(5, -8)
			hand_r = c + Vector2(8, 7)
		"punch_l":
			hand_l = c + Vector2(14, -4)
			hand_r = c + Vector2(5, 7)
		"punch_r":
			hand_l = c + Vector2(5, -7)
			hand_r = c + Vector2(14, 4)
	# arms first (under shoulders)
	shapes.append(cap(sh_l, hand_l, 2.6, sleeve))
	shapes.append(cap(sh_r, hand_r, 2.6, sleeve))
	shapes.append(ell(hand_l, Vector2(2.4, 2.4), skin))
	shapes.append(ell(hand_r, Vector2(2.4, 2.4), skin))
	# shoulders / torso
	var body := ell(c, Vector2(6.0 * bw, 10.5 * bw), top)
	if "hawaii" in extras:
		body.pattern = "hawaii"
	shapes.append(body)
	if "vest" in extras:
		shapes.append(ell(c + Vector2(0.5, 0), Vector2(5.0 * bw, 8.5 * bw), Color("3a2413")))
	if "pads" in extras:
		shapes.append(ell(sh_l + Vector2(0, 1.5), Vector2(3.5, 3), Color("2e3a60")))
		shapes.append(ell(sh_r - Vector2(0, 1.5), Vector2(3.5, 3), Color("2e3a60")))
	if "jacket_collar" in extras:
		shapes.append(ell(c + Vector2(3, 0), Vector2(2.5, 5.5), top.darkened(0.35)))
	if "tie" in extras:
		var tie := ell(c + Vector2(5.2, 0), Vector2(1.6, 1.3), Color("7a1030"))
		shapes.append(tie)
	if "chain" in extras:
		shapes.append(ell(c + Vector2(4.8, 0), Vector2(1.2, 4.5), Color("ffd23f"), false))
	if "radio" in extras:
		var rd := ell(sh_l + Vector2(1, 2), Vector2(1.5, 1.5), Color("222222"))
		shapes.append(rd)
	# head
	var hc := c + Vector2(1.5, 0)
	var hair: Color = P.get("h", Color.BLACK)
	shapes.append(ell(hc, Vector2(5.2, 5.2), skin))
	match str(st.hair):
		"bald":
			var shine := ell(hc + Vector2(-1, -1), Vector2(1.6, 1.2), skin.lightened(0.45), false)
			shine.outline = false
			shapes.append(shine)
		"helmet":
			shapes.append(ell(hc - Vector2(0.5, 0), Vector2(5.8, 5.8), Color("20202a")))
			var visor := cap(hc + Vector2(3.5, -4), hc + Vector2(3.5, 4), 1.4, Color("7ad0ff"))
			shapes.append(visor)
		"bandana":
			shapes.append(ell(hc - Vector2(1.5, 0), Vector2(4.6, 5.0), hair))
			shapes.append(cap(hc + Vector2(1, -5), hc + Vector2(1, 5), 1.3, P.get("a", Color.RED)))
			shapes.append(cap(hc - Vector2(4.5, 0), hc - Vector2(8, -1.5), 1.1, P.get("a", Color.RED)))
		"ponytail":
			shapes.append(cap(hc - Vector2(3, 0), hc - Vector2(9.5, 0.5), 2.0, hair))
			shapes.append(ell(hc - Vector2(1.6, 0), Vector2(4.8, 5.4), hair))
			var hl := ell(hc - Vector2(2.5, -1.5), Vector2(1.8, 1.0), hair.lightened(0.35), false)
			hl.outline = false
			shapes.append(hl)
		"mullet":
			shapes.append(ell(hc - Vector2(2.2, 0), Vector2(4.8, 5.6), hair))
		"slick":
			shapes.append(ell(hc - Vector2(1.8, 0), Vector2(4.4, 5.1), hair))
			var sl := ell(hc - Vector2(2, 0), Vector2(3.5, 0.6), hair.lightened(0.4), false)
			sl.outline = false
			shapes.append(sl)
		"silver":
			shapes.append(ell(hc - Vector2(1.9, 0), Vector2(4.4, 5.1), hair))
			var sv := ell(hc - Vector2(2.5, 1.5), Vector2(2.6, 0.7), Color.WHITE, false)
			sv.outline = false
			shapes.append(sv)
		_:
			shapes.append(ell(hc - Vector2(1.8, 0), Vector2(4.4, 5.1), hair))
	# nose + ears
	shapes.append(ell(hc + Vector2(5, 0), Vector2(1.2, 1.1), skin.darkened(0.1)))
	if str(st.hair) != "helmet":
		shapes.append(ell(hc + Vector2(0.5, -5.1), Vector2(1.1, 0.9), skin.darkened(0.15)))
		shapes.append(ell(hc + Vector2(0.5, 5.1), Vector2(1.1, 0.9), skin.darkened(0.15)))
	if "shades" in extras:
		shapes.append(cap(hc + Vector2(3.6, -3), hc + Vector2(3.6, 3), 1.1, Color("101018")))
	var img := _render(shapes, SIZE, SIZE)
	if "star" in extras:
		_star(img, hc + Vector2(2.5, 2.2), 2.2, Color("ffd23f"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func _star(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(x + 0.5, y + 0.5) - c
			var ang := fposmod(d.angle() + PI * 0.5, TAU / 5.0) - TAU / 10.0
			var lim := r * (0.45 + 0.55 * (1.0 - absf(ang) / (TAU / 10.0)))
			if d.length() <= lim:
				img.set_pixel(x, y, col)

static func legs(frame: int, palette: String) -> Texture2D:
	var key := "l|%s|%d" % [palette, frame]
	if _cache.has(key):
		return _cache[key]
	var bk := _baked(key)
	if bk:
		return bk
	var P := _pal(palette)
	var st: Dictionary = STYLES.get(palette, STYLES["guard"])
	var bw: float = st.build
	var c := Vector2(15, 16)
	var pants: Color = P.get("p", Color.DIM_GRAY)
	var shoe: Color = P.get("P", Color.BLACK)
	var off: float = [0.0, 5.5, -5.5][frame % 3]
	var hip_l := c + Vector2(0, -3.8 * bw)
	var hip_r := c + Vector2(0, 3.8 * bw)
	var foot_l := hip_l + Vector2(3.0 + off, -0.5)
	var foot_r := hip_r + Vector2(3.0 - off, 0.5)
	var shapes: Array = [
		cap(hip_l, foot_l, 2.7 * bw, pants), cap(hip_r, foot_r, 2.7 * bw, pants),
		ell(foot_l + Vector2(1.6, 0), Vector2(2.6, 2.1), shoe), ell(foot_r + Vector2(1.6, 0), Vector2(2.6, 2.1), shoe),
	]
	var tex := ImageTexture.create_from_image(_render(shapes, SIZE, SIZE))
	_cache[key] = tex
	return tex

## Body lying on its back (48x32 tex), head to the right.
static func corpse(palette: String, downed := false, missing := "") -> Texture2D:
	var key := "c|%s|%s" % [palette, downed] + ("" if missing == "" else "|" + missing)
	if _cache.has(key):
		return _cache[key]
	var bk := _baked(key)
	if bk:
		return bk
	var P := _pal(palette)
	var st: Dictionary = STYLES.get(palette, STYLES["guard"])
	var bw: float = st.build
	var c := Vector2(24, 16)
	var top: Color = P.get("j", Color.GRAY)
	var skin: Color = P.get("s", Color.BISQUE)
	var pants: Color = P.get("p", Color.DIM_GRAY)
	var hair: Color = P.get("h", Color.BLACK)
	var spread := 6.0 if downed else 3.0
	var shapes: Array = [
		cap(c + Vector2(-6, -3), c + Vector2(-17, -5 - spread * 0.3), 2.8, pants),
		cap(c + Vector2(-6, 3), c + Vector2(-16, 6 + spread * 0.4), 2.8, pants),
		ell(c + Vector2(-18, -5 - spread * 0.3), Vector2(2.0, 2.4), P.get("P", Color.BLACK)),
		ell(c + Vector2(-17, 6 + spread * 0.4), Vector2(2.0, 2.4), P.get("P", Color.BLACK)),
		cap(c + Vector2(3, -7 * bw), c + Vector2(7 + spread, -12 - spread), 2.4, P.get("J", top)),
		cap(c + Vector2(3, 7 * bw), c + Vector2(4 - spread * 0.5, 13 + spread * 0.5), 2.4, P.get("J", top)),
		ell(c + Vector2(7 + spread, -12 - spread), Vector2(2.2, 2.2), skin),
		ell(c + Vector2(4 - spread * 0.5, 13 + spread * 0.5), Vector2(2.2, 2.2), skin),
		ell(c, Vector2(9.0, 8.0 * bw), top),
		ell(c + Vector2(12, 0), Vector2(5.0, 5.0), skin),
	]
	if missing == "arm":
		shapes.remove_at(7)   # hand
		shapes.remove_at(5)   # sleeve
		shapes.append(ell(c + Vector2(3, 7 * bw), Vector2(2.6, 2.6), Color("8a0a16")))
	if missing == "head":
		shapes.remove_at(shapes.size() - 1)
		shapes.append(ell(c + Vector2(8.5, 0), Vector2(3.0, 3.6), Color("8a0a16")))
		shapes.append(ell(c + Vector2(9.5, 0), Vector2(1.4, 1.6), Color("efe6d8")))
		var tex0 := ImageTexture.create_from_image(_render(shapes, 48, 32))
		_cache[key] = tex0
		return tex0
	if str(st.hair) == "helmet":
		shapes.append(ell(c + Vector2(12, 0), Vector2(5.5, 5.5), Color("20202a")))
	elif str(st.hair) != "bald":
		shapes.append(ell(c + Vector2(14, 0), Vector2(3.4, 5.0), hair))
	var tex := ImageTexture.create_from_image(_render(shapes, 48, 32))
	_cache[key] = tex
	return tex

## Hand position in WORLD pixels relative to the sprite centre for a pose.
static func hand_world(pose: String) -> Vector2:
	match pose:
		"aim_one": return Vector2(5.5, 1.5)
		"aim_two": return Vector2(4.5, 0.5)
		"aim_dual": return Vector2(5.5, 2.0)
		"aim_dual_l": return Vector2(5.5, -2.0)
		"melee": return Vector2(3.5, 3.5)
	return Vector2(3, 3)
