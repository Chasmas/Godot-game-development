class_name CinematicArt
extends RefCounted
## Central registry for optional high-resolution story/title art.
## The game always keeps its procedural TitleBackdrop as a fallback, so missing
## art never prevents a scene from running.

const ROOT := "res://assets/art/"

const TITLE := ROOT + "title/hotshot_title.webp"

const CUTSCENES := {
	"apartment_1988": ROOT + "cutscenes/apartment_1988.webp",
	"news_1988": ROOT + "cutscenes/news_1988.webp",
}
## In-level scenes played over a painted frame (animated by StoryShot's
## painted_shot shader): dialogue id -> painted shot id.
const PAINTED := {
	"m01_boss_intro": "harcourt_office", "m01_boss_down": "harcourt_office", "m01_room_204": "room_204",
	"m03_boss_intro": "fireman", "m03_boss_down": "fireman_down",
	"m04_boss_intro": "burning_tommy", "m04_boss_down": "burning_tommy", "m01_phone": "lobby_phone",
}

static func texture_for(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func cutscene_texture(id: String) -> Texture2D:
	if PAINTED.has(id):
		return StoryShot.painted_tex(str(PAINTED[id]))
	return texture_for(str(CUTSCENES.get(id, "")))

## The animating material for an in-level scene's frame, or null.
static func cutscene_material(id: String) -> Material:
	if PAINTED.has(id) and StoryShot.painted_tex(str(PAINTED[id])):
		return StoryShot.painted_material(str(PAINTED[id]))
	return null

static func title_texture() -> Texture2D:
	return texture_for(TITLE)

static func make_fullscreen(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
