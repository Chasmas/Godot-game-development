class_name WallArt
extends Node2D
## Things hung on the walls, so a long run of wall tells you where you are:
## framed paintings (thumbnails of the story's own paintings in gilt
## frames), 80s movie posters, small neon signs with their own light, and
## outside, graffiti with drips. Placed along horizontal walls whose face is
## visible (floor just south of them), spaced out, chosen per room type,
## deterministic per level. Level JSON can turn it off: "wall_art": false.

const PAINTINGS := ["motel_night", "desert_road", "hills_fire", "salvage_yard", "galaxy_palace", "polaroid", "burbank_night", "villa_gate", "mom_kitchen", "tommy_car"]
const POSTERS := [
	["HOTSHOT", "COMING SOON", Color("ff3d7f")], ["DESERT ROSE", "WE'RE DYING TO MEET YOU", Color("c21f2f")],
	["NEON VIGIL", "A VANCE PICTURE", Color("35e0ff")], ["BLUE HOUR", "LIVE EVERY NIGHT", Color("5a7aff")],
	["CHANNEL 9", "EYEWITNESS NEWS", Color("ffd23f")], ["SCENE 40", "TAKE ONE", Color("ff7a20")],
]
const NEONS := ["star", "palm", "cocktail", "open", "arrow", "heart", "tv"]
const NEON_COLORS := [Color("ff3d7f"), Color("35e0ff"), Color("ffd23f"), Color("b18cff"), Color("ff5a5a"), Color("5affb0")]
const TAGS := ["TOMMY 4EVER", "CUT!", "★", "HOTSHOT", "WAKE UP", "1988", "NO CUT", "AGAIN", "V.", "ROOM 204"]
const TAG_COLORS := [Color("ff3d7f"), Color("35e0ff"), Color("ffd23f"), Color("7aff6a"), Color("ff8a3d"), Color("f4f0e8")]

## Each place dresses its walls its own way. "outside" is the cycle of what
## goes on exterior faces: "tag" (spray paint, drips), "stencil" (painted
## block letters, no drips), "plate" (a bolted metal sign), "hubcap", "vine"
## (bougainvillea), "sconce" (a lit lantern). Tags, plates, the neon shapes,
## the posters and the paintings indoors are picked from the theme too.
const THEMES := {
	"m01_sunset_palms": {
		"outside": ["tag", "tag", "stencil"],
		"tags": ["TOMMY 4EVER", "CUT!", "★", "ROOM 204", "WAKE UP", "SUNSET GIRLS", "1988", "NO CUT", "AGAIN"],
		"stencils": ["NO PARKING", "GUESTS ONLY", "ICE →"],
		"colors": [Color("ff3d7f"), Color("35e0ff"), Color("ffd23f"), Color("f4f0e8")],
		"neons": ["palm", "cocktail", "heart", "open"],
		"posters": ["psychoe_motel", "lost_angeles", "back_to_the_futon", "top_gum", "mad_maxine"],
		"paintings": [0, 1, 2, 3, 4, 5],
	},
	"m02_yermo_salvage": {
		"outside": ["stencil", "plate", "hubcap", "tag", "hubcap", "plate"],
		"tags": ["BAD DOG", "ARLO WAS HERE", "YERMO 88", "RUN", "WOOF"],
		"stencils": ["KEEP OUT", "DOGS LOOSE", "PARTS $$", "NO DUMPING", "GATE 2"],
		"plates": ["NO TRESPASSING", "BEWARE OF DOG", "CASH ONLY", "U-PULL-IT"],
		"colors": [Color("ff8a3d"), Color("f4f0e8"), Color("ffd23f"), Color("c21f2f")],
		"neons": ["open", "arrow", "star"],
		"posters": ["beware_of_dogg", "mad_maxine", "scarfaced"],
		"paintings": [6, 7],
	},
	"m03_khsc_studios": {
		"outside": ["stencil", "plate", "stencil", "tag"],
		"tags": ["CUT!", "RATINGS KILL", "★", "ROLL 7"],
		"stencils": ["STAGE 9", "QUIET ON SET", "LOT C", "NO SMOKING", "CREW ONLY", "DOCK 3"],
		"plates": ["CAST PARKING", "ON AIR = NO ENTRY", "FIRE LANE", "KHSC 9"],
		"colors": [Color("ffd23f"), Color("f4f0e8"), Color("35e0ff")],
		"neons": ["tv", "star", "arrow"],
		"posters": ["die_hardly", "tron_ish", "backdrafted", "lost_angeles", "scarfaced"],
		"paintings": [8, 9],
	},
	"m04_villa_estrella": {
		"outside": ["vine", "sconce", "vine", "vine", "sconce"],
		"neons": ["star", "cocktail", "heart"],
		"posters": ["scarfaced", "top_gum", "die_hardly", "back_to_the_futon", "tron_ish"],
		"paintings": [10, 11, 12],
	},
}
const DEFAULT_THEME := {"outside": ["tag"], "tags": TAGS, "colors": TAG_COLORS, "neons": NEONS, "posters": [], "paintings": [0, 1, 2, 3, 4, 5]}

var builder: LevelBuilder
var theme: Dictionary = DEFAULT_THEME
var items: Array = []        ## {kind, pos (face centre), seed, ...}
var _t := 0.0

## The parody posters (tools/art "posters", shown as painted frames
## poster_<id>): title, tagline, and the painting used if the poster art
## isn't there.
const POSTER_DEFS := {
	"psychoe_motel": ["PSYCHOE MOTEL", "Check in. Check out. Check again.", "motel_night"],
	"mad_maxine": ["MAD MAXINE", "The road has no speed limit. Neither does she.", "desert_road"],
	"die_hardly": ["DIE HARDLY", "Twelve floors. One barefoot cop. Zero fire exits.", "explosion"],
	"beware_of_dogg": ["BEWARE OF DOGG", "Some yards bite back.", "salvage_yard"],
	"lost_angeles": ["LOST ANGELES", "Everybody's somebody's extra.", "burbank_night"],
	"backdrafted": ["BACKDRAFTED", "It came from the hills. It wants the valley.", "hills_fire"],
	"tron_ish": ["TRON-ISH", "Enter the grid. Bring quarters.", "galaxy_palace"],
	"scarfaced": ["SCARFACED", "Say hello to my little friend's lawyer.", "marv"],
	"top_gum": ["TOP GUM", "I feel the need... the need for mint.", "desert_road"],
	"back_to_the_futon": ["BACK TO THE FUTON", "He's never been late for a nap.", "tommy_car"],
}
## Framed motel paintings: the painting and what you notice looking closer.
const PAINTING_DEFS := [
	["desert_road", "A sunset over a highway. The price sticker is still on the frame: $4.99, Desert Rose Crafts."],
	["motel_night", "The motel itself, painted in the rain by someone who clearly stayed here. There's a tiny gold star in the corner, in lipstick."],
	["hills_fire", "A cheerful view of the hills. The frame is hiding a bullet hole."],
	["galaxy_palace", "An arcade at night. Printed along the bottom: GALAXY PALACE - FREE PLAY WEDNESDAYS."],
	["polaroid", "Somebody framed a Polaroid of a film set. The initials on the border have been scratched off."],
	["salvage_yard", "A junkyard at night, lovingly painted. On the back: 'For Arlo. The dogs came out great.'"],
	# Yermo
	["salvage_yard", "The yard, painted from the office window. Every dog has a name written underneath, in pencil."],
	["desert_road", "A road map of the Mojave, framed behind cracked glass. Somebody circled Yermo twice."],
	# KHSC
	["burbank_night", "A publicity still of the lot at night. EYEWITNESS 9 - WE'RE ALWAYS WATCHING."],
	["galaxy_palace", "A framed set sketch: an arcade, for a pilot that never aired. 'Too loud,' says a note in the margin."],
	# Villa Estrella
	["villa_gate", "The villa's own gate, painted in oils. Commissioned, of course."],
	["hills_fire", "The hills from the terrace at dusk. Gold leaf where the lights of the valley are."],
	["desert_road", "A long road into the desert. Signed in the corner by someone who wanted you to know they were famous."],
]

var level: Node

func build(b: LevelBuilder) -> void:
	builder = b
	level = b.level
	z_index = 7   # over the wall chunks (6)
	theme = THEMES.get(str(b.data.get("id", "")), DEFAULT_THEME)
	# outside: the place's own kind of wall dressing, evenly spaced along each exterior run
	var tag_i := 0
	var out_i := 0
	for y in range(1, b.h - 2):
		var x := 1
		while x < b.w - 1:
			if not _face(x, y) or not WeatherSystem.OUTDOOR.contains(str(b.floor_grid[y + 1][x])):
				x += 1
				continue
			var x0 := x
			while x < b.w - 1 and _face(x, y) and WeatherSystem.OUTDOOR.contains(str(b.floor_grid[y + 1][x])):
				x += 1
			var cx := x0 + 4
			while cx < x - 3:
				_add_outside(Vector2(cx * 16 + 8, y * 16 + 8), str(theme.outside[out_i % theme.outside.size()]), tag_i)
				out_i += 1
				tag_i += 1
				cx += 12

func _add_outside(p: Vector2, kind: String, i: int) -> void:
	var cols: Array = theme.get("colors", TAG_COLORS)
	var col: Color = cols[(i * 3) % cols.size()]
	var sd := fmod(i * 0.37, 1.0)
	match kind:
		"tag":
			var tags: Array = theme.get("tags", TAGS)
			items.append({"kind": "tag", "pos": p, "text": tags[i % tags.size()], "color": col, "rot": 0.06 * sin(i * 1.7), "seed": sd})
		"stencil":
			var st: Array = theme.get("stencils", ["NO PARKING"])
			items.append({"kind": "stencil", "pos": p, "text": st[i % st.size()], "color": col, "seed": sd})
		"plate":
			var pl: Array = theme.get("plates", ["NO TRESPASSING"])
			items.append({"kind": "plate", "pos": p, "text": pl[i % pl.size()], "seed": sd})
		"hubcap", "vine":
			items.append({"kind": kind, "pos": p, "seed": sd})
		"sconce":
			items.append({"kind": "sconce", "pos": p, "seed": sd})
			var l := PointLight2D.new()
			l.texture = SpriteLib.light_texture(128)
			l.texture_scale = 0.55
			l.energy = 0.7
			l.color = Color(1.0, 0.72, 0.4)
			l.position = p + Vector2(0, 14)
			add_child(l)

## What this level hangs indoors: neon shape, poster and painting by index.
func theme_neon(i: int) -> String:
	var n: Array = theme.get("neons", NEONS)
	return n[absi(i) % n.size()]

func theme_poster(i: int) -> String:
	var ps: Array = theme.get("posters", [])
	if ps.is_empty():
		ps = POSTER_DEFS.keys()
	return ps[absi(i) % ps.size()]

func theme_painting(i: int) -> int:
	var ps: Array = theme.get("paintings", [0])
	return int(ps[absi(i) % ps.size()])

## A framed painting on a wall face; inspectable.
func add_painting(pos: Vector2, idx: int) -> void:
	var d: Array = PAINTING_DEFS[idx % PAINTING_DEFS.size()]
	var tex := StoryShot.painted_tex(str(d[0]))
	if tex == null:
		return
	items.append({"kind": "painting", "pos": pos, "tex": tex, "seed": fmod(idx * 0.31, 1.0)})
	_inspect(pos, "LOOK AT THE PAINTING", str(d[0]), tr(str(d[1])))

## A movie poster; inspectable (the poster art full screen, title, tagline).
func add_poster(pos: Vector2, id: String) -> void:
	var d: Array = POSTER_DEFS.get(id, POSTER_DEFS.values()[0])
	var shot := "poster_" + id
	if StoryShot.painted_tex(shot) == null:
		shot = str(d[2])
	items.append({"kind": "poster", "pos": pos, "title": d[0], "sub": d[1], "color": NEON_COLORS[absi(hash(id)) % NEON_COLORS.size()], "seed": 0.5, "tex": StoryShot.painted_tex(shot)})
	_inspect(pos, "READ THE POSTER", shot, "%s
\"%s\"" % [str(d[0]), tr(str(d[1]))], id)

func add_neon(pos: Vector2, shape: String, color: Color) -> void:
	var it := {"kind": "neon", "pos": pos, "shape": shape, "color": color, "seed": fmod(pos.x * 0.013, 10.0)}
	items.append(it)
	var l := PointLight2D.new()
	l.texture = SpriteLib.light_texture(128)
	l.texture_scale = 0.4
	l.energy = 0.6
	l.color = color
	l.position = pos + Vector2(0, 12)
	l.range_item_cull_mask = 1 | 2
	add_child(l)
	it["light"] = l

## The interactable in front of a wall piece: [E] shows it full screen.
func _inspect(pos: Vector2, prompt: String, shot: String, text: String, poster := "") -> void:
	if level == null:
		return
	var it := Interactable.new()
	it.setup("inspect", prompt, "art")
	it.one_shot = false
	it.position = pos + Vector2(0, 14)
	it.set_meta("shot", shot)
	it.set_meta("text", text)
	it.set_meta("poster", poster)
	level.props_root.add_child(it)
	it.used.connect(func(i2: Interactable, _by: Node):
		if Dialogue.active:
			return
		Audio.play("blip", -6.0)
		var pid := str(i2.get_meta("poster", ""))
		if pid != "" and SaveManager.add_poster(pid):
			Events.hint.emit(tr("Poster added to your collection (PLAY VIDEOTAPE)."), 3.0)
		level._run_inline_dialogue({"start": "a", "nodes": {"a": {"speaker": "narration", "text": str(i2.get_meta("text")), "shot": str(i2.get_meta("shot"))}}}))

func _face(x: int, y: int) -> bool:
	if builder.ch(x, y) != "#" or builder.ch(x, y + 1) == "#":
		return false
	var below := builder.ch(x, y + 1)
	return below != "D" and below != "W" and below != "L" and below != " " and builder.floor_grid[y + 1][x] != ""

func _process(delta: float) -> void:
	_t += delta
	for it in items:
		if it.kind == "neon" and it.has("light") and is_instance_valid(it.light):
			it.light.energy = 0.55 * _neon_on(it)
	if Engine.get_process_frames() % 3 == 0:
		queue_redraw()

func _neon_on(it: Dictionary) -> float:
	var s: float = it.seed
	if fmod(_t + s, 6.3) < 0.1 or fmod(_t * 1.3 + s, 4.1) < 0.04:
		return 0.3
	return 0.9 + 0.1 * sin(_t * 30.0 + s)

func _draw() -> void:
	var fd := UIStyle.font_display()
	for it in items:
		var p: Vector2 = it.pos
		match it.kind:
			"painting":
				# gilt frame on the wall top, a lamp's warm wash under it
				var r := Rect2(p + Vector2(-10, -7), Vector2(20, 12))
				draw_rect(r.grow(2.0), Color(0.05, 0.03, 0.02, 0.6))
				draw_rect(r.grow(1.5), Color(0.72, 0.55, 0.22))
				draw_rect(r.grow(0.5), Color(0.4, 0.28, 0.1))
				var tex: Texture2D = it.tex
				var tw := float(tex.get_width())
				var th := float(tex.get_height())
				var src := Rect2(tw * (0.15 + 0.3 * float(it.seed)), th * 0.1, tw * 0.55, th * 0.55 * (12.0 / 20.0) * (tw / th))
				draw_texture_rect_region(tex, r, src)
				draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.25))
			"poster":
				var r2 := Rect2(p + Vector2(-6, -9), Vector2(12, 15))
				var c: Color = it.color
				draw_rect(r2.grow(1.0), Color(0.03, 0.02, 0.05, 0.7))
				var ptex: Texture2D = it.get("tex")
				if ptex:
					var pw := float(ptex.get_width())
					var ph := float(ptex.get_height())
					var src_w := ph * r2.size.x / r2.size.y
					draw_texture_rect_region(ptex, r2, Rect2((pw - src_w) * 0.5, 0, src_w, ph))
					draw_rect(Rect2(r2.position + Vector2(0, r2.size.y - 3), Vector2(r2.size.x, 3)), Color(0.05, 0.02, 0.08, 0.85))
					draw_string(UIStyle.font_bold(), r2.position + Vector2(0.5, r2.size.y - 0.6), str(it.title), HORIZONTAL_ALIGNMENT_LEFT, r2.size.x, 3, c.lightened(0.4))
					continue
				draw_rect(r2, Color(0.08, 0.05, 0.1))
				draw_rect(Rect2(r2.position + Vector2(1, 1), Vector2(r2.size.x - 2, 7)), c.darkened(0.35))
				draw_circle(r2.position + Vector2(7, 5), 2.5, c.lightened(0.2))    # the "art"
				draw_string(UIStyle.font_bold(), r2.position + Vector2(1, 11), str(it.title), HORIZONTAL_ALIGNMENT_LEFT, 12, 4, Color(0.95, 0.9, 0.8))
				draw_rect(Rect2(r2.position + Vector2(2, 12), Vector2(10, 0.6)), c)
				# a torn corner
				draw_colored_polygon(PackedVector2Array([r2.position + Vector2(r2.size.x - 3, 0), r2.position + Vector2(r2.size.x, 0), r2.position + Vector2(r2.size.x, 3)]), Color(0.3, 0.25, 0.3))
			"neon":
				_draw_neon(it)
			"tag":
				var txt: String = it.text
				var col: Color = it.color
				draw_set_transform(p + Vector2(0, -2), it.rot, Vector2.ONE)
				var w := fd.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
				draw_string_outline(fd, Vector2(-w * 0.5, 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 2, Color(0.05, 0.02, 0.08, 0.8))
				draw_string(fd, Vector2(-w * 0.5, 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(col, 0.9))
				# paint drips
				for k in 3:
					var dx := -w * 0.4 + w * 0.4 * k + float(it.seed) * 4.0
					draw_line(Vector2(dx, 3), Vector2(dx, 3 + 2.0 + fmod(float(it.seed) * 13.0 * (k + 1), 4.0)), Color(col, 0.7), 1.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"stencil":
				# painted block capitals: a soft overspray halo, crisp letters, no drips
				var fb := UIStyle.font_bold()
				var st: String = it.text
				var sw := fb.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
				var sc: Color = it.color
				draw_rect(Rect2(p + Vector2(-sw * 0.5 - 2, -5), Vector2(sw + 4, 9)), Color(sc, 0.06))
				draw_string(fb, p + Vector2(-sw * 0.5, 2), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(sc, 0.72))
				# stencil bridges: thin gaps through the letters
				for k in int(sw / 5.0):
					draw_line(p + Vector2(-sw * 0.5 + 2.5 + k * 5.0, -4), p + Vector2(-sw * 0.5 + 2.5 + k * 5.0, -2.5), Color(0.12, 0.1, 0.12, 0.5), 0.6)
			"plate":
				var fb2 := UIStyle.font_bold()
				var pt: String = it.text
				var pw2 := fb2.get_string_size(pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x + 6.0
				var pr := Rect2(p + Vector2(-pw2 * 0.5, -6), Vector2(pw2, 9))
				draw_rect(Rect2(pr.position + Vector2(1, 2), pr.size), Color(0, 0, 0, 0.35))
				draw_rect(pr, Color(0.86, 0.84, 0.78))
				draw_rect(pr.grow(-1.0), Color(0.72, 0.1, 0.1) if ("DOG" in pt or "NO " in pt) else Color(0.12, 0.16, 0.28), false, 1.0)
				draw_string(fb2, pr.position + Vector2(3, 6.5), pt, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.12, 0.08, 0.08))
				# bolts and a rust run under one of them
				draw_circle(pr.position + Vector2(1.8, 1.8), 0.7, Color(0.4, 0.38, 0.36))
				draw_circle(Vector2(pr.end.x - 1.8, pr.position.y + 1.8), 0.7, Color(0.4, 0.38, 0.36))
				draw_line(Vector2(pr.end.x - 1.8, pr.position.y + 2.5), Vector2(pr.end.x - 2.2, pr.end.y + 2.0 + float(it.seed) * 3.0), Color(0.5, 0.25, 0.1, 0.55), 0.8)
			"hubcap":
				# a chrome hubcap nailed up as a trophy
				var hc := p + Vector2(0, -1)
				draw_circle(hc + Vector2(1, 2), 5.5, Color(0, 0, 0, 0.35))
				draw_circle(hc, 5.5, Color(0.55, 0.56, 0.6))
				draw_circle(hc, 4.2, Color(0.75, 0.77, 0.82))
				for k in 6:
					var a := k * TAU / 6.0 + float(it.seed) * 3.0
					draw_line(hc + Vector2.from_angle(a) * 1.5, hc + Vector2.from_angle(a) * 4.0, Color(0.45, 0.46, 0.5), 0.8)
				draw_circle(hc, 1.4, Color(0.35, 0.35, 0.4))
				draw_line(hc + Vector2(-3, -3), hc + Vector2(-1, -4), Color(1, 1, 1, 0.6), 0.8)
			"vine":
				# bougainvillea spilling over the wall top: dark leaves, magenta bracts, swaying a touch
				var sway := sin(_t * 0.9 + float(it.seed) * 6.0) * 0.8
				for k in 9:
					var fx := -9.0 + k * 2.25 + sin(k * 2.3 + float(it.seed) * 5.0) * 1.5
					var fy := -6.0 + fmod(k * 3.7 + float(it.seed) * 11.0, 9.0)
					draw_line(p + Vector2(fx, -7), p + Vector2(fx + sway * (fy + 7) * 0.1, fy), Color(0.12, 0.28, 0.12, 0.9), 1.0)
					draw_circle(p + Vector2(fx + sway * 0.3, fy), 1.8, Color(0.14, 0.34, 0.16))
					if k % 2 == 0:
						draw_circle(p + Vector2(fx + 0.8 + sway * 0.3, fy - 0.6), 1.3, Color("e0348a"))
			"sconce":
				# a brass lantern with a warm bulb and its pool of light on the wall
				draw_circle(p + Vector2(0, -2), 7.0, Color(1.0, 0.7, 0.35, 0.08))
				draw_rect(Rect2(p + Vector2(-1, -8), Vector2(2, 3)), Color(0.45, 0.33, 0.15))
				draw_rect(Rect2(p + Vector2(-2.5, -5), Vector2(5, 6)), Color(0.5, 0.38, 0.16))
				draw_rect(Rect2(p + Vector2(-1.5, -4), Vector2(3, 4)), Color(1.0, 0.85, 0.55))

func _draw_neon(it: Dictionary) -> void:
	var c: Color = it.color
	var on := _neon_on(it)
	var p: Vector2 = it.pos + Vector2(0, -2)
	var lines: Array = []
	match str(it.shape):
		"star":
			for k in 5:
				var a1 := -PI * 0.5 + k * TAU * 2.0 / 5.0
				var a2 := -PI * 0.5 + (k + 1) * TAU * 2.0 / 5.0
				lines.append([Vector2.from_angle(a1) * 6.0, Vector2.from_angle(a2) * 6.0])
		"palm":
			lines.append([Vector2(0, 6), Vector2(1, -3)])
			for k in 5:
				var d := Vector2.from_angle(-PI * 0.5 + (k - 2) * 0.55)
				lines.append([Vector2(1, -3), Vector2(1, -3) + d * 5.0 + Vector2(0, 2)])
		"cocktail":
			lines.append([Vector2(-5, -5), Vector2(5, -5)])
			lines.append([Vector2(-5, -5), Vector2(0, 1)])
			lines.append([Vector2(5, -5), Vector2(0, 1)])
			lines.append([Vector2(0, 1), Vector2(0, 6)])
			lines.append([Vector2(-3, 6), Vector2(3, 6)])
		"arrow":
			lines.append([Vector2(-7, 0), Vector2(6, 0)])
			lines.append([Vector2(6, 0), Vector2(2, -4)])
			lines.append([Vector2(6, 0), Vector2(2, 4)])
		"heart":
			var pts := PackedVector2Array()
			for k in 13:
				var t := k / 12.0 * TAU
				pts.append(Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * 0.35)
			for k in pts.size() - 1:
				lines.append([pts[k], pts[k + 1]])
		"tv":
			lines.append([Vector2(-6, -4), Vector2(6, -4)])
			lines.append([Vector2(6, -4), Vector2(6, 5)])
			lines.append([Vector2(6, 5), Vector2(-6, 5)])
			lines.append([Vector2(-6, 5), Vector2(-6, -4)])
			lines.append([Vector2(-2, -4), Vector2(-4, -8)])
			lines.append([Vector2(2, -4), Vector2(4, -8)])
		_:
			var f := UIStyle.font_display()
			var w := f.get_string_size("OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			draw_string_outline(f, p + Vector2(-w * 0.5, 3), "OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 4, Color(c, 0.25 * on))
			draw_string(f, p + Vector2(-w * 0.5, 3), "OPEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(c.lightened(0.5), on))
			return
	# glow passes, then the bright tube
	for pass_w in [4.0, 2.5]:
		for l in lines:
			draw_line(p + l[0], p + l[1], Color(c, 0.12 * on), pass_w)
	for l in lines:
		draw_line(p + l[0], p + l[1], Color(c.lightened(0.45), on), 1.0)


## The motel's roadside sign: a lit box on two posts, VACANCY buzzing in
## neon, and a little NO plate hanging off chains underneath, swinging in
## the wind, that stutters on and off.
class VacancySign extends Node2D:
	var _t := 0.0
	var _light: PointLight2D
	var _no_on := 0.0

	func _ready() -> void:
		z_index = 44
		_light = PointLight2D.new()
		_light.texture = SpriteLib.light_texture(256)
		_light.texture_scale = 1.2
		_light.color = Color("35e0ff")
		_light.energy = 0.9
		_light.position = Vector2(0, -8)
		add_child(_light)

	func _wind() -> float:
		var w = get_tree().get_first_node_in_group("weather")
		return float(w.wind) if w else 0.2

	func _process(d: float) -> void:
		_t += d
		# NO flickers in bursts: off for a while, then it sputters on
		var cyc := fmod(_t, 7.0)
		_no_on = 1.0 if (cyc > 4.2 and fmod(_t * 9.0, 1.0) > 0.25) else 0.0
		_light.energy = 0.85 * _buzz() + 0.3 * _no_on
		_light.color = Color("35e0ff").lerp(Color("ff3d7f"), _no_on * 0.5)
		queue_redraw()

	func _buzz() -> float:
		return 0.35 if (fmod(_t, 3.3) < 0.08 or fmod(_t, 5.1) < 0.05) else 1.0

	func _draw() -> void:
		var ink := Color(0.05, 0.03, 0.07)
		# posts, their shadows on the lot
		for px in [-20.0, 20.0]:
			draw_line(Vector2(px + 4, 18), Vector2(px + 10, 30), Color(0, 0, 0, 0.3), 3.0)
			draw_rect(Rect2(px - 1.5, -2, 3, 20), Color(0.25, 0.22, 0.28))
			draw_rect(Rect2(px - 1.5, -2, 1, 20), Color(0.45, 0.42, 0.5))
		# the box
		var box := Rect2(-34, -20, 68, 18)
		draw_rect(box.grow(1.5), ink)
		draw_rect(box, Color(0.1, 0.06, 0.14))
		draw_rect(Rect2(box.position, Vector2(box.size.x, 2)), Color(0.35, 0.3, 0.4))
		var f := UIStyle.font_display()
		var on := _buzz()
		var c := Color("35e0ff")
		var w := f.get_string_size("VACANCY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		for g in [6, 3]:
			draw_string_outline(f, Vector2(-w * 0.5, -6), "VACANCY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, g, Color(c, 0.14 * on))
		draw_string(f, Vector2(-w * 0.5, -6), "VACANCY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(c.lightened(0.5), on))
		# NO plate on two chains, swinging
		var sway := sin(_t * 1.8) * (0.12 + _wind() * 0.2)
		draw_set_transform(Vector2(0, -2), sway, Vector2.ONE)
		for cx in [-8.0, 8.0]:
			for k in 3:
				draw_circle(Vector2(cx, 2 + k * 2.5), 0.9, Color(0.55, 0.52, 0.6))
		var plate := Rect2(-12, 9, 24, 10)
		draw_rect(plate.grow(1), ink)
		draw_rect(plate, Color(0.12, 0.06, 0.1))
		var nc := Color("ff3d7f")
		var nw := f.get_string_size("NO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		if _no_on > 0.0:
			draw_string_outline(f, Vector2(-nw * 0.5, 17), "NO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 5, Color(nc, 0.25))
			draw_string(f, Vector2(-nw * 0.5, 17), "NO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, nc.lightened(0.4))
		else:
			draw_string(f, Vector2(-nw * 0.5, 17), "NO", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.35, 0.15, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
