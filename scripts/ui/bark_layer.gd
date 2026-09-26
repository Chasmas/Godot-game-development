class_name BarkLayer
extends CanvasLayer
## World speech ("barks") drawn in screen space.
##
## World-space speech bubbles clipped through walls, doors and props drawn
## above the speaker, and ran off the screen edge. Here every bubble is
## projected from its speaker to the screen and drawn above the world:
##  - wraps long lines (Portuguese runs ~25% longer than English);
##  - stays inside a safe area that avoids the HUD corners;
##  - stacks bubbles so two speakers never cover each other;
##  - speakers off screen get a bubble pinned to the edge, tail pointing at
##    them;
##  - text size follows the subtitle size setting.

const MAX_W := 240.0
const PAD := Vector2(8, 5)
## inset from the screen edges: keeps clear of the objective, boss bar and
## hint lines at the top (to y=158) and the prompt/ability bars at the bottom
const SAFE := Rect2(Vector2(24, 158), Vector2(-48, -262))

class Bark:
	var speaker: Node2D
	var text := ""
	var name := ""
	var t := 0.0
	var life := 2.8
	var color := Color(0.96, 0.94, 0.9)
	var rect := Rect2()
	var voice_i := -1
	var mood := ""

var _barks: Array[Bark] = []
var _canvas: Control

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_barks)
	add_child(_canvas)

static func find(tree: SceneTree) -> BarkLayer:
	return tree.get_first_node_in_group("bark_layer") as BarkLayer if tree else null

func _enter_tree() -> void:
	add_to_group("bark_layer")

const CPS := 42.0

## Show (or replace) what `speaker` is saying. text is translated here.
func say(speaker: Node2D, text: String, life := 2.8, color := Color(0.96, 0.94, 0.9), who := "") -> void:
	if speaker == null or text == "":
		return
	if not bool(SaveManager.get_setting("subtitles", true)):
		return   # overheard chatter is subtitles; story dialogue always shows
	for b in _barks:
		if b.speaker == speaker:
			b.text = tr(text)
			b.t = 0.0
			b.voice_i = -1
			b.life = _life_for(b.text, life)
			b.color = color
			b.mood = _mood_of(b.text)
			return
	var nb := Bark.new()
	nb.speaker = speaker
	nb.text = tr(text)
	nb.life = _life_for(nb.text, life)
	nb.color = color
	nb.name = who
	nb.mood = _mood_of(nb.text)
	_barks.append(nb)
	Audio.play_at("bubble_pop", speaker.global_position, -10.0, 0.1)

## Long lines stay up long enough to be typed out and read.
static func _life_for(text: String, life: float) -> float:
	return maxf(life, text.length() / CPS + 1.6)

static func _mood_of(text: String) -> String:
	var t := text.strip_edges()
	if t.ends_with("!?") or t.ends_with("?!"):
		return "shock"
	if t.ends_with("!") and t.to_upper() == t:
		return "angry"
	if t.begins_with("..."):
		return "sad"
	return ""

func clear(speaker: Node2D) -> void:
	for b in _barks.duplicate():
		if b.speaker == speaker:
			_barks.erase(b)

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.03)
	for b in _barks.duplicate():
		b.t += rd
		if b.t >= b.life or not is_instance_valid(b.speaker):
			_barks.erase(b)
			continue
		# quiet babble while the bubble types out, from where they stand
		var i := int(b.t * CPS)
		if i != b.voice_i and i < b.text.length() and i % 3 == 0 and TextFX.speaks(b.text, i):
			b.voice_i = i
			Audio.play_at(TextFX.voice_grain("", b.text, i), b.speaker.global_position, -13.0, 0.12)
	_canvas.queue_redraw()

func _font_size() -> int:
	return [12, 15, 19][clampi(int(SaveManager.get_setting("subtitle_size", 1)), 0, 2)]

func _draw_barks() -> void:
	if _barks.is_empty():
		return
	var vp := _canvas.get_viewport()
	var ct := vp.get_canvas_transform()
	var screen := _canvas.get_rect()
	var safe := Rect2(screen.position + SAFE.position, screen.size + SAFE.size)
	var f := UIStyle.font_bold()
	var fs := _font_size()
	var placed: Array[Rect2] = []
	for b in _barks:
		if not is_instance_valid(b.speaker):
			continue
		var head: Vector2 = ct * (b.speaker.global_position + Vector2(0, -12))
		# wrap
		var lines := _wrap(f, b.text, fs, MAX_W)
		var w := 0.0
		for l in lines:
			w = maxf(w, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var lh := f.get_height(fs)
		var size := Vector2(w, lh * lines.size()) + PAD * 2.0
		var r := Rect2(head - Vector2(size.x * 0.5, size.y + 10.0), size)
		var off := not safe.has_point(head)
		# keep inside the safe area
		r.position.x = clampf(r.position.x, safe.position.x, safe.end.x - r.size.x)
		r.position.y = clampf(r.position.y, safe.position.y, safe.end.y - r.size.y)
		# don't cover other bubbles: push up (or down if there's no room)
		for i in 6:
			var hit := false
			for o in placed:
				if o.grow(3).intersects(r):
					hit = true
					r.position.y = o.position.y - r.size.y - 6.0
					if r.position.y < safe.position.y:
						r.position.y = o.end.y + 6.0
			if not hit:
				break
		placed.append(r)
		b.rect = r
		# fade
		var a := clampf(b.t / 0.12, 0.0, 1.0) * clampf((b.life - b.t) / 0.3, 0.0, 1.0)
		var pop := 1.0 + (1.0 - clampf(b.t / 0.12, 0.0, 1.0)) * 0.08
		var ctr := r.get_center()
		_canvas.draw_set_transform(ctr, 0.0, Vector2.ONE * pop)
		var lr := Rect2(r.position - ctr, r.size)
		# tail toward the speaker (from the nearest bubble edge)
		var tip := head - ctr
		var base := Vector2(clampf(tip.x, lr.position.x + 8, lr.end.x - 8), lr.end.y if tip.y > lr.end.y else (lr.position.y if tip.y < lr.position.y else lr.end.y))
		var tail_len := minf((tip - base).length(), 26.0 if not off else 14.0)
		var tail_tip := base + (tip - base).normalized() * tail_len
		var side := Vector2(6, 0) if absf(tip.y - base.y) > absf(tip.x - base.x) else Vector2(0, 6)
		var bg := Color(0.05, 0.03, 0.09, 0.9 * a)
		_canvas.draw_colored_polygon(PackedVector2Array([base - side, tail_tip, base + side]), bg)
		_canvas.draw_rect(lr, bg)
		_canvas.draw_rect(lr, Color(b.color, 0.55 * a), false, 1.0)
		# letters pop in as they're typed (the bubble is sized for the whole line)
		var shown := b.t * CPS
		var ci := 0
		for i in lines.size():
			var lp := lr.position + PAD + Vector2(0, lh * i + f.get_ascent(fs))
			var line: String = lines[i]
			var x := 0.0
			for j in line.length():
				var ch := line[j]
				var gw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var pose := TextFX.letter_pose(ci, shown, b.t, b.mood)
				ci += 1
				if not pose.visible:
					break
				var la: float = a * float(pose.alpha)
				var gc: Vector2 = lp + Vector2(x + gw * 0.5, 0) + pose.offset
				_canvas.draw_set_transform(ctr + gc * pop, 0.0, Vector2.ONE * pop * float(pose.scale))
				_canvas.draw_string_outline(f, Vector2(-gw * 0.5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8 * la))
				_canvas.draw_string(f, Vector2(-gw * 0.5, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(b.color, la))
				x += gw
			ci += 1   # the space the wrap swallowed
		_canvas.draw_set_transform(ctr, 0.0, Vector2.ONE * pop)
		if off:
			# the speaker is off screen: a small arrow at the bubble edge
			var dir := (tip - base).normalized()
			_canvas.draw_colored_polygon(PackedVector2Array([tail_tip + dir * 5.0, tail_tip + dir.orthogonal() * 4.0, tail_tip - dir.orthogonal() * 4.0]), Color(b.color, a))
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _wrap(f: Font, text: String, fs: int, max_w: float) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var trial := word if line == "" else line + " " + word
			if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w and line != "":
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return out
