class_name SpriteForge
extends RefCounted
## High-detail, cel-shaded character painter (v2 art).
## Characters are built from shapes (ellipses / capsules / circles) and
## rendered per-pixel into a 2x-resolution texture with a 3-tone cel ramp
## (highlight / base / shade) and a dark ink outline. Lighting is radial
## (top-down), so it stays correct as the sprite rotates to aim.
## Textures are 2x; CharacterVisual draws them at 0.5 scale.
## Painted at RES x that again (4 texture pixels per world pixel): the
## ImageTexture reports the 2x size (set_size_override), so every sprite,
## offset and hand position stays as it was - there's just four times the
## detail inside: a 5-step light ramp, fine cloth grain, thin inner line art.

const S := 2.0                  # texture pixels per world pixel
const RES := 2                  # supersampling on top of S (the painted detail)
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
	"buck":    {"hair": "cap", "build": 1.3, "extras": ["vest", "stubble", "thick_neck"]},
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
		var src: Texture2D = load(path)
		var img := src.get_image()
		if img == null:
			return null
		var t := _tex(img)
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
	var mat := ""          ## cloth material image (tools/art "materials"), tinted by `color`
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

## Mark shapes by material so the painter can give each its own surface:
## hair gets strands, cloth gets creases and seams, skin stays smooth.
static func _tag(shapes: Array, P: Dictionary, look := "") -> void:
	var hair: Color = P.get("h", Color(-1, -1, -1))
	var cloth := [P.get("j", Color(-1, -1, -1)), P.get("J", Color(-1, -1, -1)), P.get("p", Color(-1, -1, -1))]
	var mats: Array = MATERIALS.get(look, ["", ""])
	for sh in shapes:
		var sp := sh as Shape
		# the fabric itself: top and sleeves, trousers
		if sp.color.is_equal_approx(P.get("j", Color(-1, -1, -1))) or sp.color.is_equal_approx(P.get("J", Color(-1, -1, -1))):
			sp.mat = str(mats[0])
		elif sp.color.is_equal_approx(P.get("p", Color(-1, -1, -1))):
			sp.mat = str(mats[1])
		if sp.pattern != "":
			continue
		if sp.color.is_equal_approx(hair) or sp.color.is_equal_approx(hair.lightened(0.05)):
			sp.pattern = "hair"
		else:
			for cc in cloth:
				if sp.color.is_equal_approx(cc):
					sp.pattern = "cloth"

## What each look is wearing: [top / sleeves, trousers].
const MATERIALS := {
	"cass": ["leather", "denim"], "guard": ["twill", "twill"], "gunner": ["wool", "wool"],
	"hunter": ["canvas", "canvas"], "heavy": ["leather", "denim"], "scout": ["twill", "twill"],
	"riot": ["nylon", "nylon"], "boss": ["wool", "wool"], "sniper": ["canvas", "canvas"],
	"fireman": ["nylon", "nylon"], "stagehand": ["canvas", "denim"], "security": ["wool", "twill"],
	"handler": ["nylon", "canvas"], "bellhop": ["wool", "wool"], "biker": ["leather", "denim"],
	"scrapper": ["canvas", "canvas"], "welder": ["leather", "canvas"], "civilian": ["twill", "denim"],
	"buck": ["canvas", "denim"], "zombie": ["wool", "wool"], "ghoul": ["wool", "wool"],
	"cultist": ["canvas", "canvas"], "demon": ["leather", "leather"], "burnt": ["twill", "denim"],
}

## The material images, greyscale, tiling (assets/art/materials).
static var _mats: Dictionary = {}
static func _mat_img(m: String) -> Image:
	if not _mats.has(m):
		var pth := "res://assets/art/materials/%s.png" % m
		_mats[m] = (load(pth) as Texture2D).get_image() if ResourceLoader.exists(pth) else null
	return _mats[m]

## A texture from a RES-times painted image, reporting the base size.
static func _tex(img: Image) -> ImageTexture:
	var t := ImageTexture.create_from_image(img)
	t.set_size_override(Vector2i(img.get_width() / RES, img.get_height() / RES))
	return t

## Render shapes (painter's order) into an image with cel shading + outline,
## at RES x the canvas size `w` x `h` (shape coordinates stay in canvas px).
static func _render(shapes: Array, w: int, h: int) -> Image:
	for sh in shapes:
		(sh as Shape).finish()
	var W := w * RES
	var H := h * RES
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var owner := PackedInt32Array()
	owner.resize(W * H)
	owner.fill(-1)
	var inv := 1.0 / float(RES)
	for y in H:
		for x in W:
			var p := Vector2((x + 0.5) * inv, (y + 0.5) * inv)
			for i in range(shapes.size() - 1, -1, -1):
				var s: Shape = shapes[i]
				if not s.bb.has_point(p):
					continue
				if s.sdf(p) <= 0.0:
					owner[y * W + x] = i
					var c := s.color
					var rim := s.rim(p)
					if s.shade:
						# 5-step light ramp: specular core, lit, base, turning away, rim shadow
						if rim < 0.2:
							c = c.lightened(0.3)
						elif rim < 0.42:
							c = c.lightened(0.14)
						elif rim > 0.88:
							c = c.darkened(0.34)
						elif rim > 0.7:
							c = c.darkened(0.16)
						# light from the top-left of the canvas: a soft cross-light
						var lit := ((p - s.a).normalized().dot(Vector2(-0.7, -0.7)) if p != s.a else 0.0) * rim
						c = c.lightened(0.06 * maxf(lit, 0.0)) if lit > 0.0 else c.darkened(0.08 * -lit)
					# the fabric: a painted material, tinted by the shape's colour
					var mi: Image = _mat_img(s.mat) if s.mat != "" else null
					if mi:
						var l := mi.get_pixel(x % mi.get_width(), y % mi.get_height()).r
						c = Color(c.r * (0.72 + 0.56 * l), c.g * (0.72 + 0.56 * l), c.b * (0.72 + 0.56 * l), c.a)
					else:
						# cloth / skin grain: a faint, stable weave
						var g := float(((x * 7 + y * 13) ^ (x * y)) % 5) / 5.0 - 0.4
						c = c.lightened(0.03 * g) if g > 0.0 else c.darkened(-0.03 * g)
					var px := int(p.x)
					var py := int(p.y)
					if s.pattern == "hair":
						# strands combed back from the crown, a sheen along them
						var dv := p - s.a
						var ang := atan2(dv.y, dv.x)
						var strand := sin(ang * 22.0 + dv.length() * 0.9)
						if strand > 0.55:
							c = c.darkened(0.22)
						elif strand < -0.8 and rim < 0.6:
							c = c.lightened(0.18)
					elif s.pattern == "cloth":
						# folds: soft diagonal creases, a seam line down the middle
						var fold := sin((p.x + p.y * 0.6) * 1.7 + s.a.x)
						if fold > 0.82:
							c = c.darkened(0.12)
						elif fold < -0.9:
							c = c.lightened(0.07)
						if absf(p.y - s.a.y) < 0.28 and s.r.y > 3.0:
							c = c.darkened(0.18)
					if s.pattern == "hawaii" and ((px / 3 + py / 3) % 3 == 0):
						c = Color("e05a8a") if (px + py) % 2 == 0 else Color("30b0e0")
					img.set_pixel(x, y, c)
					break
	# ink outline: empty pixels within one canvas pixel of a filled one (the
	# silhouette keeps its weight), plus thin internal edges between shapes
	# (fine line art at the painted resolution)
	var out := img.duplicate()
	for y in H:
		for x in W:
			var o := owner[y * W + x]
			var edge := false
			if o == -1:
				for dy in range(-RES, RES + 1):
					for dx in range(-RES, RES + 1):
						if absi(dx) + absi(dy) > RES:
							continue
						var nx: int = x + dx
						var ny: int = y + dy
						if nx < 0 or ny < 0 or nx >= W or ny >= H:
							continue
						var no := owner[ny * W + nx]
						if no != -1 and (shapes[no] as Shape).outline:
							edge = true
							break
					if edge:
						break
				if edge:
					out.set_pixel(x, y, INK)
			else:
				for d in [Vector2i(1, 0), Vector2i(0, 1)]:
					var nx2: int = x + d.x
					var ny2: int = y + d.y
					if nx2 >= W or ny2 >= H:
						continue
					var no2 := owner[ny2 * W + nx2]
					if no2 != -1 and no2 != o and (shapes[maxi(o, no2)] as Shape).outline:
						edge = true
				if edge:
					out.set_pixel(x, y, img.get_pixel(x, y).darkened(0.5))
	return out

# ---------------------------------------------------------------- characters
## The three bosses are paintings from above (tools/art "topdown"), one
## picture for every pose: they hold their weapon out in all of them.
const BOSS_ART := {"boss": "boss_harcourt", "fireman": "boss_dutch", "buck": "boss_buck"}

## A painted cast picture at RES density, reporting the canvas size the
## painted-by-shapes version has, so it drops into the same sprites.
static func _cast(id: String) -> Texture2D:
	var k := "cast|" + id
	if _cache.has(k):
		return _cache[k]
	var pth := "res://assets/art/cast/%s.png" % id
	var t: Texture2D = null
	if ResourceLoader.exists(pth):
		var img: Image = (load(pth) as Texture2D).get_image()
		if img:
			t = _tex(img)
	_cache[k] = t
	return t

## Looks that keep their own drawn silhouette: Cass has to read at a glance
## (ponytail, gold star, the jacket's sheen) - a painting of red hair on a
## red jacket turns into a red blob at game size.
const DRAWN_LOOKS := []

## Painted limbs (tools/art "limbs" -> assets/art/cast/legs_*.png, arm_*.png).
static func _limb(id: String) -> Image:
	var k := "limb|" + id
	if not _cache.has(k):
		var pth := "res://assets/art/cast/%s.png" % id
		var im: Image = null
		if ResourceLoader.exists(pth):
			im = (load(pth) as Texture2D).get_image()
			if im and im.is_compressed():
				im.decompress()
		_cache[k] = im
	return _cache[k]

## Which painted sleeve a look wears.
static func _arm_kind(look: String, extras: Array) -> String:
	if look == "scout":
		return "hawaii"
	if "sleeveless" in extras or look in ["heavy", "hunter", "biker"]:
		return "bare"
	if look in ["riot", "fireman"]:
		return "armour"
	var m: String = str(MATERIALS.get(look, ["twill", "twill"])[0])
	match m:
		"leather":
			return "leather"
		"wool":
			return "wool"
		"nylon":
			return "armour"
	return "twill"

## Paint `src` (an arm lying left -> right) along the segment a -> b, `w`
## wide, tinted, onto `dst` (all in texture pixels).
static func _stamp_segment(dst: Image, src: Image, a: Vector2, b: Vector2, w: float, tint: Color) -> void:
	var ab := b - a
	var L := ab.length()
	if L < 1.0:
		return
	var u := ab / L
	var n := u.orthogonal()
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(w, w)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(w, w)
	var sw := src.get_width()
	var sh := src.get_height()
	for y in range(maxi(0, int(lo.y)), mini(dst.get_height(), int(hi.y) + 1)):
		for x in range(maxi(0, int(lo.x)), mini(dst.get_width(), int(hi.x) + 1)):
			var p := Vector2(x + 0.5, y + 0.5) - a
			var t := p.dot(u) / L
			var d := p.dot(n) / w
			if t < 0.0 or t > 1.0 or absf(d) > 0.5:
				continue
			var c := src.get_pixel(clampi(int(t * sw), 0, sw - 1), clampi(int((d + 0.5) * sh), 0, sh - 1))
			if c.a < 0.1:
				continue
			# tint the sleeve, leave the dark glove / outline alone
			var lum := c.get_luminance()
			if lum > 0.18:
				c = Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
			dst.set_pixel(x, y, dst.get_pixel(x, y).blend(c))

## A character's painted body from above, if there is one.
static func _body_image(name: String) -> Image:
	if name in DRAWN_LOOKS:
		return null
	var k := "body|" + name
	if not _cache.has(k):
		var pth := "res://assets/art/cast/body_%s.png" % name
		_cache[k] = (load(pth) as Texture2D).get_image() if ResourceLoader.exists(pth) else null
	return _cache[k]

static func torso(pose: String, palette: String) -> Texture2D:
	var key := "t|%s|%s" % [palette, pose]
	if _cache.has(key):
		return _cache[key]
	# baked PNGs already hold the painted-body version (the bake paints fresh)
	var bk := _baked(key)
	if bk:
		return bk
	var hybrid := _body_image(base_name(palette))
	if hybrid == null and BOSS_ART.has(base_name(palette)):
		var bt := _cast(BOSS_ART[base_name(palette)])
		if bt:
			_cache[key] = bt
			return bt
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
	var sh_l := c + Vector2(0, -7.8 * bw)     # left shoulder (screen up when facing right)
	var sh_r := c + Vector2(0, 7.8 * bw)
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
			hand_l = c + Vector2(12, -2.6)
			hand_r = c + Vector2(12, 2.6)
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
	var arm_r := (2.6 if not "sleeveless" in extras else 2.3) * (0.78 if hybrid else 1.0)
	var hand_rr := 2.4 * (0.82 if hybrid else 1.0)
	shapes.append(cap(sh_l, hand_l, arm_r, arm_col))
	shapes.append(cap(sh_r, hand_r, arm_r, arm_col))
	shapes.append(ell(hand_l, Vector2(hand_rr, hand_rr), skin))
	shapes.append(ell(hand_r, Vector2(hand_rr, hand_rr), skin))
	if hybrid:
		# the painted head and shoulders (tools/art "bodies") over arms that
		# still take every pose
		if "tape_hand" in extras:
			shapes.append(ell(hand_r, Vector2(2.2, 1.4), Color("e8e0d0"), false))
		_tag(shapes, P, base_name(palette))
		var aimg := _render(shapes, SIZE, SIZE)
		# sized by the shoulders: the painting spans the arms' roots
		var bi: Image = hybrid.duplicate()
		# slimmer than the painting: less depth front to back, shoulders a touch narrower
		var k := (19.5 * bw * RES) / float(bi.get_height())
		bi.resize(maxi(1, int(bi.get_width() * k * 0.92)), maxi(1, int(bi.get_height() * k)), Image.INTERPOLATE_LANCZOS)
		var at := Vector2i((c + Vector2(0.8, 0)) * RES) - Vector2i(bi.get_width() / 2, bi.get_height() / 2)
		aimg.blend_rect(bi, Rect2i(Vector2i.ZERO, bi.get_size()), at)
		var arm_img := _limb("arm_" + _arm_kind(base_name(palette), extras))
		if arm_img:
			# painted arms, shoulder to fist, in her / his own sleeve colour
			var tint: Color = arm_col.lightened(0.25) if not ("sleeveless" in extras) else Color(1, 1, 1)
			if base_name(palette) == "scout":
				tint = Color(1, 1, 1)
			for pr in [[sh_l, hand_l], [sh_r, hand_r]]:
				_stamp_segment(aimg, arm_img, (pr[0] as Vector2) * RES, ((pr[1] as Vector2) + ((pr[1] as Vector2) - (pr[0] as Vector2)).normalized() * 1.5) * RES, arm_r * 1.25 * RES, tint)
			if "star" in extras:
				_star(aimg, (c + Vector2(4.0, 1.8)) * RES, 2.2 * RES, Color("ffd23f"))
			var atex := _tex(aimg)
			_cache[key] = atex
			return atex
		# forearms and hands over the painting: that's what shows the pose
		var fore: Array = []
		for pr in [[sh_l, hand_l], [sh_r, hand_r]]:
			var from: Vector2 = pr[0].lerp(pr[1], 0.5)
			if (pr[1] as Vector2).x - c.x > 4.0:
				fore.append(cap(from, pr[1], arm_r, arm_col))
			fore.append(ell(pr[1], Vector2(hand_rr, hand_rr), skin))
		if "tape_hand" in extras:
			fore.append(ell(hand_r, Vector2(2.0, 1.3), Color("e8e0d0"), false))
		_tag(fore, P, base_name(palette))
		var fimg := _render(fore, SIZE, SIZE)
		aimg.blend_rect(fimg, Rect2i(Vector2i.ZERO, fimg.get_size()), Vector2i.ZERO)
		if "star" in extras:
			# her mark, always readable: the gold star at the top of the head
			_star(aimg, (c + Vector2(4.0, 1.8)) * RES, 2.2 * RES, Color("ffd23f"))
		var htex := _tex(aimg)
		_cache[key] = htex
		return htex
	# shoulders / torso
	var body := ell(c, Vector2(4.9 * bw, 9.6 * bw), top)
	if "hawaii" in extras:
		body.pattern = "hawaii"
	shapes.append(body)
	if "vest" in extras:
		shapes.append(ell(c + Vector2(0.5, 0), Vector2(4.1 * bw, 7.8 * bw), Color("3a2413")))
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
	_tag(shapes, P, base_name(palette))
	var img := _render(shapes, SIZE, SIZE)
	if "star" in extras:
		_star(img, (hc + Vector2(2.5, 2.2)) * RES, 2.2 * RES, Color("ffd23f"))
	var tex := _tex(img)
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
	var st0: Dictionary = STYLES.get(base_name(palette), STYLES["guard"])
	var li := _limb("legs_" + base_name(palette))
	if li:
		# painted legs mid-stride: frame 1 as painted, frame 2 the other foot
		# forward (mirrored), frame 0 feet together (pressed along the step)
		var bw0: float = st0.build
		var img := Image.create(SIZE * RES, SIZE * RES, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var b: Image = li.duplicate()
		var th := 12.0 * bw0 * RES
		var tw := th * float(b.get_width()) / float(b.get_height()) * (0.55 if frame % 3 == 0 else 1.0)
		b.resize(maxi(1, int(tw)), maxi(1, int(th)), Image.INTERPOLATE_LANCZOS)
		if frame % 3 == 2:
			b.flip_y()
		var c0 := Vector2(15, 16)
		img.blend_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(int((c0.x + 2.5) * RES - tw * 0.5), int(c0.y * RES - th * 0.5)))
		var ltex := _tex(img)
		_cache[key] = ltex
		return ltex
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
	_tag(shapes, P, base_name(palette))
	var tex := _tex(_render(shapes, SIZE, SIZE))
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
	# a whole body gets its painting (tools/art "corpses"); a dismembered
	# one or a downed (still breathing) one keeps the painted-by-shapes look
	if not downed and missing == "":
		var pc := _cast("corpse_" + base_name(palette))
		if pc:
			_cache[key] = pc
			return pc
	# the bake has the downed and dismembered versions (tools/bake_sprites.gd)
	var cbk := _baked("c|%s|%s" % [palette, downed] + ("" if missing == "" else "|" + missing))
	if cbk:
		_cache[key] = cbk
		return cbk
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
	_tag(shapes, P, base_name(palette))
	var tex := _tex(_render(shapes, 48, 32))
	_cache[key] = tex
	return tex

## Hand position in WORLD pixels relative to the sprite centre for a pose.
static func hand_world(pose: String) -> Vector2:
	match pose:
		"aim_one": return Vector2(5.5, 1.5)
		"aim_two": return Vector2(4.5, 0.5)
		"aim_dual": return Vector2(5.5, 1.3)
		"aim_dual_l": return Vector2(5.5, -1.3)
		"melee": return Vector2(3.5, 3.5)
	return Vector2(3, 3)
