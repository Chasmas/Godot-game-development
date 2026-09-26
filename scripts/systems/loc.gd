extends Node
## Localization. English source text is the key (gettext style): every
## player-facing string is written in English in code/data, and each
## language is one JSON file in res://data/i18n/<locale>.json mapping
## English -> translation. Missing entries fall back to English.
##
## Godot does the rest: Labels/Buttons auto-translate their text, and code
## that builds strings calls tr() on the format string before filling it in.
## Adding a language = adding one JSON file + a LANGUAGES entry.

signal language_changed(locale: String)

## locale -> name shown in the language picker (in that language)
const LANGUAGES := {"en": "English", "pt_PT": "Português"}
const DIR := "res://data/i18n/"

var _loaded: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for locale in LANGUAGES.keys():
		if locale == "en":
			continue
		_load_locale(locale)
	apply(str(SaveManager.get_setting("language", "en")), false)

func _load_locale(locale: String) -> void:
	var path := DIR + locale + ".json"
	if not FileAccess.file_exists(path):
		push_warning("Loc: no translation file for %s" % locale)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Loc: %s is not valid JSON" % path)
		return
	var tr_res := Translation.new()
	tr_res.locale = locale
	var n := 0
	for k in (parsed as Dictionary).keys():
		if str(k).begins_with("@"):
			continue   # comments / metadata
		var v := str(parsed[k])
		if v != "":
			tr_res.add_message(str(k), v)
			n += 1
	TranslationServer.add_translation(tr_res)
	_loaded[locale] = n

## Switch language (and remember it). Everything visible re-translates.
func apply(locale: String, save := true) -> void:
	if not LANGUAGES.has(locale):
		locale = "en"
	TranslationServer.set_locale(locale)
	if save:
		SaveManager.set_setting("language", locale)
	language_changed.emit(locale)

func current() -> String:
	var l := TranslationServer.get_locale()
	return l if LANGUAGES.has(l) else ("pt_PT" if l.begins_with("pt") else "en")

func count(locale: String) -> int:
	return int(_loaded.get(locale, 0))
