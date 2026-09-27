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
	"m01_room_204": ROOT + "cutscenes/room_204.png",
	"m01_boss_intro": ROOT + "cutscenes/harcourt_confrontation.png",
	"m01_boss_down": ROOT + "cutscenes/harcourt_confrontation.png",
}

static func texture_for(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func cutscene_texture(id: String) -> Texture2D:
	return texture_for(str(CUTSCENES.get(id, "")))

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
