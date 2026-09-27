class_name SpriteLib
extends RefCounted
## Procedural pixel-art library. Every sprite is authored as ASCII below and
## colourised with a per-character palette at runtime, then cached.
## Replace any sprite with a PNG in res://assets/... by registering it in
## OVERRIDES (key -> path) - the rest of the game only asks for keys.
##
## Characters face RIGHT (+X). Canvas center = rotation pivot.

const OVERRIDES := {}

## Palette slots: k outline, h hair, s skin, S skin shade, j top, J top shade,
## p pants, P shoes, a accent (persona), w white, e eyes/dark detail, m metal, M dark metal, x wood, r red
const PALETTES := {
	"cass":    {"h": "6e1f1a", "s": "f0b58c", "S": "c98a66", "j": "d4213d", "J": "8e1128", "p": "2f4f8f", "P": "1a1a24", "a": "ffd23f"},
	"guard":   {"h": "1b1410", "s": "c98f6b", "S": "9e6a4e", "j": "1f9e9a", "J": "0f6663", "p": "22222c", "P": "111118", "a": "e8e8e8"},
	"gunner":  {"h": "2a1a10", "s": "e0a07a", "S": "b07858", "j": "7b3fbf", "J": "4d2380", "p": "7b3fbf", "P": "f0f0f0", "a": "ffffff"},
	"hunter":  {"h": "3a2a1a", "s": "d99a70", "S": "a8704e", "j": "e9e2d0", "J": "b8ae98", "p": "3c4a2a", "P": "20180f", "a": "c21f2f"},
	"heavy":   {"h": "c98f6b", "s": "c98f6b", "S": "9e6a4e", "j": "5a3a22", "J": "3a2413", "p": "2a2a2a", "P": "111111", "a": "888888"},
	"scout":   {"h": "e8c060", "s": "f2c29c", "S": "c89a78", "j": "f2c230", "J": "e05a8a", "p": "e6dcc0", "P": "fafafa", "a": "30b0e0"},
	"riot":    {"h": "20202a", "s": "c08a68", "S": "905e46", "j": "22305a", "J": "141c38", "p": "1a2240", "P": "0c0c14", "a": "9aa6b8"},
	"boss":    {"h": "d8d0c0", "s": "e8b898", "S": "b88a70", "j": "e8dcc0", "J": "b0a488", "p": "e8dcc0", "P": "5a1a2a", "a": "7a1030"},
	"sniper":  {"h": "1a1a14", "s": "c89070", "S": "98684e", "j": "2e3424", "J": "1a1e14", "p": "2a2a20", "P": "0e0e0a", "a": "c81e28"},
	"burnt":    {"h": "3a2418", "s": "6a3020", "S": "3a160e", "j": "2a3a7a", "J": "141c40", "p": "2a2a38", "P": "0c0c10", "a": "ff7a20"},
	"zombie":   {"h": "3a3a30", "s": "8a9a78", "S": "5e6e52", "j": "5a5a6a", "J": "3a3a48", "p": "3a3a30", "P": "1a1a14", "a": "ffd23f"},
	"ghoul":    {"h": "1a1a1a", "s": "c8c8d0", "S": "9090a0", "j": "2a2a30", "J": "18181c", "p": "2a2a30", "P": "101014", "a": "c21f2f"},
	"demon":    {"h": "3a0a0a", "s": "b8282a", "S": "7a1418", "j": "2a0a10", "J": "16050a", "p": "1a0a0e", "P": "0a0406", "a": "ffb030"},
	"cultist":  {"h": "101010", "s": "c09070", "S": "906048", "j": "18101c", "J": "0c080e", "p": "18101c", "P": "0a060c", "a": "ffd23f"},
	"fireman":  {"h": "c89070", "s": "d49a78", "S": "a0684e", "j": "c8ccd4", "J": "8a909c", "p": "b8bcc6", "P": "3a3a40", "a": "ff7a20"},
	"stagehand": {"h": "2a2018", "s": "d8a080", "S": "a87858", "j": "1c1c22", "J": "0e0e12", "p": "1a1a20", "P": "0a0a0e", "a": "ffd23f"},
	"security": {"h": "1a1410", "s": "b88062", "S": "8a5a44", "j": "7a1830", "J": "4a0c1c", "p": "202028", "P": "0c0c10", "a": "e8c860"},
	"handler": {"h": "5a3a20", "s": "d09878", "S": "a07058", "j": "c07028", "J": "804814", "p": "3a3a2a", "P": "1a140c", "a": "e8c040"},
	"bellhop": {"h": "2a1a14", "s": "e0a888", "S": "b07a60", "j": "b01830", "J": "700c1c", "p": "1a1a22", "P": "0c0c10", "a": "ffd23f"},
	"biker":   {"h": "3a2a20", "s": "d8a080", "S": "a8705a", "j": "1a1a1e", "J": "0a0a0e", "p": "2a3a5a", "P": "140e0a", "a": "c0c0c8"},
	"scrapper":{"h": "4a3a2a", "s": "c89070", "S": "986850", "j": "5a6a4a", "J": "3a4a2a", "p": "4a4a3a", "P": "1a1410", "a": "ff8a20"},
	"welder":  {"h": "303038", "s": "c89878", "S": "987058", "j": "6a4a2a", "J": "4a3018", "p": "2a2a30", "P": "141414", "a": "35e0ff"},
	"civilian":{"h": "4a3020", "s": "e8b090", "S": "b88468", "j": "f07ab0", "J": "b04a80", "p": "3070a0", "P": "202020", "a": "ffffff"},
	"shadow":  {"h": "0a0a10", "s": "15121c", "S": "0a0a10", "j": "15121c", "J": "0a0a10", "p": "15121c", "P": "05050a", "a": "ffd23f"},
}
const FIXED := {"k": "0b0710", "w": "f4f0e8", "e": "1a1020", "m": "b8bcc8", "M": "5a5e6a", "x": "8a5a30", "X": "5a3818",
	"r": "c81e28", "R": "7a0c14", "g": "ffd23f", "G": "b08a18", "l": "7ad0ff", "o": "ff8a20", "b": "3a3a48", "n": "2a8a3a", "y": "f8e8a0"}

# ------------------------------------------------------------------ characters (16x16)
const LEGS := [
	[
	"................",
	"................",
	"................",
	"................",
	"................",
	"......PP........",
	"......pp........",
	"......pp........",
	"......pp........",
	"......pp........",
	"......PP........",
	"................",
	"................",
	"................",
	"................",
	"................"],
	[
	"................",
	"................",
	"................",
	"................",
	"................",
	"........PPP.....",
	".......ppp......",
	"......pp........",
	"......pp........",
	"....ppp.........",
	"...PPP..........",
	"................",
	"................",
	"................",
	"................",
	"................"],
	[
	"................",
	"................",
	"................",
	"................",
	"................",
	"...PPP..........",
	"....ppp.........",
	"......pp........",
	"......pp........",
	".......ppp......",
	"........PPP.....",
	"................",
	"................",
	"................",
	"................",
	"................"],
]

const TORSO := {
	"unarmed": [
	"................",
	"................",
	"................",
	"......kkkk......",
	".....kJjjjk.kk..",
	"....kJjjjjkkssk.",
	"....kJjhhhhk.kk.",
	"....kjhhhhssk...",
	"....kjhhhhssk...",
	"....kJjhhhhk.kk.",
	"....kJjjjjkkssk.",
	".....kJjjjk.kk..",
	"......kkkk......",
	"................",
	"................",
	"................"],
	"punch_l": [
	"................",
	"................",
	"................",
	"......kkkk..kk..",
	".....kJjjjkkssk.",
	"....kJjjjjjjjjkk",
	"....kJjhhhhkkkk.",
	"....kjhhhhssk...",
	"....kjhhhhssk...",
	"....kJjhhhhk.kk.",
	"....kJjjjjkkssk.",
	".....kJjjjk.kk..",
	"......kkkk......",
	"................",
	"................",
	"................"],
	"punch_r": [
	"................",
	"................",
	"................",
	"......kkkk......",
	".....kJjjjk.kk..",
	"....kJjjjjkkssk.",
	"....kJjhhhhk.kk.",
	"....kjhhhhssk...",
	"....kjhhhhssk...",
	"....kJjhhhhkkkk.",
	"....kJjjjjjjjjkk",
	".....kJjjjkkssk.",
	"......kkkk..kk..",
	"................",
	"................",
	"................"],
	"aim_one": [
	"................",
	"................",
	"................",
	"......kkkk......",
	".....kJjjjk.....",
	"....kJjjjjk.....",
	"....kJjhhhhk....",
	"....kjhhhhssk...",
	"....kjhhhhssk...",
	"....kJjhhhhkkk..",
	"....kJjjjjjjjjkk",
	".....kJjjjkkkssk",
	"......kkkk...kk.",
	"................",
	"................",
	"................"],
	"aim_two": [
	"................",
	"................",
	"................",
	"......kkkk......",
	".....kJjjjkkk...",
	"....kJjjjjjjjkk.",
	"....kJjhhhhkkssk",
	"....kjhhhhssk.k.",
	"....kjhhhhssk...",
	"....kJjhhhhkkk..",
	"....kJjjjjjjjjkk",
	".....kJjjjkkkssk",
	"......kkkk...kk.",
	"................",
	"................",
	"................"],
	"melee": [
	"................",
	"................",
	"................",
	"......kkkk......",
	".....kJjjjk.kk..",
	"....kJjjjjkkssk.",
	"....kJjhhhhk.kk.",
	"....kjhhhhssk...",
	"....kjhhhhssk...",
	"....kJjhhhhk....",
	"....kJjjjjjkkk..",
	".....kJjjjjjjssk",
	"......kkkk...kk.",
	"................",
	"................",
	"................"],
}

## Persona overlay for the player (drawn over the head).
const PERSONA_STAR := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"...........a....",
	"..........aaa...",
	"...........a....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................"]

## Dead body (24x16), head at right, lying on back.
const CORPSE := [
	"........................",
	"........................",
	"........................",
	"..........kkkk..........",
	"...PPkkk.kJjjjkk........",
	"..kPppppkJjjjjjjk..kkk..",
	"...kkpppJjjjjjjjjkkhhhk.",
	".....kppJjjjjjjjjkhhhssk",
	".....kppJjjjjjjjjkhhhssk",
	"...kkpppJjjjjjjjjkkhhhk.",
	"..kPppppkJjjjjjjk..kkk..",
	"...PPkkk.kJjjjkk........",
	"..........kkkk..........",
	"........................",
	"........................",
	"........................"]

## Downed (knocked flat, face down, arms spread) 20x16
const DOWNED := [
	"....................",
	"....................",
	"........kk..........",
	"........kssk........",
	".......kkjjkk.......",
	"..PPkkkJjjjjjk.kk...",
	".kpppppJjjjjjjkhhk..",
	".kpppppJjjjjjjkhhhk.",
	".kpppppJjjjjjjkhhhk.",
	".kpppppJjjjjjjkhhk..",
	"..PPkkkJjjjjjk.kk...",
	".......kkjjkk.......",
	"........kssk........",
	"........kk..........",
	"....................",
	"...................."]

# ------------------------------------------------------------------ weapons (drawn pointing right)
const WEAPONS := {
	"pistol": [
	"kkkkkk..",
	"kMmmmmk.",
	"kMkkkk..",
	".kk.....",],
	"whisper": [
	"kkkkkkkkkk",
	"kMmmmmMMMk",
	"kMkkkkkkk.",
	".kk.......",],
	"revolver": [
	".kkkkkkk.",
	"kMmmmmmmk",
	"kxkMk....",
	".kxk.....",],
	"hotshot": [
	".kkkkkkk.",
	"kGgggggyk",
	"kxkGk....",
	".kxk.....",],
	"boomstick": [
	"kkkkkkkkkkkkk.",
	"kxxxkMmmmmmmmk",
	"kxxxkMmmmmmmmk",
	".kxkkkkkkkkkk.",],
	"flamethrower": [
	"....kkkkkkkkkkk.",
	"kkkkMMmmmmmmmrrk",
	"kxxkkkMkkkkkkkk.",
	"kxxk.kMk........",
	".kk..kk.........",],
	"smg": [
	"kkkkkkkkk.",
	"kMMmmmmmmk",
	"kMkMk.kk..",
	"..kMk.....",
	"..kk......",],
	"shotgun": [
	"kkkkkkkkkkkkkk..",
	"kxxxxkMmmmmmmmk.",
	".kxxkkkkxxxkkk..",
	"..kk.....kk.....",],
	"rifle": [
	"kkkk..kkkkkkkkkkk",
	"kxxkkkMMmmmmmmmmk",
	".kxxkMkMkkkkkkkk.",
	"..kk..kMk........",
	"......kk.........",],
	"knife": [
	"kkk.kkkk.",
	"kxxkmmmwk",
	"kkk.kkk..",],
	"glass_shard": [
	"kkk.kkk...",
	"krrkllwkk.",
	"kkk.klllwk",
	"....kkkk..",],
	"bat": [
	"...kkkkkkkkk.",
	"kkkxxxxxxxxxk",
	"kXkxxxxxxxxxk",
	"kkkkkkkkkkkk.",],
	"pipe": [
	"kkkkkkkkkkkk",
	"kMmmmmmmmmMk",
	"kkkkkkkkkkkk",],
	"machete": [
	"kkk.kkkkkkkk.",
	"kxxkmmmmmmmwk",
	"kxxkmmmmmmmk.",
	"kkk.kkkkkkk..",],
	"bottle": [
	"...kkkkk..",
	"kkknnnnnk.",
	"kwnnnnnnnk",
	"kkknnnnnk.",
	"...kkkkk..",],
	"broken_bottle": [
	"...kkk.k..",
	"kkknnnkn..",
	"kwnnnnnnk.",
	"kkknnnnk..",
	"...kkk....",],
	"brick": [
	"kkkkkkk",
	"krrrrRk",
	"kRrrRRk",
	"kkkkkkk",],
	"flare": [
	"kkkkkkk.",
	"krrrrrrk",
	"kkkkkkoo",],
	"fists": ["."],
}

static var _cache: Dictionary = {}

static func _hex(c: String) -> Color:
	return Color.html("#" + c)

static func make(rows: Array, palette_name := "guard") -> ImageTexture:
	var key := "%s|%d|%s" % [palette_name, rows.hash(), rows.size()]
	if _cache.has(key):
		return _cache[key]
	var pal: Dictionary = PALETTES.get(palette_name, PALETTES["guard"])
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, (r as String).length())
	var img := Image.create(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var hexs: String = pal.get(ch, FIXED.get(ch, "ff00ff"))
			img.set_pixel(x, y, _hex(hexs))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func torso(pose: String, palette_name: String) -> Texture2D:
	return SpriteForge.torso(pose, palette_name)

static func legs(frame: int, palette_name: String) -> Texture2D:
	return SpriteForge.legs(frame, palette_name)

static func weapon(key: String) -> Texture2D:
	if OVERRIDES.has(key):
		return load(OVERRIDES[key])
	return make(WEAPONS.get(key, WEAPONS["pistol"]), "guard")

static func corpse(palette_name: String, missing := "") -> Texture2D:
	return SpriteForge.corpse(palette_name, false, missing)

static func downed(palette_name: String) -> Texture2D:
	return SpriteForge.corpse(palette_name, true)

static func persona_overlay(palette_name: String) -> Texture2D:
	return make(PERSONA_STAR, palette_name)

static func pose_for_hold(hold: int) -> String:
	match hold:
		WeaponData.Hold.ONE_HAND: return "aim_one"
		WeaponData.Hold.TWO_HAND: return "aim_two"
		WeaponData.Hold.MELEE_ONE, WeaponData.Hold.MELEE_TWO: return "melee"
	return "unarmed"

## Hand position (relative to sprite center) where a held weapon is attached.
static func hand_offset(hold: int) -> Vector2:
	return SpriteForge.hand_world(pose_for_hold(hold))

## Radial light texture for PointLight2D.
static func light_texture(size := 256, falloff := 1.6) -> Texture2D:
	var key := "light%d_%f" % [size, falloff]
	if _cache.has(key):
		return _cache[key]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = size
	t.height = size
	_cache[key] = t
	return t

## Cone texture for flashlights / vision.
static func cone_texture(size := 256) -> Texture2D:
	var key := "cone%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(0, size * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y) - c
			var ang := absf(d.angle())
			var r := d.length() / float(size)
			var a := clampf(1.0 - r, 0.0, 1.0) * clampf(1.0 - ang / 0.42, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
