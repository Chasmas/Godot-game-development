class_name StoryShot
extends Control
## Plays the illustrated story shots (assets/art/shots/<id>/<layer>.png,
## painted by tools/art/gen_shots.py): parallax layers under a slow camera
## move, per-layer animation (blinking LEDs, police lights, the clapper
## snapping shut, breathing, flicker) and drawn effects (rain, embers, smoke,
## dust, tape static). Changing shot cuts with a VHS glitch and a short
## cross-fade. Used by cutscenes, the intro and the chapter covers.

const ART := "res://assets/art/shots/%s/%s.png"
const FRAME := Vector2(480, 270)     ## the visible frame inside each 544x306 layer

## Per shot: layers back to front [name, depth]; camera from/to (zoom, pan
## in frame pixels); anims per layer; fx drawn over it.
const SHOTS := {
	"desert_road":  {"layers": [["bg", 0.2], ["mid", 0.6], ["fg", 1.0]], "cam": [1.0, Vector2(-14, 0), 1.08, Vector2(10, -4)], "fx": ["dust"]},
	"cass_close":   {"layers": [["bg", 0.25], ["fg", 1.0], ["flare", 1.0]], "cam": [1.04, Vector2(-8, 4), 1.1, Vector2(6, -2)], "anim": {"fg": "breathe", "flare": "flare"}, "face": {"layer": "fg", "speaker": "cass"}, "fx": ["dust"]},
	"tommy_car":    {"layers": [["bg", 0.3], ["mid", 0.7], ["fg", 1.0], ["charm", 1.0]], "cam": [1.02, Vector2(8, 0), 1.06, Vector2(-6, 2)], "anim": {"mid": "breathe", "fg": "rumble", "charm": "sway"}, "pivot": {"charm": Vector2(0.265, 0.165)}, "face": {"layer": "mid", "speaker": "tommy"}, "smoke": [Vector2(0.5, 0.49)], "fx": []},
	"clapper":      {"layers": [["bg", 0.3], ["fg", 1.0], ["arm", 1.0]], "cam": [1.0, Vector2.ZERO, 1.05, Vector2(0, 4)], "anim": {"arm": "snap"}, "fx": []},
	"explosion":    {"layers": [["bg", 0.2], ["mid", 0.6], ["fg", 1.0]], "cam": [1.12, Vector2(0, -6), 1.02, Vector2.ZERO], "anim": {"mid": "flicker_fire"}, "fx": ["shake", "embers", "flash"]},
	"wreck":        {"layers": [["bg", 0.3], ["mid", 1.0]], "cam": [1.0, Vector2(-10, 0), 1.06, Vector2(6, 0)], "anim": {"mid": "flicker_fire"}, "fx": ["embers", "smoke"]},
	"apartment":    {"layers": [["bg", 0.4], ["fan_0", 0.7], ["mid", 1.0], ["led", 1.0]], "cam": [1.0, Vector2(-10, 0), 1.06, Vector2(10, -2)], "anim": {"led": "blink", "bg": "neon", "fan_0": "cycle3"}, "face": {"layer": "mid", "speaker": "cass"}, "smoke": [Vector2(0.2, 0.735)], "fx": ["rain_window", "dust"]},
	"machine":      {"layers": [["bg", 0.3], ["mid", 1.0], ["reels_0", 1.0], ["led", 1.0]], "cam": [1.06, Vector2(0, 2), 1.14, Vector2(-8, 0)], "anim": {"led": "blink", "reels_0": "cycle3"}, "fx": ["dust"]},
	"package":      {"layers": [["bg", 0.5], ["mid", 1.0]], "cam": [1.0, Vector2(-16, 6), 1.12, Vector2(12, -4)], "fx": ["dust"]},
	"mirror":       {"layers": [["bg", 0.4], ["mid", 0.9], ["bulbs", 0.9], ["fg", 1.0]], "cam": [1.02, Vector2(0, -6), 1.12, Vector2(0, 4)], "anim": {"mid": "breathe", "bulbs": "buzz"}, "face": {"layer": "mid", "speaker": ""}, "fx": ["glint"]},
	"tv_news":      {"layers": [["bg", 0.3], ["mid", 1.0]], "cam": [1.0, Vector2.ZERO, 1.07, Vector2(-6, 0)], "anim": {"mid": "tv"}, "face": {"layer": "mid", "speaker": "anchor"}, "fx": ["scan"]},
	"motel_night":  {"layers": [["bg", 0.2], ["mid", 0.6], ["sign", 0.6], ["fg", 1.0]], "cam": [1.0, Vector2(-12, 0), 1.06, Vector2(10, -2)], "anim": {"sign": "flicker"}, "fx": ["rain"]},
	"motel_crime":  {"layers": [["bg", 0.2], ["mid", 1.0], ["red", 1.0], ["blue", 1.0]], "cam": [1.0, Vector2(10, 0), 1.06, Vector2(-8, 0)], "anim": {"red": "siren_a", "blue": "siren_b"}, "fx": []},
	"marv":         {"layers": [["bg", 0.3], ["mid", 1.0]], "cam": [1.06, Vector2(0, 4), 1.0, Vector2.ZERO], "anim": {"mid": "breathe", "bg": "neon"}, "face": {"layer": "mid", "speaker": "marv"}, "fx": ["scan", "glitter"]},
	"polaroid":     {"layers": [["bg", 0.4], ["mid", 1.0]], "cam": [1.0, Vector2(0, 10), 1.14, Vector2(10, -6)], "fx": ["dust"]},
	"salvage_yard": {"layers": [["bg", 0.2], ["mid", 0.6], ["fg", 1.0], ["eyes", 1.0]], "cam": [1.0, Vector2(-10, 0), 1.08, Vector2(8, 0)], "anim": {"eyes": "eyes"}, "fx": ["dust"]},
	"galaxy_palace": {"layers": [["bg", 0.3], ["mid", 1.0]], "cam": [1.0, Vector2(0, 6), 1.08, Vector2(0, -2)], "anim": {"bg": "neon"}, "fx": []},
	"barstow_pd":   {"layers": [["bg", 0.2], ["mid", 1.0], ["red", 1.0]], "cam": [1.0, Vector2(-8, 0), 1.06, Vector2(8, 0)], "anim": {"red": "siren_a"}, "fx": ["rain"]},
	"hills_fire":   {"layers": [["bg", 0.2], ["mid", 0.6], ["fg", 1.0]], "cam": [1.0, Vector2(0, 0), 1.08, Vector2(-8, -4)], "anim": {"mid": "flicker_fire"}, "fx": ["embers", "smoke"]},
	"static":       {"layers": [], "cam": [1.0, Vector2.ZERO, 1.0, Vector2.ZERO], "fx": ["static"]},
}

## Painted frames (assets/art/painted/<id>.webp, see tools/art/gen_ai_art.py)
## take over from the pixel shots of the same name. One flat painting each,
## brought to life by the painted_shot shader: zones [type, x, y, w, h,
## amount, speed] over the frame (types below), the emissive mask breathing,
## a slow camera move, and the same drawn effects as the pixel shots.
## Extras: "fireworks" rect, "eyes" points, "reddot" point, "papers",
## "rumble" / "handheld" camera motion, "glow" mask strength.
const PAINT := "res://assets/art/painted/%s.webp"
const PAINT_GLOW := "res://assets/art/painted/%s_glow.png"
const PAINT_SHADER := preload("res://shaders/painted_shot.gdshader")
enum Z { SWAY, RIPPLE, FLICKER, PULSE, TV, HEAT, BLINK, BREATHE, SIREN, DRIFT }
const PAINTED := {
	"desert_road":  {"cam": [1.02, Vector2(-14, 2), 1.1, Vector2(12, -4)], "z": [[Z.PULSE, 0.0, 0.55, 0.4, 0.25, 0.3, 1.2], [Z.FLICKER, 0.75, 0.4, 0.25, 0.3, 0.5, 1.0], [Z.BREATHE, 0.45, 0.2, 0.25, 0.7, 0.5, 1.0]], "fx": ["dust"]},
	"cass_close":   {"cam": [1.04, Vector2(-6, 4), 1.12, Vector2(6, -2)], "z": [[Z.BREATHE, 0.3, 0.0, 0.5, 1.0, 0.7, 1.0], [Z.SWAY, 0.28, 0.0, 0.2, 0.7, 0.6, 0.8], [Z.FLICKER, 0.85, 0.0, 0.15, 0.35, 0.6, 1.4]], "fx": ["dust"]},
	"tommy_car":    {"cam": [1.03, Vector2(8, 0), 1.1, Vector2(-6, 2)], "z": [[Z.SWAY, 0.03, 0.12, 0.09, 0.34, 3.0, 2.6], [Z.BREATHE, 0.3, 0.15, 0.4, 0.85, 0.8, 1.0], [Z.FLICKER, 0.6, 0.35, 0.4, 0.4, 0.25, 0.8]], "rumble": 0.6, "fx": ["dust"]},
	"clapper":      {"cam": [1.0, Vector2.ZERO, 1.07, Vector2(0, 4)], "z": [[Z.PULSE, 0.7, 0.4, 0.3, 0.3, 0.4, 2.0], [Z.FLICKER, 0.8, 0.0, 0.2, 0.3, 0.5, 1.2]], "handheld": 1.0, "fx": ["dust"]},
	"explosion":    {"cam": [1.14, Vector2(0, -6), 1.03, Vector2.ZERO], "z": [[Z.HEAT, 0.3, 0.0, 0.5, 0.75, 1.4, 1.0], [Z.FLICKER, 0.25, 0.0, 0.6, 0.8, 0.6, 2.0]], "glow": 0.5, "fx": ["shake", "embers", "flash", "smoke"]},
	"wreck":        {"cam": [1.02, Vector2(-10, 0), 1.08, Vector2(6, 0)], "z": [[Z.HEAT, 0.55, 0.2, 0.35, 0.5, 1.0, 1.0], [Z.FLICKER, 0.5, 0.3, 0.45, 0.5, 0.6, 1.5], [Z.DRIFT, 0.4, 0.0, 0.6, 0.45, 1.0, 1.0]], "fx": ["embers", "smoke"]},
	"apartment":    {"cam": [1.02, Vector2(-10, 0), 1.08, Vector2(10, -2)], "z": [[Z.BLINK, 0.535, 0.27, 0.03, 0.05, 1.2, 1.6], [Z.FLICKER, 0.9, 0.0, 0.1, 0.3, 0.5, 1.0], [Z.PULSE, 0.3, 0.0, 0.2, 0.35, 0.25, 0.7]], "fireworks": [0.02, 0.02, 0.26, 0.3], "fx": ["rain_window", "dust"]},
	"machine":      {"cam": [1.06, Vector2(0, 2), 1.15, Vector2(-8, 0)], "z": [[Z.BLINK, 0.34, 0.6, 0.05, 0.08, 1.4, 1.6], [Z.PULSE, 0.55, 0.0, 0.45, 0.5, 0.2, 0.5]], "fx": ["dust"]},
	"package":      {"cam": [1.02, Vector2(-16, 6), 1.14, Vector2(12, -4)], "z": [[Z.PULSE, 0.7, 0.0, 0.3, 0.4, 0.2, 0.8], [Z.FLICKER, 0.0, 0.0, 0.35, 0.3, 0.3, 1.0]], "fx": ["dust"]},
	"mirror":       {"cam": [1.03, Vector2(0, -6), 1.12, Vector2(0, 4)], "z": [[Z.BREATHE, 0.45, 0.05, 0.4, 0.95, 0.7, 1.0], [Z.FLICKER, 0.85, 0.0, 0.15, 1.0, 0.35, 2.0], [Z.BREATHE, 0.0, 0.0, 0.4, 1.0, 0.5, 1.0]], "fx": ["glint"]},
	"tv_news":      {"cam": [1.02, Vector2.ZERO, 1.08, Vector2(-6, 0)], "z": [[Z.TV, 0.0, 0.0, 1.0, 1.0, 0.6, 1.0], [Z.BREATHE, 0.25, 0.1, 0.5, 0.9, 0.5, 1.0]], "fx": ["scan"]},
	"motel_night":  {"cam": [1.02, Vector2(-12, 0), 1.08, Vector2(10, -2)], "z": [[Z.FLICKER, 0.55, 0.1, 0.35, 0.4, 0.9, 1.3], [Z.SWAY, 0.0, 0.0, 0.25, 0.6, 1.2, 1.1], [Z.RIPPLE, 0.0, 0.72, 1.0, 0.28, 1.2, 1.0]], "fx": ["rain"]},
	"motel_crime":  {"cam": [1.02, Vector2(10, 0), 1.08, Vector2(-8, 0)], "z": [[Z.SIREN, 0.0, 0.3, 0.55, 0.35, 1.0, 1.0], [Z.FLICKER, 0.75, 0.0, 0.25, 0.3, 0.7, 1.4], [Z.BREATHE, 0.35, 0.3, 0.3, 0.6, 0.4, 1.0]], "fx": []},
	"marv":         {"cam": [1.07, Vector2(0, 4), 1.0, Vector2.ZERO], "z": [[Z.BREATHE, 0.2, 0.0, 0.6, 1.0, 0.6, 1.0], [Z.FLICKER, 0.25, 0.0, 0.5, 0.45, 0.35, 2.0]], "glow": 0.5, "fx": ["scan", "glitter"]},
	"polaroid":     {"cam": [1.0, Vector2(0, 10), 1.14, Vector2(10, -6)], "z": [[Z.DRIFT, 0.0, 0.0, 0.3, 0.3, 0.6, 0.6]], "smoke": [Vector2(0.05, 0.1)], "fx": ["dust"]},
	"salvage_yard": {"cam": [1.02, Vector2(-10, 0), 1.1, Vector2(8, 0)], "z": [[Z.FLICKER, 0.75, 0.0, 0.25, 0.3, 0.8, 1.2], [Z.RIPPLE, 0.3, 0.7, 0.7, 0.3, 0.8, 0.8], [Z.SWAY, 0.4, 0.25, 0.25, 0.25, 0.8, 0.5]], "eyes": [[0.12, 0.62], [0.33, 0.68], [0.58, 0.66], [0.81, 0.72]], "fx": ["dust"]},
	"galaxy_palace": {"cam": [1.02, Vector2(0, 6), 1.1, Vector2(0, -2)], "z": [[Z.TV, 0.55, 0.3, 0.3, 0.4, 0.5, 1.0], [Z.TV, 0.0, 0.2, 0.15, 0.5, 0.5, 1.3], [Z.PULSE, 0.3, 0.0, 0.7, 0.2, 0.4, 1.5], [Z.BREATHE, 0.3, 0.1, 0.35, 0.9, 0.5, 1.0]], "glow": 0.5, "fx": []},
	"barstow_pd":   {"cam": [1.02, Vector2(-8, 0), 1.08, Vector2(8, 0)], "z": [[Z.SIREN, 0.0, 0.15, 0.3, 0.5, 0.8, 0.8], [Z.BREATHE, 0.3, 0.05, 0.45, 0.95, 0.6, 1.0], [Z.FLICKER, 0.75, 0.3, 0.25, 0.3, 0.3, 1.0]], "smoke": [Vector2(0.43, 0.55)], "fx": ["rain_window"]},
	"hills_fire":   {"cam": [1.02, Vector2(0, 0), 1.1, Vector2(-8, -4)], "z": [[Z.HEAT, 0.0, 0.05, 1.0, 0.55, 1.2, 1.0], [Z.FLICKER, 0.0, 0.05, 1.0, 0.6, 0.5, 1.5], [Z.SWAY, 0.05, 0.1, 0.2, 0.6, 1.0, 1.2], [Z.RIPPLE, 0.0, 0.75, 1.0, 0.25, 0.6, 1.0]], "fx": ["embers", "smoke"]},
	"arlo_close":   {"cam": [1.03, Vector2(-6, 2), 1.1, Vector2(6, 0)], "z": [[Z.TV, 0.6, 0.0, 0.4, 0.55, 0.7, 1.0], [Z.BREATHE, 0.2, 0.05, 0.5, 0.95, 0.6, 0.9], [Z.FLICKER, 0.0, 0.2, 0.15, 0.25, 0.4, 1.0]], "smoke": [Vector2(0.88, 0.8)], "fx": ["dust"]},
	"yermo_office": {"cam": [1.02, Vector2(-8, 0), 1.1, Vector2(8, -2)], "z": [[Z.TV, 0.43, 0.0, 0.36, 0.45, 0.7, 1.0], [Z.BREATHE, 0.62, 0.72, 0.36, 0.28, 1.2, 0.6], [Z.BREATHE, 0.2, 0.1, 0.45, 0.9, 0.5, 1.0], [Z.FLICKER, 0.05, 0.15, 0.2, 0.3, 0.4, 1.0]], "fx": ["rain_window", "dust"]},
	"live_monitors": {"cam": [1.0, Vector2(0, 0), 1.12, Vector2(0, -4)], "z": [[Z.TV, 0.0, 0.0, 1.0, 1.0, 0.9, 1.0], [Z.BLINK, 0.05, 0.0, 0.9, 0.2, 0.5, 1.0]], "glow": 0.5, "fx": ["scan"]},
	"red_dot":      {"cam": [1.02, Vector2(4, 0), 1.12, Vector2(-4, 2)], "z": [[Z.BREATHE, 0.3, 0.1, 0.5, 0.9, 0.5, 0.8], [Z.TV, 0.05, 0.4, 0.15, 0.25, 0.6, 1.0], [Z.FLICKER, 0.55, 0.0, 0.45, 0.6, 0.3, 1.0]], "reddot": [0.42, 0.54], "fx": ["rain_window"]},
	"burbank_night": {"cam": [1.02, Vector2(-10, 2), 1.1, Vector2(10, -2)], "z": [[Z.SWAY, 0.0, 0.1, 0.15, 0.8, 2.2, 1.6], [Z.SWAY, 0.25, 0.4, 0.15, 0.4, 2.0, 1.8], [Z.SWAY, 0.82, 0.3, 0.18, 0.5, 2.2, 1.7], [Z.FLICKER, 0.15, 0.0, 0.65, 0.35, 0.6, 1.3], [Z.HEAT, 0.15, 0.05, 0.6, 0.3, 0.7, 1.0]], "glow": 0.45, "fx": ["embers", "dust"]},
	"stage_door":   {"cam": [1.03, Vector2(0, 2), 1.1, Vector2(-4, 0)], "z": [[Z.BLINK, 0.7, 0.0, 0.14, 0.2, 1.0, 1.0], [Z.BREATHE, 0.25, 0.05, 0.5, 0.95, 0.8, 1.6], [Z.SWAY, 0.55, 0.3, 0.3, 0.5, 2.5, 2.0]], "papers": true, "fx": ["dust"]},
	"room_204_set": {"cam": [1.0, Vector2(0, 4), 1.12, Vector2(0, -2)], "z": [[Z.PULSE, 0.0, 0.0, 1.0, 0.3, 0.2, 0.6], [Z.BLINK, 0.1, 0.35, 0.8, 0.3, 0.4, 1.0], [Z.FLICKER, 0.3, 0.3, 0.4, 0.4, 0.2, 1.0]], "fx": ["dust"]},
	"control_room": {"cam": [1.02, Vector2(0, 2), 1.1, Vector2(6, -2)], "z": [[Z.TV, 0.05, 0.0, 0.9, 0.6, 0.8, 1.0], [Z.BLINK, 0.05, 0.6, 0.55, 0.25, 0.5, 2.3]], "glow": 0.5, "fx": ["scan"]},
	"fireman":      {"cam": [1.05, Vector2(0, 4), 1.12, Vector2(-6, 0)], "z": [[Z.HEAT, 0.55, 0.3, 0.45, 0.5, 1.2, 1.2], [Z.FLICKER, 0.5, 0.2, 0.5, 0.7, 0.6, 1.8], [Z.BREATHE, 0.25, 0.05, 0.4, 0.95, 0.6, 1.0]], "glow": 0.55, "fx": ["embers", "smoke"]},
	"fireman_down": {"cam": [1.02, Vector2(0, 0), 1.1, Vector2(0, 4)], "z": [[Z.FLICKER, 0.2, 0.0, 0.55, 0.3, 0.6, 2.2], [Z.HEAT, 0.65, 0.2, 0.35, 0.6, 1.0, 1.0], [Z.BLINK, 0.82, 0.5, 0.12, 0.2, 1.0, 1.5], [Z.BREATHE, 0.3, 0.2, 0.4, 0.8, 1.0, 1.4]], "glow": 0.5, "fx": ["embers", "smoke"]},
	"phone_bank":   {"cam": [1.02, Vector2(6, 0), 1.1, Vector2(-6, 2)], "z": [[Z.FLICKER, 0.55, 0.0, 0.45, 0.25, 0.7, 2.5], [Z.PULSE, 0.0, 0.0, 0.35, 0.15, 0.4, 2.0], [Z.BREATHE, 0.35, 0.3, 0.3, 0.7, 0.9, 1.3]], "glow": 0.5, "fx": []},
	"news_studio_fire": {"cam": [1.03, Vector2(0, 2), 1.09, Vector2(-4, 0)], "z": [[Z.FLICKER, 0.45, 0.0, 0.55, 0.6, 0.6, 1.8], [Z.HEAT, 0.45, 0.0, 0.55, 0.55, 0.6, 1.0], [Z.BREATHE, 0.2, 0.05, 0.5, 0.95, 0.5, 1.0]], "fx": ["scan"]},
	"credits_tv":   {"cam": [1.02, Vector2(0, 0), 1.14, Vector2(0, -8)], "z": [[Z.TV, 0.28, 0.02, 0.45, 0.62, 0.9, 1.0], [Z.BREATHE, 0.0, 0.5, 0.3, 0.5, 0.5, 0.8]], "fx": ["scan"]},
	"harcourt_office": {"cam": [1.03, Vector2(0, 2), 1.1, Vector2(4, 0)], "z": [[Z.BREATHE, 0.0, 0.05, 0.45, 0.95, 0.6, 1.1], [Z.BREATHE, 0.6, 0.0, 0.4, 1.0, 0.5, 0.8], [Z.FLICKER, 0.0, 0.1, 0.1, 0.4, 0.8, 1.3]], "fx": ["dust"]},
	"room_204":     {"cam": [1.02, Vector2(-6, 0), 1.1, Vector2(6, 0)], "z": [[Z.TV, 0.1, 0.05, 0.2, 0.3, 0.8, 1.0], [Z.FLICKER, 0.7, 0.0, 0.3, 0.4, 0.5, 1.2]], "fx": ["rain_window", "dust"]},
	"motel_dream":  {"cam": [1.03, Vector2(-4, 2), 1.12, Vector2(4, -2)], "z": [[Z.TV, 0.0, 0.08, 0.24, 0.4, 0.9, 1.0], [Z.BREATHE, 0.2, 0.25, 0.55, 0.65, 0.5, 0.6], [Z.DRIFT, 0.15, 0.0, 0.45, 0.45, 1.2, 0.5], [Z.FLICKER, 0.78, 0.0, 0.18, 0.25, 0.5, 1.0]], "fx": ["dust"]},
	"villa_gate":   {"cam": [1.02, Vector2(0, 4), 1.12, Vector2(0, -4)], "z": [[Z.FLICKER, 0.3, 0.1, 0.4, 0.35, 0.5, 1.0], [Z.SWAY, 0.0, 0.0, 0.18, 0.5, 1.5, 1.2], [Z.SWAY, 0.82, 0.0, 0.18, 0.5, 1.5, 1.3], [Z.PULSE, 0.5, 0.0, 0.2, 0.2, 0.3, 0.8], [Z.DRIFT, 0.0, 0.55, 1.0, 0.45, 1.5, 0.6], [Z.SWAY, 0.35, 0.6, 0.2, 0.3, 0.6, 2.0]], "glow": 0.5, "fx": ["blood_rain"]},
	"wrap_party":   {"cam": [1.02, Vector2(-6, 0), 1.1, Vector2(6, -2)], "z": [[Z.SWAY, 0.2, 0.2, 0.6, 0.6, 0.8, 0.5], [Z.FLICKER, 0.35, 0.55, 0.15, 0.3, 0.7, 1.4], [Z.PULSE, 0.4, 0.0, 0.25, 0.15, 0.3, 0.7], [Z.DRIFT, 0.0, 0.0, 1.0, 1.0, 0.6, 0.4]], "glow": 0.45, "fx": ["dust"]},
	"burning_tommy": {"cam": [1.06, Vector2(0, 4), 1.12, Vector2(0, -2)], "z": [[Z.HEAT, 0.15, 0.05, 0.7, 0.9, 1.5, 1.2], [Z.FLICKER, 0.15, 0.05, 0.7, 0.9, 0.6, 2.0], [Z.BREATHE, 0.3, 0.1, 0.4, 0.9, 0.7, 0.8]], "glow": 0.6, "fx": ["embers", "smoke"]},
	"mirror_dead":  {"cam": [1.02, Vector2(4, 0), 1.12, Vector2(-4, -2)], "z": [[Z.BREATHE, 0.1, 0.1, 0.35, 0.9, 0.4, 0.4], [Z.SWAY, 0.45, 0.0, 0.4, 0.6, 0.6, 0.7], [Z.FLICKER, 0.85, 0.4, 0.15, 0.3, 0.6, 1.2], [Z.DRIFT, 0.0, 0.05, 0.35, 0.5, 1.0, 0.3]], "fx": ["dust"]},
	"wake_motel":   {"cam": [1.05, Vector2(0, 0), 1.1, Vector2(2, 0)], "z": [[Z.TV, 0.0, 0.15, 0.24, 0.38, 0.7, 1.0], [Z.BREATHE, 0.35, 0.1, 0.45, 0.9, 1.2, 2.2], [Z.BLINK, 0.72, 0.75, 0.2, 0.2, 0.3, 3.0], [Z.PULSE, 0.8, 0.0, 0.2, 0.5, 0.2, 0.4]], "handheld": 0.5, "fx": ["dust"]},
	"casting_1990": {"cam": [1.0, Vector2(-8, 4), 1.14, Vector2(8, -4)], "z": [[Z.PULSE, 0.05, 0.0, 0.25, 0.25, 0.4, 1.4], [Z.PULSE, 0.65, 0.5, 0.3, 0.25, 0.4, 1.1], [Z.FLICKER, 0.0, 0.45, 0.12, 0.35, 0.5, 1.0]], "fx": ["dust"]},
	"lobby_phone":  {"cam": [1.03, Vector2(-4, 0), 1.1, Vector2(4, -2)], "z": [[Z.BREATHE, 0.05, 0.05, 0.4, 0.95, 0.6, 0.9], [Z.FLICKER, 0.6, 0.0, 0.35, 0.35, 0.8, 1.4], [Z.FLICKER, 0.0, 0.3, 0.15, 0.3, 0.4, 1.0]], "fx": ["dust"]},
	"tommy_trapped": {"cam": [1.05, Vector2(0, 0), 1.12, Vector2(2, -2)], "z": [[Z.HEAT, 0.3, 0.0, 0.7, 0.7, 1.4, 1.2], [Z.FLICKER, 0.3, 0.0, 0.7, 0.8, 0.7, 2.2], [Z.SWAY, 0.25, 0.0, 0.25, 0.4, 0.5, 3.0]], "glow": 0.6, "fx": ["embers", "smoke"]},
	"dead_line":    {"cam": [1.04, Vector2(0, -4), 1.14, Vector2(0, 4)], "z": [[Z.SWAY, 0.35, 0.05, 0.3, 0.75, 2.5, 1.0], [Z.FLICKER, 0.75, 0.0, 0.25, 0.4, 0.6, 1.2]], "fx": ["scan", "dust"]},
	# --- the trailer (scripts/ui/intro.gd)
	"t_tape":       {"cam": [1.0, Vector2(-10, 4), 1.22, Vector2(8, -2)], "z": [[Z.PULSE, 0.0, 0.0, 0.35, 0.35, 0.6, 1.4], [Z.BLINK, 0.75, 0.45, 0.14, 0.12, 1.0, 2.0], [Z.TV, 0.0, 0.0, 0.3, 0.25, 1.0, 0.6]], "glow": 0.5, "fx": ["dust"]},
	"t_drive":      {"cam": [1.04, Vector2(6, 0), 1.14, Vector2(-6, -2)], "z": [[Z.RIPPLE, 0.0, 0.0, 1.0, 1.0, 0.8, 0.5], [Z.FLICKER, 0.6, 0.0, 0.4, 0.5, 0.9, 1.6], [Z.BREATHE, 0.3, 0.1, 0.35, 0.8, 0.5, 0.7]], "rumble": 0.6, "fx": ["rain_window"]},
	"t_star":       {"cam": [1.0, Vector2.ZERO, 1.2, Vector2(0, -3)], "z": [[Z.BREATHE, 0.0, 0.0, 1.0, 1.0, 0.4, 0.5], [Z.PULSE, 0.38, 0.35, 0.24, 0.3, 0.7, 1.2]], "glow": 0.6, "fx": ["glint"]},
	"t_arsenal":    {"cam": [1.12, Vector2(-14, 0), 1.02, Vector2(14, 0)], "z": [[Z.PULSE, 0.5, 0.0, 0.5, 0.5, 0.3, 0.8], [Z.DRIFT, 0.0, 0.0, 1.0, 1.0, 0.5, 0.6]], "fx": ["dust"]},
	"t_corridor":   {"cam": [1.02, Vector2(0, 0), 1.16, Vector2(6, -2)], "z": [[Z.FLICKER, 0.78, 0.0, 0.22, 0.4, 1.2, 2.2], [Z.RIPPLE, 0.0, 0.72, 1.0, 0.28, 0.9, 1.0], [Z.PULSE, 0.8, 0.2, 0.15, 0.55, 0.4, 0.8]], "fx": ["rain"]},
	"t_dogs":       {"cam": [1.02, Vector2(-6, 2), 1.14, Vector2(4, 0)], "z": [[Z.BREATHE, 0.0, 0.45, 0.6, 0.4, 0.9, 1.0], [Z.PULSE, 0.05, 0.5, 0.55, 0.3, 0.5, 0.8], [Z.FLICKER, 0.5, 0.0, 0.2, 0.3, 0.4, 1.0]], "handheld": 1.0, "fx": ["dust"]},
	"t_studio":     {"cam": [1.0, Vector2(0, 4), 1.1, Vector2(0, -2)], "z": [[Z.FLICKER, 0.5, 0.1, 0.3, 0.55, 1.4, 2.4], [Z.BLINK, 0.55, 0.0, 0.25, 0.15, 0.8, 1.8], [Z.PULSE, 0.0, 0.0, 1.0, 0.3, 0.3, 0.6]], "glow": 0.5, "fx": ["dust"]},
	"t_fire":       {"cam": [1.08, Vector2(0, -4), 1.0, Vector2.ZERO], "z": [[Z.HEAT, 0.0, 0.05, 1.0, 0.75, 1.3, 1.2], [Z.FLICKER, 0.0, 0.0, 1.0, 0.9, 0.7, 2.0]], "glow": 0.6, "rumble": 1.0, "fx": ["embers", "smoke"]},
	"t_mansion":    {"cam": [1.02, Vector2(0, 6), 1.16, Vector2(0, -6)], "z": [[Z.SWAY, 0.35, 0.0, 0.3, 0.22, 0.4, 0.8], [Z.FLICKER, 0.0, 0.3, 1.0, 0.5, 0.6, 1.2], [Z.DRIFT, 0.0, 0.7, 1.0, 0.3, 0.3, 1.0]], "fx": ["blood_rain", "dust"]},
	"t_monitors":   {"cam": [1.02, Vector2(-8, 0), 1.12, Vector2(8, 0)], "z": [[Z.TV, 0.0, 0.0, 0.62, 0.55, 1.0, 1.0], [Z.BREATHE, 0.62, 0.08, 0.34, 0.9, 0.5, 0.8]], "fx": ["scan"]},
	"t_marv":       {"cam": [1.0, Vector2.ZERO, 1.14, Vector2(0, -2)], "z": [[Z.TV, 0.03, 0.05, 0.9, 0.85, 1.4, 1.4], [Z.BREATHE, 0.2, 0.1, 0.5, 0.8, 1.6, 1.4]], "fx": ["scan"]},
	"t_phone":      {"cam": [1.02, Vector2(-4, 0), 1.12, Vector2(4, -2)], "z": [[Z.SWAY, 0.24, 0.45, 0.18, 0.5, 0.6, 1.6], [Z.FLICKER, 0.38, 0.05, 0.25, 0.15, 1.2, 2.2], [Z.RIPPLE, 0.0, 0.75, 1.0, 0.25, 0.9, 1.0]], "fx": ["rain"]},
	"t_walk":       {"cam": [1.18, Vector2(0, -6), 1.02, Vector2(0, 2)], "z": [[Z.HEAT, 0.0, 0.3, 0.45, 0.55, 1.2, 1.2], [Z.FLICKER, 0.0, 0.2, 0.5, 0.7, 0.8, 1.6], [Z.BREATHE, 0.4, 0.1, 0.3, 0.9, 0.7, 0.8]], "glow": 0.5, "fx": ["embers", "smoke", "rain"]},
	# --- boss scenes
	"h_door":       {"cam": [1.12, Vector2(0, 0), 1.02, Vector2(4, 0)], "z": [[Z.TV, 0.1, 0.05, 0.25, 0.35, 1.0, 1.0], [Z.PULSE, 0.02, 0.35, 0.12, 0.15, 0.4, 0.8], [Z.BREATHE, 0.12, 0.25, 0.2, 0.45, 0.6, 0.8]], "smoke": [Vector2(0.25, 0.1)], "fx": ["dust"]},
	"h_reveal":     {"cam": [1.0, Vector2(0, 0), 1.18, Vector2(0, -4)], "z": [[Z.BREATHE, 0.2, 0.0, 0.6, 1.0, 1.4, 1.2], [Z.PULSE, 0.35, 0.2, 0.3, 0.15, 0.6, 1.0]], "handheld": 0.8, "fx": ["dust"]},
	"h_alarm":      {"cam": [1.1, Vector2(6, 0), 1.0, Vector2(-4, 0)], "z": [[Z.SIREN, 0.3, 0.0, 0.7, 1.0, 1.6, 1.4], [Z.SWAY, 0.72, 0.4, 0.2, 0.4, 2.0, 0.8]], "rumble": 0.8, "fx": ["shake"]},
	"h_down":       {"cam": [1.02, Vector2(0, 0), 1.1, Vector2(-4, -2)], "z": [[Z.SIREN, 0.0, 0.0, 1.0, 0.6, 0.6, 0.7], [Z.BREATHE, 0.25, 0.2, 0.4, 0.6, 1.0, 1.0]], "fx": ["dust"]},
	"h_polaroid":   {"cam": [1.0, Vector2(0, 0), 1.16, Vector2(-6, -2)], "z": [[Z.BREATHE, 0.0, 0.3, 0.3, 0.7, 1.6, 0.8], [Z.FLICKER, 0.0, 0.0, 0.2, 0.3, 0.4, 0.8]], "handheld": 1.2, "fx": ["dust"]},
	"d_stage":      {"cam": [1.02, Vector2(0, 4), 1.12, Vector2(0, -2)], "z": [[Z.HEAT, 0.3, 0.3, 0.2, 0.3, 1.2, 1.0], [Z.FLICKER, 0.6, 0.0, 0.4, 0.8, 1.2, 2.0], [Z.BREATHE, 0.3, 0.1, 0.4, 0.9, 0.5, 0.7]], "glow": 0.5, "fx": ["embers"]},
	"d_tote":       {"cam": [1.0, Vector2(0, 0), 1.1, Vector2(0, 4)], "z": [[Z.TV, 0.25, 0.0, 0.5, 0.35, 2.0, 1.4], [Z.BLINK, 0.0, 0.1, 0.2, 0.5, 1.0, 1.2], [Z.BLINK, 0.8, 0.1, 0.2, 0.5, 1.3, 1.2]], "glow": 0.5, "fx": []},
	"d_changeorder": {"cam": [1.0, Vector2(0, 0), 1.18, Vector2(8, 2)], "z": [[Z.HEAT, 0.7, 0.0, 0.3, 1.0, 1.4, 1.2], [Z.FLICKER, 0.5, 0.0, 0.5, 1.0, 0.8, 1.6]], "fx": ["embers"]},
	"d_cameras":    {"cam": [1.1, Vector2(-6, 0), 1.0, Vector2(6, 0)], "z": [[Z.FLICKER, 0.3, 0.2, 0.7, 0.6, 1.6, 2.4], [Z.BLINK, 0.0, 0.05, 0.12, 0.1, 1.2, 1.6], [Z.HEAT, 0.5, 0.0, 0.5, 0.6, 1.0, 1.0]], "rumble": 0.6, "fx": ["embers", "shake"]},
	"b_party":      {"cam": [1.02, Vector2(0, 0), 1.14, Vector2(0, -4)], "z": [[Z.HEAT, 0.3, 0.0, 0.4, 1.0, 1.0, 1.0], [Z.FLICKER, 0.0, 0.0, 1.0, 0.4, 0.8, 1.4], [Z.BREATHE, 0.0, 0.2, 0.3, 0.8, 0.4, 0.6], [Z.BREATHE, 0.7, 0.2, 0.3, 0.8, 0.4, 0.6]], "fx": ["embers", "smoke"]},
	"b_embrace":    {"cam": [1.06, Vector2(0, 0), 1.14, Vector2(0, -3)], "z": [[Z.HEAT, 0.2, 0.3, 0.6, 0.7, 0.8, 0.8], [Z.BREATHE, 0.3, 0.1, 0.4, 0.8, 0.5, 1.0], [Z.FLICKER, 0.0, 0.0, 1.0, 1.0, 0.5, 1.2]], "fx": ["embers"]},
	"b_credits":    {"cam": [1.0, Vector2(0, 0), 1.12, Vector2(-6, 0)], "z": [[Z.TV, 0.1, 0.25, 0.3, 0.5, 1.0, 1.0], [Z.RIPPLE, 0.75, 0.1, 0.25, 0.5, 0.6, 0.6]], "fx": ["rain_window"]},
	# --- Dog Days' boss
	"k_yard":       {"cam": [1.02, Vector2(-6, 0), 1.12, Vector2(6, -2)], "z": [[Z.FLICKER, 0.3, 0.0, 0.4, 0.3, 0.5, 1.2], [Z.BREATHE, 0.0, 0.3, 1.0, 0.6, 0.9, 0.8], [Z.DRIFT, 0.0, 0.0, 1.0, 1.0, 0.3, 0.6]], "fx": ["dust"]},
	"k_buck":       {"cam": [1.02, Vector2(0, 0), 1.14, Vector2(0, -3)], "z": [[Z.BREATHE, 0.3, 0.1, 0.4, 0.9, 0.5, 0.8], [Z.FLICKER, 0.3, 0.0, 0.4, 0.2, 0.5, 1.0]], "fx": ["dust"]},
	"k_lane":       {"cam": [1.1, Vector2(0, 0), 1.0, Vector2(4, 0)], "z": [[Z.HEAT, 0.6, 0.1, 0.4, 0.6, 1.2, 1.2], [Z.BREATHE, 0.0, 0.4, 0.6, 0.6, 1.4, 1.0], [Z.FLICKER, 0.5, 0.0, 0.5, 0.8, 0.8, 1.6]], "handheld": 1.2, "fx": ["embers"]},
	"k_down":       {"cam": [1.02, Vector2(0, 0), 1.12, Vector2(-3, -2)], "z": [[Z.BREATHE, 0.2, 0.2, 0.6, 0.8, 0.5, 0.7], [Z.FLICKER, 0.3, 0.0, 0.4, 0.2, 0.4, 0.8]], "fx": ["dust"]},
	"k_dogs":       {"cam": [1.0, Vector2(0, 0), 1.1, Vector2(0, -2)], "z": [[Z.BREATHE, 0.0, 0.2, 1.0, 0.8, 0.8, 0.9]], "fx": ["dust"]},
	# --- title-screen vignettes: the camera holds still, only the moment moves
	"menu_smoke":   {"cam": [1.0, Vector2.ZERO, 1.0, Vector2.ZERO], "handheld": 0.0, "z": [[Z.FLICKER, 0.25, 0.0, 0.2, 0.6, 0.4, 0.8], [Z.BREATHE, 0.5, 0.05, 0.35, 0.9, 0.35, 0.6], [Z.RIPPLE, 0.35, 0.0, 0.3, 0.5, 0.4, 0.4]], "smoke": [Vector2(0.63, 0.2)], "fx": ["rain_window"]},
	"menu_revolver": {"cam": [1.0, Vector2.ZERO, 1.0, Vector2.ZERO], "handheld": 0.0, "z": [[Z.SWAY, 0.4, 0.0, 0.2, 0.15, 0.3, 0.6], [Z.BREATHE, 0.45, 0.1, 0.4, 0.8, 0.35, 0.6], [Z.PULSE, 0.4, 0.0, 0.25, 0.25, 0.3, 0.6]], "fx": ["dust"]},
	"menu_dutch":   {"cam": [1.0, Vector2.ZERO, 1.0, Vector2.ZERO], "handheld": 0.0, "z": [[Z.FLICKER, 0.6, 0.35, 0.2, 0.25, 1.2, 1.6], [Z.BREATHE, 0.55, 0.05, 0.4, 0.9, 0.4, 0.6]], "glow": 0.5, "fx": ["dust"]},
	"menu_arlo":    {"cam": [1.0, Vector2.ZERO, 1.0, Vector2.ZERO], "handheld": 0.0, "z": [[Z.TV, 0.0, 0.3, 0.3, 0.4, 1.0, 0.8], [Z.BREATHE, 0.5, 0.2, 0.4, 0.8, 0.4, 0.6]], "fx": ["dust"]},
	"menu_marv":    {"cam": [1.0, Vector2.ZERO, 1.0, Vector2.ZERO], "handheld": 0.0, "z": [[Z.TV, 0.3, 0.0, 0.25, 0.8, 1.0, 1.0], [Z.FLICKER, 0.6, 0.0, 0.3, 0.2, 0.4, 0.8], [Z.BREATHE, 0.45, 0.1, 0.25, 0.8, 0.35, 0.6]], "fx": ["dust"]},
	"menu_tommy":   {"cam": [1.0, Vector2.ZERO, 1.0, Vector2.ZERO], "handheld": 0.0, "z": [[Z.HEAT, 0.0, 0.5, 0.7, 0.3, 0.6, 0.6], [Z.BREATHE, 0.6, 0.1, 0.35, 0.9, 0.35, 0.6], [Z.SWAY, 0.62, 0.35, 0.08, 0.1, 1.2, 1.0]], "fx": ["dust"]},
	# --- coverage frames for the long scenes
	"arlo_wide":    {"cam": [1.02, Vector2(-6, 0), 1.08, Vector2(6, 0)], "z": [[Z.TV, 0.0, 0.2, 0.22, 0.35, 1.0, 1.0], [Z.BREATHE, 0.3, 0.2, 0.3, 0.7, 0.5, 0.8], [Z.BREATHE, 0.6, 0.6, 0.2, 0.3, 0.9, 0.8]], "smoke": [Vector2(0.4, 0.4)], "fx": ["dust"]},
	"cass_listens": {"cam": [1.04, Vector2(4, 0), 1.12, Vector2(-2, -2)], "z": [[Z.TV, 0.85, 0.0, 0.15, 0.35, 1.0, 1.0], [Z.BREATHE, 0.35, 0.05, 0.4, 0.9, 0.5, 0.7], [Z.FLICKER, 0.3, 0.0, 0.7, 1.0, 0.4, 0.6]], "fx": ["dust"]},
	"fire_windshield": {"cam": [1.0, Vector2(0, 0), 1.12, Vector2(-6, -2)], "z": [[Z.HEAT, 0.15, 0.2, 0.3, 0.45, 1.2, 1.2], [Z.FLICKER, 0.0, 0.0, 1.0, 1.0, 0.6, 1.4]], "glow": 0.6, "fx": ["embers"]},
	"dutch_3am":    {"cam": [1.0, Vector2(0, 2), 1.1, Vector2(0, -2)], "z": [[Z.FLICKER, 0.18, 0.1, 0.12, 0.2, 0.5, 1.0], [Z.DRIFT, 0.0, 0.5, 1.0, 0.5, 0.3, 0.6]], "fx": ["dust"]},
	"vance_boys":   {"cam": [1.02, Vector2(0, 0), 1.1, Vector2(4, -2)], "z": [[Z.DRIFT, 0.5, 0.35, 0.12, 0.2, 0.6, 1.2], [Z.BREATHE, 0.0, 0.0, 1.0, 1.0, 0.3, 0.3]], "smoke": [Vector2(0.53, 0.55)], "fx": ["dust"]},
	"machine_close": {"cam": [1.06, Vector2(0, 0), 1.16, Vector2(-4, 0)], "z": [[Z.BLINK, 0.32, 0.72, 0.08, 0.1, 1.0, 2.0], [Z.PULSE, 0.4, 0.2, 0.5, 0.5, 0.5, 0.6], [Z.DRIFT, 0.0, 0.0, 1.0, 0.4, 0.3, 0.5]], "fx": ["dust"]},
	"earl_tv":      {"cam": [1.02, Vector2(0, 0), 1.1, Vector2(0, -2)], "z": [[Z.TV, 0.05, 0.05, 0.9, 0.9, 1.0, 1.0], [Z.SIREN, 0.7, 0.3, 0.25, 0.3, 1.0, 1.0], [Z.BREATHE, 0.35, 0.15, 0.35, 0.7, 0.8, 0.8]], "fx": ["scan"]},
	"phone_cass":   {"cam": [1.04, Vector2(-4, 0), 1.12, Vector2(4, -2)], "z": [[Z.FLICKER, 0.3, 0.2, 0.5, 0.4, 0.8, 1.2], [Z.BREATHE, 0.1, 0.1, 0.4, 0.9, 0.6, 0.8]], "fx": ["dust"]},
	"rudy_backstage": {"cam": [1.06, Vector2(0, 0), 1.0, Vector2(0, 2)], "z": [[Z.BLINK, 0.2, 0.02, 0.12, 0.1, 0.9, 1.6], [Z.BREATHE, 0.35, 0.15, 0.3, 0.8, 1.4, 1.2], [Z.FLICKER, 0.7, 0.0, 0.3, 0.8, 0.6, 1.0]], "handheld": 1.2, "fx": ["dust"]},
	"tommy_grin":   {"cam": [1.02, Vector2(4, 0), 1.1, Vector2(-4, -2)], "z": [[Z.PULSE, 0.6, 0.0, 0.4, 0.4, 0.4, 0.8], [Z.BREATHE, 0.3, 0.1, 0.4, 0.8, 0.5, 0.7]], "fx": ["dust"]},
	"barstow_fireworks": {"cam": [1.02, Vector2(4, 0), 1.1, Vector2(-4, -2)], "z": [[Z.BREATHE, 0.1, 0.1, 0.4, 0.9, 0.5, 0.8], [Z.FLICKER, 0.8, 0.0, 0.2, 0.7, 0.7, 1.3]], "fireworks": [0.45, 0.02, 0.35, 0.35], "fx": ["rain"]},
	"tote_board":   {"cam": [1.0, Vector2(0, 4), 1.1, Vector2(0, -2)], "z": [[Z.FLICKER, 0.1, 0.0, 0.8, 0.35, 0.5, 3.0], [Z.HEAT, 0.0, 0.35, 1.0, 0.65, 1.0, 1.0], [Z.FLICKER, 0.0, 0.35, 1.0, 0.65, 0.4, 1.6]], "glow": 0.6, "fx": ["embers", "smoke"]},
	"canned_applause": {"cam": [1.02, Vector2(-6, 0), 1.08, Vector2(6, 0)], "z": [[Z.BLINK, 0.85, 0.0, 0.15, 0.1, 0.8, 1.2], [Z.FLICKER, 0.0, 0.0, 0.4, 0.5, 0.6, 1.5], [Z.DRIFT, 0.0, 0.0, 1.0, 0.5, 1.0, 0.6]], "fx": ["smoke"]},
	"cameras_shot": {"cam": [1.05, Vector2(-2, 2), 1.1, Vector2(4, 0)], "z": [[Z.TV, 0.4, 0.0, 0.6, 0.35, 1.0, 1.0], [Z.FLICKER, 0.0, 0.0, 1.0, 1.0, 0.4, 2.0], [Z.HEAT, 0.0, 0.3, 0.3, 0.7, 0.8, 1.0]], "handheld": 0.8, "fx": ["embers", "shake"]},
	"dead_applause": {"cam": [1.02, Vector2(0, 2), 1.1, Vector2(0, -2)], "z": [[Z.SWAY, 0.0, 0.1, 1.0, 0.7, 0.7, 0.5], [Z.DRIFT, 0.3, 0.5, 0.4, 0.5, 1.5, 0.4]], "fx": ["dust", "smoke"]},
	"holding_tommy": {"cam": [1.06, Vector2(0, 2), 1.12, Vector2(0, -2)], "z": [[Z.BREATHE, 0.25, 0.0, 0.55, 1.0, 0.5, 0.5], [Z.FLICKER, 0.0, 0.0, 1.0, 1.0, 0.3, 1.4]], "glow": 0.5, "fx": ["embers"]},
	"tv_mansion":   {"cam": [1.03, Vector2(0, 0), 1.15, Vector2(0, -4)], "z": [[Z.TV, 0.25, 0.1, 0.5, 0.65, 1.0, 1.0], [Z.PULSE, 0.4, 0.15, 0.1, 0.12, 0.5, 0.8]], "fx": ["scan"]},
	"extinguisher": {"cam": [1.06, Vector2(0, 0), 1.12, Vector2(-4, 2)], "z": [[Z.HEAT, 0.0, 0.0, 0.5, 0.45, 1.0, 1.0], [Z.FLICKER, 0.0, 0.0, 0.6, 0.5, 0.6, 1.6]], "fx": ["embers", "smoke"]},
	"star_on_mirror": {"cam": [1.02, Vector2(0, 4), 1.12, Vector2(0, -2)], "z": [[Z.FLICKER, 0.45, 0.0, 0.55, 1.0, 0.25, 2.0], [Z.PULSE, 0.0, 0.0, 0.3, 0.6, 0.2, 0.5]], "fx": ["glint", "dust"]},
	"dogs_silent":  {"cam": [1.0, Vector2(0, 0), 1.08, Vector2(0, -2)], "z": [[Z.PULSE, 0.2, 0.0, 0.5, 0.7, 0.6, 3.0], [Z.BREATHE, 0.0, 0.5, 0.3, 0.5, 0.4, 0.6]], "fx": ["flash", "rain_window"]},
	"pov_test_pattern": {"cam": [1.02, Vector2(0, 0), 1.08, Vector2(0, -2)], "z": [[Z.TV, 0.35, 0.2, 0.3, 0.4, 0.7, 1.0], [Z.BREATHE, 0.3, 0.6, 0.4, 0.4, 1.4, 2.4]], "handheld": 0.6, "fx": ["dust"]},
	"phone_ringing": {"cam": [1.04, Vector2(0, 0), 1.1, Vector2(2, -2)], "z": [[Z.SWAY, 0.1, 0.0, 0.45, 0.6, 3.0, 14.0]], "handheld": 0.3, "fx": ["dust"]},
	"corkboard_note": {"cam": [1.0, Vector2(0, 6), 1.16, Vector2(0, -4)], "z": [[Z.FLICKER, 0.0, 0.0, 0.2, 0.4, 0.3, 1.0]], "fx": ["dust"]},
	"ev_tape_roll7": {"cam": [1.02, Vector2(0, 0), 1.1, Vector2(0, -2)], "z": [[Z.TV, 0.15, 0.1, 0.7, 0.75, 1.0, 1.0]], "fx": ["scan"]},
	"ev_tape_vance": {"cam": [1.02, Vector2(0, 0), 1.1, Vector2(0, -2)], "z": [[Z.TV, 0.0, 0.0, 0.9, 0.9, 1.0, 1.0]], "fx": ["scan"]},
	"ev_tape_pilot": {"cam": [1.02, Vector2(0, 0), 1.1, Vector2(0, -2)], "z": [[Z.TV, 0.1, 0.0, 0.8, 0.9, 1.0, 1.0]], "fx": ["scan"]},
	"ev_tape_dream": {"cam": [1.02, Vector2(0, 0), 1.1, Vector2(0, -2)], "z": [[Z.TV, 0.1, 0.05, 0.8, 0.85, 1.0, 1.0]], "fx": ["scan"]},
	"mom_kitchen":  {"cam": [1.03, Vector2(-4, 2), 1.1, Vector2(4, -2)], "z": [[Z.BREATHE, 0.35, 0.2, 0.35, 0.8, 0.6, 0.8], [Z.PULSE, 0.0, 0.0, 0.3, 0.45, 0.2, 0.6]], "fireworks": [0.42, 0.05, 0.3, 0.3], "fx": ["dust"]},
}

var shot_id := ""
var shot_time := 9.0         ## seconds the camera takes over its move
var letterbox := true
var _t := 0.0
var _tex: Array = []         ## [[texture, depth, layer name], ...] of the current shot
var _prev: Array = []
var _prev_def: Dictionary = {}
var _prev_t := 0.0
var _fade := 1.0             ## 0..1 cross-fade from the previous shot
var _def: Dictionary = {}
var _bars := 0.0
var _glitch := 0.0
var _flash := 0.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _embers: Array = []
var _face_layer := ""
var _face_speaker := ""
var _blink_t := 3.0
var _blinking := 0.0
var _mouth_t := 0.0
var _mouth_open := false
var _smoke: Array = []
var _rain: Array = []
var _paint: PaintedLayer        ## the painted frame on screen, if this shot has one
var _paint_old: PaintedLayer    ## the one fading out under it
var _bursts: Array = []         ## fireworks
var _papers: Array = []

static var _cache: Dictionary = {}

## Frames whose painting hasn't been made yet stand in with a close cousin.
const PAINT_FALLBACK := {
	"motel_dream": "room_204", "villa_gate": "hills_fire", "wrap_party": "room_204_set", "burning_tommy": "wreck",
	"mirror_dead": "mirror", "wake_motel": "room_204", "casting_1990": "galaxy_palace",
}

static func resolve(id: String) -> String:
	if painted_tex(id) == null and not SHOTS.has(id) and PAINT_FALLBACK.has(id):
		return str(PAINT_FALLBACK[id])
	return id

static func has_shot(id: String) -> bool:
	id = resolve(id)
	return SHOTS.has(id) or painted_tex(id) != null

static func painted_tex(id: String) -> Texture2D:
	var key := "paint/" + id
	if not _cache.has(key):
		var p := PAINT % id
		_cache[key] = load(p) if ResourceLoader.exists(p) else null
	return _cache[key]

static func painted_glow(id: String) -> Texture2D:
	var key := "glow/" + id
	if not _cache.has(key):
		var p := PAINT_GLOW % id
		_cache[key] = load(p) if ResourceLoader.exists(p) else null
	return _cache[key]

## A ShaderMaterial that animates the painting `id` (also used for the
## full-frame art behind in-level dialogue).
static func painted_material(id: String) -> ShaderMaterial:
	var def: Dictionary = PAINTED.get(id, {})
	var m := ShaderMaterial.new()
	m.shader = PAINT_SHADER
	var zt := PackedInt32Array()
	var zr: Array = []
	var zp: Array = []
	var i := 0
	for z in def.get("z", []):
		zt.append(int(z[0]))
		zr.append(Vector4(z[1], z[2], z[3], z[4]))
		zp.append(Vector4(z[5], z[6], float(i) * 1.7, 0.0))
		i += 1
	while zt.size() < 16:
		zt.append(-1)
		zr.append(Vector4.ZERO)
		zp.append(Vector4.ZERO)
	m.set_shader_parameter("zn", i)
	m.set_shader_parameter("zt", zt)
	m.set_shader_parameter("zr", zr)
	m.set_shader_parameter("zp", zp)
	m.set_shader_parameter("glow_amount", float(def.get("glow", 0.35)))
	m.set_shader_parameter("time_offset", randf() * 50.0)
	var g := painted_glow(id)
	if g:
		m.set_shader_parameter("glow_mask", g)
	return m

static func tex(id: String, layer: String) -> Texture2D:
	var key := id + "/" + layer
	if not _cache.has(key):
		var p := ART % [id, layer]
		_cache[key] = load(p) if ResourceLoader.exists(p) else null
	return _cache[key]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_rng.seed = 1988
	for i in 90:
		_rain.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf_range(0.6, 1.0)))

## Cut to a shot. `hard` skips the cross-fade (first shot of a scene).
func show_shot(id: String, hard := false) -> void:
	id = resolve(id)
	if id == shot_id or not has_shot(id):
		return
	if not hard and shot_id != "":
		_prev = _tex
		_prev_def = _def
		_prev_t = _t
		_fade = 0.0
		_glitch = 1.0
		if is_inside_tree():
			PostFX.vhs_glitch(0.35)
	# the painted frame fades out under the new one (or is dropped on a hard cut)
	if _paint_old and is_instance_valid(_paint_old):
		_paint_old.queue_free()
	_paint_old = _paint
	_paint = null
	if _paint_old and hard:
		_paint_old.queue_free()
		_paint_old = null
	shot_id = id
	_rf_zoom = 1.0
	_rf_pan = Vector2.ZERO
	_rf_i = 0
	var ptex := painted_tex(id)
	_def_for_amb = PAINTED.get(id, SHOTS.get(id, {}))
	var fallback := {"cam": [1.02, Vector2.ZERO, 1.1, Vector2.ZERO], "fx": ["dust"]}
	if id.begins_with("vhs_"):
		# camcorder footage: handheld, a slow push, the frame breathing
		fallback = {"cam": [1.04, Vector2(-6, 2), 1.16, Vector2(6, -2)], "handheld": 1.8, "z": [[Z.BREATHE, 0.0, 0.0, 1.0, 1.0, 0.6, 0.5], [Z.FLICKER, 0.0, 0.0, 1.0, 1.0, 0.5, 0.6]], "fx": ["scan"]}
	_def = PAINTED.get(id, fallback) if ptex else SHOTS[id]
	_t = 0.0
	_tex = []
	_bursts.clear()
	_papers.clear()
	if ptex:
		_paint = PaintedLayer.new()
		_paint.shot = self
		_paint.def = _def
		_paint.texture = ptex
		_paint.material = painted_material(id)
		_paint.modulate.a = 1.0 if hard or _prev.is_empty() and _paint_old == null else 0.0
		add_child(_paint)
		_face_layer = ""
		_face_speaker = ""
		_smoke.clear()
		if "shake" in _def.get("fx", []):
			_shake = 1.0
		if "flash" in _def.get("fx", []):
			_flash = 1.0
		_embers.clear()
		return
	for l in _def.get("layers", []):
		var t := tex(id, l[0])
		if t:
			_tex.append([t, float(l[1]), String(l[0]), id])
	var fdef: Dictionary = _def.get("face", {})
	_face_layer = str(fdef.get("layer", ""))
	_face_speaker = str(fdef.get("speaker", ""))
	_smoke.clear()
	if "shake" in _def.get("fx", []):
		_shake = 1.0
	if "flash" in _def.get("fx", []):
		_flash = 1.0
	_embers.clear()
	_set_bed(_bed_for(_def_for_amb))

var _def_for_amb: Dictionary = {}
var _beds: Dictionary = {}       ## loop name -> AudioStreamPlayer
var ambience := true             ## play the frame's sound bed

## What the frame sounds like: rain on the glass, fire, a TV, sirens, or
## the room just breathing.
func _bed_for(def: Dictionary) -> String:
	var fx: Array = def.get("fx", [])
	var zs: Array = def.get("z", [])
	var kinds := zs.map(func(z): return int(z[0]))
	var anim: Dictionary = def.get("anim", {})
	if "embers" in fx or Z.HEAT in kinds or "flicker_fire" in anim.values():
		return "fire_loop"
	if Z.SIREN in kinds:
		return "siren_loop"
	if "rain_window" in fx or "rain" in fx or "blood_rain" in fx:
		return "rain_loop"
	if Z.TV in kinds or "scan" in fx or "tv" in anim.values():
		return "tv_hum"
	return "room_tone"

func _set_bed(bed: String) -> void:
	if not is_inside_tree() or not ambience:
		return
	for k in _beds:
		var p: AudioStreamPlayer = _beds[k]
		create_tween().tween_property(p, "volume_db", -8.0 if k == bed else -60.0, 0.6)
	if bed == "" or _beds.has(bed):
		return
	var src := Audio.get_stream(bed) as AudioStreamWAV
	if src == null:
		return
	var st := src.duplicate() as AudioStreamWAV
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = st.data.size() / 2
	var pl := AudioStreamPlayer.new()
	pl.stream = st
	pl.bus = "Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else "SFX"
	pl.volume_db = -60.0
	add_child(pl)
	pl.play()
	_beds[bed] = pl
	create_tween().tween_property(pl, "volume_db", -8.0, 0.6)

func _process(delta: float) -> void:
	_t += delta
	_prev_t += delta
	_fade = move_toward(_fade, 1.0, delta / 0.45)
	_bars = move_toward(_bars, 1.0 if letterbox else 0.0, delta * 2.0)
	_glitch = move_toward(_glitch, 0.0, delta * 3.0)
	_flash = move_toward(_flash, 0.0, delta * 1.4)
	_shake = move_toward(_shake, 0.0, delta * 0.7)
	# faces: blink now and then; the mouth moves while this character's
	# line is typing out in the dialogue box
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = _rng.randf_range(2.2, 5.0)
		_blinking = 0.13
	_blinking = maxf(0.0, _blinking - delta)
	_mouth_t -= delta
	if _mouth_t <= 0.0:
		_mouth_t = _rng.randf_range(0.07, 0.12)
		_mouth_open = _talking() and not _mouth_open
	# cigarette smoke: wisps rising from each point
	for p in _def.get("smoke", []):
		if _rng.randf() < delta * 7.0 and _smoke.size() < 50:
			_smoke.append({"p": p, "o": Vector2.ZERO, "v": Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-16, -9)), "t": 0.0, "life": _rng.randf_range(1.6, 2.8), "r": _rng.randf_range(1.5, 2.5)})
	for w in _smoke.duplicate():
		w.t += delta
		w.o += w.v * delta
		w.v.x += sin(_t * 2.0 + w.life * 7.0) * 6.0 * delta
		if w.t > w.life:
			_smoke.erase(w)
	var fx: Array = _def.get("fx", [])
	if "embers" in fx and _embers.size() < 60 and _rng.randf() < 0.6:
		_embers.append({"p": Vector2(_rng.randf_range(0.2, 0.8), _rng.randf_range(0.6, 0.9)), "v": Vector2(_rng.randf_range(-0.02, 0.02), _rng.randf_range(-0.12, -0.05)), "life": _rng.randf_range(1.5, 3.5), "t": 0.0})
	for e in _embers.duplicate():
		e.t += delta
		e.p += e.v * delta
		e.v.x += sin(_t * 3.0 + e.life * 10.0) * 0.004 * delta * 60.0
		if e.t > e.life:
			_embers.erase(e)
	_update_painted(delta)
	queue_redraw()

## Painted frames: fade the new one in and the old one out; fireworks and
## flying papers.
func _update_painted(delta: float) -> void:
	if _paint:
		_paint.modulate.a = move_toward(_paint.modulate.a, 1.0, delta / 0.45)
	if _paint_old and is_instance_valid(_paint_old):
		_paint_old.modulate.a = move_toward(_paint_old.modulate.a, 0.0, delta / 0.45)
		if _paint_old.modulate.a <= 0.0:
			_paint_old.queue_free()
			_paint_old = null
	if _paint == null:
		return
	var fw: Array = _def.get("fireworks", [])
	if fw.size() == 4 and _rng.randf() < delta * 1.1:
		var hue: Color = [Color(1, 0.35, 0.6), Color(0.4, 0.9, 1.0), Color(1, 0.85, 0.35), Color(0.7, 0.5, 1.0)][_rng.randi() % 4]
		if _rng.randf() < 0.6:
			var pop_v := -18.0 - _rng.randf() * 8.0
			get_tree().create_timer(_rng.randf_range(0.2, 0.7)).timeout.connect(func(): Audio.play("firework_pop", pop_v, _rng.randf_range(0.8, 1.15)))
		_bursts.append({"p": Vector2(fw[0] + _rng.randf() * fw[2], fw[1] + _rng.randf() * fw[3] * 0.7), "t": 0.0, "c": hue, "n": _rng.randi_range(10, 16), "r": _rng.randf_range(0.025, 0.045)})
	for b in _bursts.duplicate():
		b.t += delta
		if b.t > 1.6:
			_bursts.erase(b)
	if _def.get("papers", false):
		if _rng.randf() < delta * 2.5 and _papers.size() < 14:
			_papers.append({"p": Vector2(-0.05, _rng.randf_range(0.1, 0.9)), "v": Vector2(_rng.randf_range(0.25, 0.5), _rng.randf_range(-0.12, 0.05)), "rot": _rng.randf() * TAU, "spin": _rng.randf_range(-7, 7), "s": _rng.randf_range(0.7, 1.3)})
		for pp in _papers.duplicate():
			pp.p += pp.v * delta
			pp.v.y += sin(_t * 3.0 + pp.rot) * 0.2 * delta
			pp.rot += pp.spin * delta
			if pp.p.x > 1.1:
				_papers.erase(pp)

func _talking() -> bool:
	if _face_speaker == "" or not Dialogue.active:
		return false
	return Dialogue._spk == _face_speaker and Dialogue.is_typing()

## The texture to draw for a layer right now (face frames, cycling frames).
func _layer_tex(id: String, lname: String, base: Texture2D, t: float, def: Dictionary) -> Texture2D:
	if lname == _face_layer and def == _def:
		if _blinking > 0.0:
			var b := tex(id, lname + "_blink")
			if b:
				return b
		if _mouth_open:
			var m := tex(id, lname + "_talk")
			if m:
				return m
	var anim := str(def.get("anim", {}).get(lname, ""))
	if anim.begins_with("cycle"):
		var n := int(anim.substr(5))
		var stem := lname.substr(0, lname.rfind("_"))
		var f := tex(id, "%s_%d" % [stem, int(t * 14.0) % n])
		if f:
			return f
	return base

## Scale (screen px per art px) so the frame fills the control.
func _base_scale() -> float:
	return maxf(size.x / FRAME.x, size.y / FRAME.y)

## A point in the art (0..1 of the layer) to screen, for the nearest layer.
func _art_to_screen(p: Vector2) -> Vector2:
	if _paint:
		return _paint.frame_to_screen(p)
	var cam := _cam(_def, _t)
	var zoom: float = cam[0]
	var pan: Vector2 = cam[1]
	var base := _base_scale()
	var art := Vector2(544, 306)
	var sc := base * zoom
	var centre := size * 0.5 + pan * base
	return centre + (p - Vector2(0.5, 0.5)) * art * sc

func _cam(def: Dictionary, t: float) -> Array:
	var c: Array = def.get("cam", [1.0, Vector2.ZERO, 1.0, Vector2.ZERO])
	var k := clampf(t / shot_time, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var z := lerpf(float(c[0]), float(c[2]), k)
	var pan := (c[1] as Vector2).lerp(c[3] as Vector2, k)
	if def == _def:
		# coverage: the same frame re-cut closer / wider / off to a side
		z *= _rf_zoom
		pan += _rf_pan
	return [z, pan]

## Coverage within one frame: several lines on the same painting cut to
## a new framing each time (a push-in on a face, a wider look, a slide to
## the other side) and the slow camera move starts again from there.
const FRAMINGS := [[1.0, Vector2.ZERO], [1.22, Vector2(-22, -10)], [1.3, Vector2(24, -8)], [1.14, Vector2(0, 12)], [1.35, Vector2(-8, -16)], [1.08, Vector2(16, 6)]]
var _rf_zoom := 1.0
var _rf_pan := Vector2.ZERO
var _rf_i := 0

func reframe() -> void:
	var i := _rf_i
	while i == _rf_i:
		i = _rng.randi_range(0, FRAMINGS.size() - 1)
	_rf_i = i
	_rf_zoom = float(FRAMINGS[i][0])
	_rf_pan = FRAMINGS[i][1]
	_t = 0.0
	if _paint:
		_paint.t = 0.0
	_glitch = 0.4

func _draw() -> void:
	# a painted frame sits behind this node (show_behind_parent): only
	# black out the back when nothing painted is on screen
	if _paint == null and _paint_old == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.0, 0.02))
	if _paint != null and _fade < 1.0 and not _prev.is_empty():
		_draw_layers(_prev, _prev_def, _prev_t, 1.0 - _fade)
	elif _fade < 1.0 and not _prev.is_empty():
		_draw_layers(_prev, _prev_def, _prev_t, 1.0)
	if _paint == null:
		_draw_layers(_tex, _def, _t, _fade if (not _prev.is_empty() or _paint_old != null) else 1.0)
	_draw_painted_fx()
	_draw_fx()
	# letterbox bars (drawn last, over everything but the dialogue)
	var bh := size.y * 0.1 * _bars
	if bh > 0.5:
		draw_rect(Rect2(0, 0, size.x, bh), Color.BLACK)
		draw_rect(Rect2(0, size.y - bh, size.x, bh), Color.BLACK)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.8, 0.5, _flash * 0.6))

func _draw_layers(list: Array, def: Dictionary, t: float, alpha: float) -> void:
	var cam := _cam(def, t)
	var zoom: float = cam[0]
	var pan: Vector2 = cam[1]
	var base := _base_scale()
	var shake := Vector2.ZERO
	if _shake > 0.0 and def == _def:
		shake = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 6.0 * _shake * _shake
	var anims: Dictionary = def.get("anim", {})
	for entry in list:
		var depth: float = entry[1]
		var lname: String = entry[2]
		var tx: Texture2D = _layer_tex(str(entry[3]) if entry.size() > 3 else shot_id, lname, entry[0], t, def)
		var z := 1.0 + (zoom - 1.0) * (0.4 + 0.6 * depth)
		var sc := base * z
		var tsz := Vector2(tx.get_width(), tx.get_height()) * sc
		var centre := size * 0.5 + (pan * depth) * base + shake * depth
		var pos := centre - tsz * 0.5
		var mod := Color(1, 1, 1, alpha)
		var xform_scale := 1.0
		var rot := 0.0
		var pivot := Vector2.ZERO
		match str(anims.get(lname, "")):
			"blink":
				mod.a *= 1.0 if fmod(t, 1.2) < 0.6 else 0.08
			"flicker":
				mod.a *= 0.25 if (fmod(t, 3.7) < 0.12 or fmod(t, 1.9) < 0.05) else 1.0
			"neon":
				mod = mod * Color(1, 1, 1).lerp(Color(1.08, 0.95, 1.08), 0.5 + 0.5 * sin(t * 7.0) * sin(t * 2.3))
			"flicker_fire":
				var f := 0.9 + 0.1 * sin(t * 17.0) * sin(t * 5.3)
				mod = Color(f, f * 0.97, f * 0.94, mod.a)
			"siren_a":
				mod.a *= clampf(sin(t * 9.0) * 1.5, 0.0, 1.0)
			"siren_b":
				mod.a *= clampf(-sin(t * 9.0) * 1.5, 0.0, 1.0)
			"eyes":
				# red eyes: steady glow, a slow blink now and then
				mod.a *= 0.0 if fmod(t + 0.4, 4.3) < 0.12 else (0.75 + 0.25 * sin(t * 2.0))
			"breathe":
				xform_scale = 1.0 + sin(t * 1.6) * 0.006
				pivot = Vector2(tsz.x * 0.5, tsz.y)
			"rumble":
				pos += Vector2(0, sin(t * 40.0) * 0.6 + sin(t * 13.0) * 0.4)
			"wobble":
				pos += Vector2(0, sin(t * 3.0) * 0.4)
			"tv":
				var fl := 0.94 + 0.06 * sin(t * 50.0)
				mod = Color(fl, fl, fl, mod.a)
			"sway":
				# hanging from its string: swings with the car
				rot = sin(t * 2.6) * 0.18 + sin(t * 7.0) * 0.04
				var pv: Vector2 = def.get("pivot", {}).get(lname, Vector2(0.5, 0.0))
				pivot = Vector2(tsz.x * pv.x, tsz.y * pv.y)
			"buzz":
				# vanity bulbs: a faint hum in the brightness, and now and then a dip
				var dip := 0.55 if fmod(t, 4.7) < 0.09 or fmod(t, 2.3) < 0.03 else 1.0
				mod.a *= (0.92 + 0.08 * sin(t * 60.0)) * dip
			"flare":
				mod.a *= 0.75 + 0.25 * sin(t * 1.3) * sin(t * 0.7)
			"snap":
				# the clapper stick hangs open, then snaps shut at 0.9s
				var k := clampf((t - 0.9) / 0.08, 0.0, 1.0)
				rot = lerpf(-0.32, 0.0, k)
				if k >= 1.0 and t < 1.05 and is_inside_tree():
					_on_snap()
				pivot = Vector2(tsz.x * 0.3 / 1.0, tsz.y * 0.31)
		if rot != 0.0 or xform_scale != 1.0:
			var xf := Transform2D(rot, pos + pivot) * Transform2D(0.0, Vector2(xform_scale, xform_scale), 0.0, -pivot)
			draw_set_transform_matrix(xf)
			draw_texture_rect(tx, Rect2(Vector2.ZERO, tsz), false, mod)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			draw_texture_rect(tx, Rect2(pos, tsz), false, mod)

var _snapped_at := -1.0
func _on_snap() -> void:
	if _snapped_at >= 0.0 and _t - _snapped_at < 1.0:
		return
	_snapped_at = _t
	Audio.play("door_slam", -6.0, 1.6)
	_shake = maxf(_shake, 0.35)

## Drawn over painted frames: fireworks in the window, dog eyes in the dark,
## a sniper's dot, papers in the wind.
func _draw_painted_fx() -> void:
	if _paint == null:
		return
	var fr := _paint.frame_rect()
	for b in _bursts:
		var c: Vector2 = fr.position + (b.p as Vector2) * fr.size
		var k: float = b.t / 1.6
		var rad: float = b.r * fr.size.x * (1.0 - pow(1.0 - minf(k * 1.6, 1.0), 3.0))
		var col: Color = b.c
		col.a = (1.0 - k) * 0.9
		for i in int(b.n):
			var a: float = float(i) / float(b.n) * TAU
			var q := c + Vector2.from_angle(a) * rad + Vector2(0, k * k * 18.0)
			draw_circle(q, 2.0, col)
			draw_line(q, q - Vector2.from_angle(a) * 6.0, Color(col, col.a * 0.5), 1.0)
		if b.t < 0.12:
			draw_circle(c, 5.0, Color(1, 1, 1, 0.8))
	for e in _def.get("eyes", []):
		var ep: Vector2 = fr.position + Vector2(e[0], e[1]) * fr.size
		var on := fmod(_t + float(e[0]) * 7.0, 4.1) > 0.15
		if on:
			var gl := 0.7 + 0.3 * sin(_t * 2.0 + float(e[1]) * 9.0)
			for dx in [-5.0, 5.0]:
				draw_circle(ep + Vector2(dx, 0), 5.0, Color(1, 0.1, 0.05, 0.18 * gl))
				draw_circle(ep + Vector2(dx, 0), 2.0, Color(1, 0.25, 0.15, 0.95 * gl))
	var rd: Array = _def.get("reddot", [])
	if rd.size() == 2:
		var wob := Vector2(sin(_t * 1.3) * 0.012 + sin(_t * 4.1) * 0.003, cos(_t * 1.1) * 0.01)
		var dp := fr.position + (Vector2(rd[0], rd[1]) + wob) * fr.size
		draw_circle(dp, 6.0, Color(1, 0, 0, 0.25))
		draw_circle(dp, 2.5, Color(1, 0.2, 0.2, 0.95))
	for pp in _papers:
		var pc: Vector2 = fr.position + (pp.p as Vector2) * fr.size
		var sq := 0.35 + 0.65 * absf(cos(pp.rot * 1.3))
		draw_set_transform(pc, pp.rot, Vector2(pp.s, pp.s * sq))
		draw_rect(Rect2(-9, -12, 18, 24), Color(0.93, 0.9, 0.82, 0.9))
		draw_line(Vector2(-6, -7), Vector2(6, -7), Color(0.4, 0.4, 0.45, 0.6), 1.0)
		draw_line(Vector2(-6, -2), Vector2(5, -2), Color(0.4, 0.4, 0.45, 0.6), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_fx() -> void:
	var fx: Array = _def.get("fx", [])
	var t := _t
	if "rain" in fx or "rain_window" in fx or "blood_rain" in fx:
		var a := 0.22 if "rain" in fx else (0.3 if "blood_rain" in fx else 0.1)
		var rc := Color(0.75, 0.05, 0.08, a) if "blood_rain" in fx else Color(0.75, 0.8, 1.0, a)
		for r in _rain:
			var x := fmod(r.x * size.x + t * 50.0, size.x)
			var y := fmod(r.y * size.y + t * (380.0 if "blood_rain" in fx else 620.0) * r.z, size.y)
			draw_line(Vector2(x, y), Vector2(x - 4, y + 16), rc, 1.0)
	if "embers" in fx:
		for e in _embers:
			var k: float = 1.0 - e.t / e.life
			var p: Vector2 = e.p * size
			draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.6 + 0.3 * k, 0.2, k))
	if "smoke" in fx:
		for i in 6:
			var k := fmod(t * 0.05 + i / 6.0, 1.0)
			var c := Vector2(size.x * (0.35 + 0.3 * sin(i * 1.7)), size.y * (0.8 - k * 0.8))
			draw_circle(c, 40.0 + k * 120.0, Color(0.08, 0.04, 0.05, 0.12 * sin(k * PI)))
	if not _smoke.is_empty():
		for w in _smoke:
			var sp: Vector2 = _art_to_screen(w.p) + w.o * _base_scale()
			var k: float = w.t / w.life
			draw_circle(sp, (w.r + k * 6.0) * _base_scale() * 0.5, Color(0.85, 0.85, 0.9, 0.16 * (1.0 - k)))
	if "glitter" in fx:
		for i in 18:
			var gx := fmod(i * 131.0, size.x)
			var gy := size.y * 0.55 + fmod(i * 71.0, size.y * 0.4)
			var ph := fmod(t * 1.7 + i * 0.37, 1.0)
			if ph < 0.15:
				var kk := sin(ph / 0.15 * PI)
				draw_line(Vector2(gx - 4 * kk, gy), Vector2(gx + 4 * kk, gy), Color(1, 0.95, 0.7, kk), 1.0)
				draw_line(Vector2(gx, gy - 4 * kk), Vector2(gx, gy + 4 * kk), Color(1, 0.95, 0.7, kk), 1.0)
	if "dust" in fx:
		for i in 26:
			var x := fmod(i * 97.0 + t * (6.0 + i % 5), size.x)
			var y := fmod(i * 53.0 + sin(t * 0.4 + i) * 20.0 + t * 3.0, size.y)
			draw_rect(Rect2(x, y, 2, 2), Color(1, 0.9, 0.8, 0.12 + 0.08 * sin(t * 2.0 + i)))
	if "glint" in fx:
		var g := fmod(t, 3.2)
		if g < 0.5:
			var c := size * Vector2(0.43, 0.42)
			var k := sin(g / 0.5 * PI)
			draw_line(c - Vector2(14, 0) * k, c + Vector2(14, 0) * k, Color(1, 0.95, 0.7, k), 2.0)
			draw_line(c - Vector2(0, 14) * k, c + Vector2(0, 14) * k, Color(1, 0.95, 0.7, k), 2.0)
	if "scan" in fx:
		for i in 12:
			var y := fmod(i * 47.0 + t * 60.0, size.y)
			draw_rect(Rect2(0, y, size.x, 2), Color(1, 1, 1, 0.025))
	if "static" in fx:
		for i in 700:
			var p := Vector2(_rng.randf() * size.x, _rng.randf() * size.y)
			var v := _rng.randf()
			draw_rect(Rect2(p, Vector2(3, 2)), Color(v, v, v, 0.5))
		var ty := fmod(t * 120.0, size.y)
		draw_rect(Rect2(0, ty, size.x, 18), Color(1, 1, 1, 0.08))
	if _glitch > 0.0:
		for i in 6:
			var y := _rng.randf() * size.y
			draw_rect(Rect2(0, y, size.x, _rng.randf_range(2, 10)), Color(1, 1, 1, 0.08 * _glitch))


## One painted frame, drawn behind the StoryShot's own effects. It carries
## its own camera move (plus a car's rumble or a handheld wobble) and the
## animating shader; the frame is overscanned so a pan never shows an edge.
class PaintedLayer extends Control:
	var shot: StoryShot
	var def: Dictionary
	var texture: Texture2D
	var t := 0.0

	func _ready() -> void:
		show_behind_parent = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func frame_rect() -> Rect2:
		var cam: Array = shot._cam(def, t)
		var zoom: float = cam[0]
		var pan: Vector2 = cam[1]
		var ts := Vector2(texture.get_width(), texture.get_height())
		var cover := maxf(size.x / ts.x, size.y / ts.y) * 1.05 * zoom
		var sz := ts * cover
		var base := maxf(size.x / 480.0, size.y / 270.0)
		var off := pan * base
		var rumble := float(def.get("rumble", 0.0))
		if rumble > 0.0:
			off += Vector2(sin(t * 31.0) * 0.6, sin(t * 43.0) * 0.8 + sin(t * 11.0) * 0.5) * rumble * base * 0.5
		var hand := float(def.get("handheld", 0.35))   # a breath of handheld on every frame
		if hand > 0.0:
			off += Vector2(sin(t * 0.9) * 2.0 + sin(t * 2.3), cos(t * 0.7) * 1.5 + sin(t * 1.9) * 0.8) * hand * base * 0.5
		var pos := size * 0.5 - sz * 0.5 + off
		# never show past the edge of the painting
		pos.x = clampf(pos.x, size.x - sz.x, 0.0)
		pos.y = clampf(pos.y, size.y - sz.y, 0.0)
		return Rect2(pos, sz)

	func frame_to_screen(p: Vector2) -> Vector2:
		var r := frame_rect()
		return r.position + p * r.size

	func _draw() -> void:
		if texture:
			draw_texture_rect(texture, frame_rect(), false)
