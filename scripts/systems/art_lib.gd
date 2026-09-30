class_name ArtLib
extends RefCounted
## Painted props and floors (tools/art/process_ai_art.py): top-down sprites
## in assets/art/sprites and seamless floor tiles in assets/art/floors, both
## at the pixel characters' density (2 texels per world pixel). Everything
## falls back to the procedural drawing when a file is missing or the
## "Painted props & floors" option is off.

const FLOORS := {".": "carpet", ",": "tile", "_": "wood", ":": "asphalt", "=": "concrete", "\"": "grass", ";": "dirt", "+": "steel", "-": "stage", "~": "pool_water"}
const CARS := ["car_red", "car_blue", "car_white", "car_black", "dumpster"]
static var _cache: Dictionary = {}

static func enabled() -> bool:
	return bool(SaveManager.get_setting("painted_props", true))

static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		var pixel_path := path.replace("res://assets/art/", "res://assets/art/pixellab_world/")
		var source := pixel_path if ResourceLoader.exists(pixel_path) else path
		_cache[path] = load(source) if ResourceLoader.exists(source) else null
	return _cache[path]

## Sprites are painted at DENSITY x the old 2 texels per world pixel; they
## report their old size (set_size_override) so every rect and every
## get_width() in the game still works in the same units - with the detail.
const DENSITY := 2

static func sprite(id: String) -> Texture2D:
	if not enabled():
		return null
	var key := "sprite:" + id
	if not _cache.has(key):
		var src := _load("res://assets/art/sprites/%s.png" % id)
		var img: Image = src.get_image() if src else null
		if img:
			var t := ImageTexture.create_from_image(img)
			t.set_size_override(Vector2i(img.get_width() / DENSITY, img.get_height() / DENSITY))
			_cache[key] = t
		else:
			_cache[key] = src
	return _cache[key]

## `over`: the level's own "floor_textures" (a mansion's tile is marble).
static func floor_tex(ch: String, over: Dictionary = {}) -> Texture2D:
	if not enabled() or not (FLOORS.has(ch) or over.has(ch)):
		return null
	return _load("res://assets/art/floors/%s.png" % str(over.get(ch, FLOORS.get(ch, ""))))

## The painted wall-top texture for a level (floors/wall_<place>.png).
const WALLS := {"m01_sunset_palms": "wall_motel", "m02_yermo_salvage": "wall_salvage", "m03_khsc_studios": "wall_studio", "m04_villa_estrella": "wall_villa"}
static func wall_tex(level_id: String) -> Texture2D:
	if not enabled():
		return null
	var t := _load("res://assets/art/floors/%s.png" % str(WALLS.get(level_id, "")))
	return t if t else _load("res://assets/art/floors/concrete.png")

## Draw a right-facing sprite into rect r on `ci`, turned to fit the rect
## (tall rects get the sprite rotated a quarter turn; `flip` turns it round).
static func draw_fitted(ci: CanvasItem, tex: Texture2D, r: Rect2, flip := false, mod := Color.WHITE) -> void:
	var tall := r.size.y > r.size.x * 1.15
	var ang := (PI * 0.5 if tall else 0.0) + (PI if flip else 0.0)
	var sz := Vector2(r.size.y, r.size.x) if tall else r.size
	# keep the sprite's own aspect inside the rect
	var ta := float(tex.get_width()) / float(tex.get_height())
	if sz.x / sz.y > ta:
		sz.x = sz.y * ta
	else:
		sz.y = sz.x / ta
	ci.draw_set_transform(r.get_center(), ang, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, mod)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
