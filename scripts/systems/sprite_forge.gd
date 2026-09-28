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
## Silhouette first: at 16 px on screen a character is read by its outline
## (headgear, shoulders, arms), then by colour. Every archetype gets at least
## one shape nobody else has.
const STYLES := {
	"cass":    {"hair": "ponytail", "build": 1.0, "extras": ["star", "popped_collar", "aviators_up", "sheen", "holster", "scuffs", "tape_hand"]},
	"guard":   {"hair": "cap", "build": 1.0, "extras": ["radio", "epaulettes", "badge"]},
	"gunner":  {"hair": "slick", "build": 1.05, "extras": ["shades", "chain", "power_shoulders"]},
	"hunter":  {"hair": "bandana", "build": 1.05, "extras": ["sleeveless", "dogtags"]},
	"heavy":   {"hair": "bald", "build": 1.35, "extras": ["vest", "thick_neck", "stubble"]},
	"scout":   {"hair": "mullet", "build": 0.95, "extras": ["hawaii", "headphones"]},
	"riot":    {"hair": "helmet", "build": 1.1, "extras": ["pads"]},
	"boss":    {"hair": "silver", "build": 1.1, "extras": ["tie", "lapels", "pocket_square"]},
	"sniper":  {"hair": "cap", "build": 0.95, "extras": ["shades", "radio"]},
	"handler": {"hair": "bandana", "build": 1.1, "extras": ["vest", "stubble"]},
	"bellhop": {"hair": "cap", "build": 0.9, "extras": ["epaulettes", "badge"]},
	"biker":   {"hair": "bandana", "build": 1.2, "extras": ["shades", "chain", "sleeveless"]},
	"scrapper":{"hair": "bald", "build": 1.05, "extras": ["stubble", "dogtags"]},
	"welder":  {"hair": "helmet", "build": 1.15, "extras": ["vest", "thick_neck"]},
	"fireman": {"hair": "bald", "build": 1.45, "extras": ["vest", "thick_neck", "pads"]},
	"stagehand": {"hair": "cap", "build": 1.0, "extras": ["headphones", "tape_hand"]},
	"security": {"hair": "short", "build": 1.1, "extras": ["radio", "badge", "lapels"]},
	"burnt":   {"hair": "short", "build": 1.05, "extras": ["scuffs", "popped_collar"]},
	"zombie":  {"hair": "short", "build": 1.0, "extras": ["scuffs", "stubble", "star"]},
	"ghoul":   {"hair": "bald", "build": 0.9, "extras": ["thick_neck"]},
	"demon":   {"hair": "bald", "build": 1.5, "extras": ["thick_neck", "pads", "star"]},
	"cultist": {"hair": "helmet", "build": 1.0, "extras": ["chain"]},
	"civilian":{"hair": "short", "build": 1.0, "extras": []},
	"shadow":  {"hair": "short", "build": 1.0, "extras": []},
}

## Per-instance looks so a room of guards isn't a room of clones:
## "guard#2" = guard palette, variant 2 (skin tone / hair / trousers).
const VARIANT_SKIN := [0.0, -0.28, 0.12, -0.14]
const VARIANT_HAIR := ["", "3a2618", "8a6a3a", "121014"]
const VARIANT_PANTS := [0.0, 0.12, -0.1, 0.06]

static func base_name(palette: String) -> String:
	var i := palette.find("#")
	return palette if i < 0 else palette.substr(0, i)

static func variant_of(palette: String) -> int:
	var i := palette.find("#")
	return 0 if i < 0 else int(palette.substr(i + 1))

static var _cache: Dictionary = {}
const BAKE_DIR := "res://assets/characters/baked/"

static func baked_path(key: String) -> String:
	return BAKE_DIR + key.replace("|", "_").replace("#", "-v") + ".png"

static var bake_disabled := false   ## the bake tool paints fresh, ignoring old PNGs

static func _baked(key: String) -> Texture2D:
	if bake_disabled:
		return null
	var path := baked_path(key)
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		_cache[key] = t
		return t
	return null

static func _pal(name: String) -> Dictionary:
	var p: Dictionary = SpriteLib.PALETTES.get(base_name(name), SpriteLib.PALETTES["guard"])
	var out := {}
	for k in p.keys():
		out[k] = Color.html("#" + str(p[k]))
	var v := variant_of(name)
	if v > 0:
		var ds: float = VARIANT_SKIN[v % VARIANT_SKIN.size()]
		for k in ["s", "S"]:
			if out.has(k):
				out[k] = (out[k] as Color).darkened(-ds) if ds < 0.0 else (out[k] as Color).lightened(ds)
		var hc: String = VARIANT_HAIR[v % VARIANT_HAIR.size()]
		if hc != "" and base_name(name) != "heavy":
			out["h"] = Color.html("#" + hc)
		var dp: float = VARIANT_PANTS[v % VARIANT_PANTS.size()]
		if out.has("p"):
			out["p"] = (out["p"] as Color).lightened(dp) if dp > 0.0 else (out["p"] as Color).darkened(-dp)
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
	var st: Dictionary = STYLES.get(base_name(palette), STYLES["guard"])
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
	var arm_col := skin.darkened(0.06) if "sleeveless" in extras else sleeve
	shapes.append(cap(sh_l, hand_l, 2.6 if not "sleeveless" in extras else 2.3, arm_col))
	shapes.append(cap(sh_r, hand_r, 2.6 if not "sleeveless" in extras else 2.3, arm_col))
	shapes.append(ell(hand_l, Vector2(2.4, 2.4), skin))
	shapes.append(ell(hand_r, Vector2(2.4, 2.4), skin))
	# shoulders / torso
	var body := ell(c, Vector2(6.0 * bw, 10.5 * bw), top)
	if "hawaii" in extras:
		body.pattern = "hawaii"
	shapes.append(body)
	if "vest" in extras:
		shapes.append(ell(c + Vector2(0.5, 0), Vector2(5.0 * bw, 8.5 * bw), Color("3a2413")))
	if "power_shoulders" in extras:
		# 80s blazer: square padded shoulders stick out past the arms
		shapes.append(ell(sh_l + Vector2(-0.5, 1.0), Vector2(3.4, 3.2), top.lightened(0.08)))
		shapes.append(ell(sh_r - Vector2(0.5, 1.0), Vector2(3.4, 3.2), top.lightened(0.08)))
	if "epaulettes" in extras:
		shapes.append(ell(sh_l + Vector2(0, 2.0), Vector2(2.4, 1.5), sleeve.darkened(0.3)))
		shapes.append(ell(sh_r - Vector2(0, 2.0), Vector2(2.4, 1.5), sleeve.darkened(0.3)))
	if "thick_neck" in extras:
		shapes.append(ell(c + Vector2(0.5, 0), Vector2(4.2, 6.5), skin.darkened(0.12)))
	if "lapels" in extras:
		shapes.append(ell(c + Vector2(3.8, -2.6), Vector2(2.4, 1.3), top.darkened(0.22)))
		shapes.append(ell(c + Vector2(3.8, 2.6), Vector2(2.4, 1.3), top.darkened(0.22)))
	if "pocket_square" in extras:
		shapes.append(ell(c + Vector2(3.0, -5.2), Vector2(0.9, 1.1), Color("c81e5a"), false))
	if "popped_collar" in extras:
		# leather jacket collar turned up either side of the neck
		shapes.append(ell(c + Vector2(2.2, -4.2), Vector2(2.0, 2.6), top.darkened(0.3)))
		shapes.append(ell(c + Vector2(2.2, 4.2), Vector2(2.0, 2.6), top.darkened(0.3)))
	if "sheen" in extras:
		# the main character's jacket catches the light: a bright streak across
		# the shoulder that stays readable in dark rooms
		var sh1 := ell(c + Vector2(-1.5, -5.5 * bw), Vector2(1.0, 2.8), top.lightened(0.5), false)
		sh1.outline = false
		shapes.append(sh1)
	if "holster" in extras:
		# shoulder rig: a worn strap across the jacket, the holster under the arm
		shapes.append(cap(sh_r + Vector2(0.5, -0.5), c + Vector2(-3.0, -4.5), 0.7, Color("3a2012")))
		shapes.append(ell(c + Vector2(-2.6, -5.4), Vector2(1.8, 1.3), Color("2a160c")))
	if "scuffs" in extras:
		# wear on the leather: a couple of pale scrapes and a dark stain
		var sc1 := ell(c + Vector2(-2.5, 3.5), Vector2(1.1, 0.5), top.lightened(0.28), false)
		sc1.outline = false
		shapes.append(sc1)
		var sc2 := ell(c + Vector2(1.0, 6.0), Vector2(0.8, 0.4), top.lightened(0.22), false)
		sc2.outline = false
		shapes.append(sc2)
		var st2 := ell(c + Vector2(-1.0, -2.0), Vector2(0.9, 0.7), top.darkened(0.35), false)
		st2.outline = false
		shapes.append(st2)
	if "tape_hand" in extras:
		# boxer's tape on the knuckles
		shapes.append(ell(hand_r, Vector2(2.2, 1.4), Color("e8e0d0"), false))
	if "dogtags" in extras:
		shapes.append(ell(c + Vector2(4.6, 1.2), Vector2(0.9, 1.1), Color("c8ccd8"), false))
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
		shapes.append(cap(sh_l + Vector2(1, 2), sh_l + Vector2(-2.5, 3.5), 0.45, Color("111111")))   # antenna
	if "badge" in extras:
		shapes.append(ell(c + Vector2(3.5, -4.0), Vector2(1.0, 1.0), Color("ffd23f"), false))
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
			shapes.append(cap(hc - Vector2(4, 0), hc - Vector2(7, 0), 2.2, hair))   # business in the back
		"cap":
			# security guard's peaked cap: crown + a visor sticking out front
			shapes.append(ell(hc - Vector2(0.6, 0), Vector2(4.9, 5.3), Color("1b2a4a")))
			shapes.append(ell(hc + Vector2(3.6, 0), Vector2(2.3, 4.2), Color("0e1528")))
			var capb := ell(hc + Vector2(1.6, 0), Vector2(0.9, 0.9), Color("ffd23f"), false)
			capb.outline = false
			shapes.append(capb)
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
	if "stubble" in extras:
		shapes.append(ell(hc + Vector2(3.4, 0), Vector2(1.9, 3.6), skin.darkened(0.32)))
	shapes.append(ell(hc + Vector2(5, 0), Vector2(1.2, 1.1), skin.darkened(0.1)))
	if str(st.hair) != "helmet" and not "headphones" in extras:
		shapes.append(ell(hc + Vector2(0.5, -5.1), Vector2(1.1, 0.9), skin.darkened(0.15)))
		shapes.append(ell(hc + Vector2(0.5, 5.1), Vector2(1.1, 0.9), skin.darkened(0.15)))
	if "shades" in extras:
		shapes.append(cap(hc + Vector2(3.6, -3), hc + Vector2(3.6, 3), 1.1, Color("101018")))
	if "aviators_up" in extras:
		# sunglasses pushed up into the hair: gold frame glint on top
		shapes.append(cap(hc + Vector2(0.5, -3.6), hc + Vector2(0.5, 3.6), 0.8, Color("2a1a14")))
		var gl := ell(hc + Vector2(0.5, -2.0), Vector2(0.6, 1.0), Color("ffd23f"), false)
		gl.outline = false
		shapes.append(gl)
	if "headphones" in extras:
		# Walkman headphones: band over the top, orange foam on the ears
		shapes.append(cap(hc + Vector2(0, -5.2), hc + Vector2(0, 5.2), 0.7, Color("2a2a30")))
		shapes.append(ell(hc + Vector2(0.5, -5.4), Vector2(1.7, 1.5), Color("ff8a20")))
		shapes.append(ell(hc + Vector2(0.5, 5.4), Vector2(1.7, 1.5), Color("ff8a20")))
	var img := _render(shapes, SIZE, SIZE)
	if "star" in extras:
		_star(img, hc + Vector2(2.5, 2.2), 2.2, Color("ffd23f"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Paint every texture a set of looks will need (all poses, walk frames,
## downed, corpse) up front. Painting is per-pixel GDScript: doing it the
## first time an enemy punches or falls caused visible hitches in big
## fights. Called during level load, behind the fade. Returns ms spent.
const PREWARM_POSES := ["unarmed", "aim_one", "aim_two", "melee", "punch_l", "punch_r"]

static func prewarm(looks: Array) -> float:
	var t0 := Time.get_ticks_usec()
	for look in looks:
		var l := str(look)
		for pose in PREWARM_POSES:
			torso(pose, l)
		for f in 3:
			legs(f, l)
		corpse(l, true)
		corpse(l, false)
	return (Time.get_ticks_usec() - t0) / 1000.0

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
	var st: Dictionary = STYLES.get(base_name(palette), STYLES["guard"])
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
## A body on the floor, head to the right: a lean sprawl, not a blob.
## Torso as a narrow capsule from hips to shoulders with a collar and belt,
## the pelvis, two legs bent at the knee, two arms flung out (one up, one
## back), the head tipped over. `pose` (0..3) picks one of four sprawls so a
## room of dead doesn't look stamped. `missing`: head / arm / leg / legs -
## the stump is painted in, the part itself flies off as a gib.
static func corpse(palette: String, downed := false, missing := "", pose := 0) -> Texture2D:
	var key := "c2|%s|%s|%d" % [palette, downed, pose] + ("" if missing == "" else "|" + missing)
	if _cache.has(key):
		return _cache[key]
	var P := _pal(palette)
	var st: Dictionary = STYLES.get(base_name(palette), STYLES["guard"])
	var bw: float = clampf(float(st.build), 0.85, 1.5)
	var c := Vector2(24, 16)
	var top: Color = P.get("j", Color.GRAY)
	var top_s: Color = P.get("J", top.darkened(0.25))
	var skin: Color = P.get("s", Color.BISQUE)
	var pants: Color = P.get("p", Color.DIM_GRAY)
	var shoes: Color = P.get("P", Color.BLACK)
	var hair: Color = P.get("h", Color.BLACK)
	var gore := Color("7a0812")
	var bone := Color("efe6d8")
	# the four sprawls: [left leg bend, right leg bend, up-arm reach, back-arm reach, head tilt]
	var poses := [[3.0, 2.0, 1.0, 1.0, 0.0], [6.0, -1.0, 1.4, 0.6, 1.5], [0.0, 5.0, 0.6, 1.4, -1.5], [4.0, 4.0, 1.2, 1.2, 1.0]]
	var q: Array = poses[posmod(pose, 4)]
	var spread := 6.0 if downed else 2.0
	var flip := -1.0 if pose % 2 == 1 else 1.0     # which side the raised arm is on
	var hips := c + Vector2(-5, 0)
	var chest := c + Vector2(5, 0)
	var shapes: Array = []
	# legs: thigh then shin, knees bent by the pose
	var legs := [
		[hips + Vector2(-1, -2.2 * bw), hips + Vector2(-7, -3.5 - float(q[0]) - spread * 0.3), hips + Vector2(-13, -2.5 - float(q[0]) * 1.4 - spread * 0.3)],
		[hips + Vector2(-1, 2.2 * bw), hips + Vector2(-7, 3.5 + float(q[1]) + spread * 0.3), hips + Vector2(-13, 3.0 + float(q[1]) * 0.6 + spread * 0.4)],
	]
	for li in 2:
		if missing == "legs" or (missing == "leg" and li == 1):
			shapes.append(ell(legs[li][0] + Vector2(-1.5, 0), Vector2(2.2, 2.2), gore))
			shapes.append(ell(legs[li][0] + Vector2(-2.5, 0), Vector2(1.0, 1.1), bone))
			continue
		shapes.append(cap(legs[li][0], legs[li][1], 2.3 * bw, pants))
		shapes.append(cap(legs[li][1], legs[li][2], 2.0, pants.darkened(0.08)))
		shapes.append(ell(legs[li][2] + Vector2(-1.8, 0), Vector2(2.2, 1.7), shoes))
	# pelvis and torso: narrow, with a belt and a collar
	shapes.append(ell(hips + Vector2(-1, 0), Vector2(3.2, 3.2 * bw), pants))
	shapes.append(cap(hips + Vector2(1, 0), chest, 3.6 * bw, top))
	shapes.append(cap(hips + Vector2(0.5, -3.0 * bw), hips + Vector2(0.5, 3.0 * bw), 0.8, Color(0.12, 0.08, 0.06)))
	shapes.append(cap(hips + Vector2(3, -1.5 * bw), chest + Vector2(-1, -1.8 * bw), 1.0, top_s))    # a crease down the shirt
	# arms: upper arm to elbow to hand; one flung up past the head, one back
	var arms := [
		[chest + Vector2(0, -3.6 * bw * flip), chest + Vector2(4.0 * float(q[2]), (-7.5 - spread) * flip), chest + Vector2(9.0 * float(q[2]), (-10.0 - spread) * flip)],
		[chest + Vector2(0, 3.6 * bw * flip), chest + Vector2(-3.0 * float(q[3]), (7.0 + spread * 0.5) * flip), chest + Vector2(-8.0 * float(q[3]), (9.0 + spread * 0.5) * flip)],
	]
	for ai in 2:
		if missing == "arm" and ai == 1:
			shapes.append(ell(arms[ai][0], Vector2(2.4, 2.4), gore))
			shapes.append(ell(arms[ai][0], Vector2(1.0, 1.0), bone))
			continue
		shapes.append(cap(arms[ai][0], arms[ai][1], 1.9, top_s))
		shapes.append(cap(arms[ai][1], arms[ai][2], 1.6, skin if str(st.extras).contains("sleeveless") else top_s.darkened(0.05)))
		shapes.append(ell(arms[ai][2], Vector2(1.6, 1.6), skin))
	shapes.append(ell(chest + Vector2(1.5, 0), Vector2(1.6, 2.4 * bw), top.lightened(0.12)))   # collar
	var head_c := c + Vector2(10.5, float(q[4]))
	if missing == "head":
		shapes.append(ell(head_c + Vector2(-2.5, 0), Vector2(2.8, 3.2), gore))
		shapes.append(ell(head_c + Vector2(-2.0, 0), Vector2(1.2, 1.4), bone))
	else:
		shapes.append(ell(head_c + Vector2(-1.8, 0), Vector2(1.6, 1.8), skin.darkened(0.12)))   # neck
		shapes.append(ell(head_c, Vector2(3.9, 3.8), skin))
		if str(st.hair) == "helmet":
			shapes.append(ell(head_c + Vector2(0.5, 0), Vector2(4.3, 4.2), Color("20202a")))
		elif str(st.hair) == "cap":
			shapes.append(ell(head_c + Vector2(1.5, 0), Vector2(3.4, 4.0), hair.lightened(0.05)))
			shapes.append(ell(head_c + Vector2(4.0, 0), Vector2(1.4, 3.0), top_s))    # the cap's peak
		elif str(st.hair) != "bald":
			shapes.append(ell(head_c + Vector2(2.2, 0), Vector2(2.6, 4.0), hair))
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
