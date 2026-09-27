class_name ArtLib
extends RefCounted
## Painted props and floors (tools/art/process_ai_art.py): top-down sprites
## in assets/art/sprites and seamless floor tiles in assets/art/floors, both
## at the pixel characters' density (2 texels per world pixel). Everything
## falls back to the procedural drawing when a file is missing or the
## "Painted props & floors" option is off.

const FLOORS := {".": "carpet", ",": "tile", "_": "wood", ":": "asphalt", "=": "concrete", "\"": "grass", ";": "dirt", "+": "steel", "-": "stage"}
const CARS := ["car_red", "car_blue", "car_white", "car_black", "dumpster"]
static var _cache: Dictionary = {}

static func enabled() -> bool:
	return bool(SaveManager.get_setting("painted_props", true))

static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

static func sprite(id: String) -> Texture2D:
	if not enabled():
		return null
	return _load("res://assets/art/sprites/%s.png" % id)

## `over`: the level's own "floor_textures" (a mansion's tile is marble).
static func floor_tex(ch: String, over: Dictionary = {}) -> Texture2D:
	if not enabled() or not (FLOORS.has(ch) or over.has(ch)):
		return null
	return _load("res://assets/art/floors/%s.png" % str(over.get(ch, FLOORS.get(ch, ""))))

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
