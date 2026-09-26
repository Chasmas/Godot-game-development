class_name TextFX
extends RefCounted
## Animated dialogue text and the babble voice that goes with it.
##
## TextFX.Pop is a RichTextEffect: every letter pops in as it is typed (rises,
## scales down from a little too big, fades up) and then moves with the
## line's mood: angry lines shake, scared lines tremble, shocked lines jolt,
## the phone voice wavers. The dialogue box and the speech bubbles share the
## letter maths (letter_pose) so both feel the same.
##
## TextFX.voice_grain() picks the babble sample for the letter being typed:
## the vowel follows the text, the timbre follows the speaker (in the room,
## on the phone, on TV, the answering machine).

## How many characters a letter takes to settle after it appears.
const SETTLE := 4.0

## Offset, scale and alpha for letter `i` when `shown` letters are revealed.
## `t` is the running clock (for the ongoing mood motion).
static func letter_pose(i: int, shown: float, t: float, mood: String) -> Dictionary:
	var age := shown - float(i)
	if age <= 0.0:
		return {"visible": false}
	var k := clampf(age / SETTLE, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var off := Vector2(0.0, (1.0 - e) * 6.0)
	var sc := lerpf(1.35, 1.0, e)
	var a := clampf(age / 1.5, 0.0, 1.0)
	match mood:
		"angry":
			var h := float((i * 7919 + int(t * 30.0) * 104729) % 1000) / 1000.0
			var h2 := float((i * 104723 + int(t * 30.0) * 7907) % 1000) / 1000.0
			off += Vector2(h - 0.5, h2 - 0.5) * 2.4
		"scared":
			off += Vector2(sin(t * 38.0 + i * 1.7), cos(t * 31.0 + i * 2.3)) * 0.8
		"shock":
			off.y -= sin(clampf(age / 3.0, 0.0, 1.0) * PI) * 5.0
			sc += (1.0 - e) * 0.4
		"phone":
			off.y += sin(t * 5.0 + i * 0.45) * 1.2
		"sad":
			off.y = -(1.0 - e) * 4.0   # letters sink in rather than pop
			sc = 1.0
		"dream":
			off.y += sin(t * 2.2 + i * 0.35) * 1.6
	return {"visible": true, "offset": off, "scale": sc, "alpha": a}


class Pop extends RichTextEffect:
	var bbcode := "pop"
	var shown := 0.0
	var mood := ""
	var clock := 0.0

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		var p := TextFX.letter_pose(fx.relative_index, shown, clock, mood)
		if not p.visible:
			fx.visible = false
			return true
		var sc: float = p.scale
		# scale about the glyph's centre (glyphs are placed from the baseline)
		var gw := 9.0
		fx.transform = fx.transform.scaled_local(Vector2(sc, sc))
		fx.offset += p.offset + Vector2(gw * 0.5 * (1.0 - sc), 0.0)
		fx.color.a *= float(p.alpha)
		return true


## Timbre per speaker; anyone not listed talks "in the room".
const VOICE_KIND := {
	"voice": "voxtel", "machine": "voxbot", "anchor": "voxtv", "marv": "voxtv",
}
const VOWELS := {
	"a": "a", "á": "a", "à": "a", "â": "a", "ã": "a",
	"e": "e", "é": "e", "ê": "e", "y": "i",
	"i": "i", "í": "i",
	"o": "o", "ó": "o", "ô": "o", "õ": "o",
	"u": "u", "ú": "u", "w": "u",
}

## The sample for the letter at `i` in `text`: the next vowel from there
## (so "strong" says "o"), in the speaker's timbre.
static func voice_grain(speaker: String, text: String, i: int) -> String:
	var kind: String = VOICE_KIND.get(speaker, "vox")
	var v := "a"
	for j in range(i, mini(i + 6, text.length())):
		var c := text[j].to_lower()
		if VOWELS.has(c):
			v = VOWELS[c]
			break
	return "%s_%s%d" % [kind, v, 1 + (i / 2) % 2]

## Speaking pitch for a speaker: authored pitch, a little random wobble,
## and a lift at the end of a question.
static func voice_pitch(base: float, text: String, i: int) -> float:
	var p := base * randf_range(0.93, 1.07)
	var q := text.strip_edges().ends_with("?")
	if q and i > text.length() - 10:
		p *= 1.12
	return p

## Letters worth a voice grain: every other letter, never spaces or
## punctuation (so pauses are silent).
static func speaks(text: String, i: int) -> bool:
	if i < 0 or i >= text.length():
		return false
	var c := text[i]
	return c != " " and c != "." and c != "," and c != "!" and c != "?" and c != "…" and c != "-" and c != "\n"
