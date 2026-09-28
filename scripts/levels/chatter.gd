class_name Chatter
extends Node
## Small talk. Every so often two guards standing near each other (both
## calm, neither dogs) turn to face each other and trade a few lines in
## speech bubbles - about the job, the boss, the weather, their lives. It
## stops dead the moment either of them notices something. Not in the dream:
## nobody there has anything left to say to each other.

const RANGE := 72.0          ## how close two people must stand to chat
const NEAR_PLAYER := 150.0   ## only close enough to overhear
const LOSE_PLAYER := 210.0   ## walk away and the talk is lost to her

## Conversations by place; "any" can happen anywhere. Lines alternate
## between the two speakers, A first.
const TALK := {
	"any": [
		["You hear something?", "That's my stomach. Night shift, no dinner.", "They said there'd be sandwiches.", "They say a lot of things."],
		["How much are they paying you?", "Enough not to ask.", "That's not a number.", "It is if you don't ask."],
		["My kid wants to be a stuntman.", "Tell him to be a dentist.", "He hates teeth.", "Everybody hates teeth. That's the business."],
		["You ever think about quitting?", "Every night at about this time.", "And?", "And then it's tomorrow night."],
		["Why do they keep filming everything?", "Insurance.", "Insurance for what?", "For whoever's watching the tape, I guess."],
		["Is that camera on?", "Red light means on.", "It's always red.", "Then smile."],
	],
	"m01_checkout": [
		["Room 204 again. The ice machine's screaming.", "It doesn't scream. It hums.", "Then why'd the guy in 206 check out at three a.m.?", "Nobody checks out of here at three a.m."],
		["Harcourt says we don't go upstairs after midnight.", "Why not?", "He didn't say. He just made the face.", "The fire watch face."],
		["They're sending a woman with a star on her face.", "Like a sheriff?", "Like a movie.", "I hate movies."],
		["Vacancy sign's flickering again.", "It's been flickering since '79.", "Somebody should fix it.", "Somebody tried. Room 112."],
	],
	"m02_dog_days": [
		["Biscuits bit me again.", "He likes you.", "He bit you last week.", "He likes me more."],
		["You fed the dogs?", "I fed the dogs.", "Then why are they looking at me like that?", "They're not hungry. They're curious."],
		["Arlo's watching the fights again.", "Channel four?", "Channel four, five and the one in the toilet.", "The man loves television."],
		["Heat's not breaking tonight.", "Mojave doesn't break. It bends you.", "Did you read that on a matchbook?", "On a tattoo. Long story."],
	],
	"m03_prime_time": [
		["Rudy says we're live at nine.", "Live what?", "Nobody told me. Just live.", "I hate when they don't say."],
		["Why is the audience mannequins?", "Real audiences ask for refunds.", "These ones don't clap.", "That's what the sign is for."],
		["Dutch filled the sprinklers with nothing again.", "Fire safety?", "Fire theatre.", "Same budget."],
		["My agent says this could be my break.", "Your agent is Marv's nephew.", "So it's a sure thing.", "It's a sure something."],
	],
}

var level: Node
var _next := 6.0
var _talk: Dictionary = {}     ## the conversation running now

func _ready() -> void:
	_next = randf_range(4.0, 9.0)

func _process(delta: float) -> void:
	if level == null or level.get("nightmare") != null:
		return
	if not _talk.is_empty():
		_tick(delta)
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = randf_range(9.0, 18.0)
	_start()

func _calm(e: Node) -> bool:
	return is_instance_valid(e) and not (e is Dog) and e.is_alive() and not e.is_aware() \
		and e.state in [Enemy.State.IDLE, Enemy.State.PATROL] and not e.get("_held")

func _start() -> void:
	var p: Node2D = level.get("player")
	if p == null:
		return
	var pool := get_tree().get_nodes_in_group("enemies").filter(func(e): return _calm(e) and (e as Node2D).global_position.distance_to(p.global_position) < NEAR_PLAYER)
	pool.shuffle()
	for a in pool:
		for b in pool:
			if a != b and (a as Node2D).global_position.distance_to((b as Node2D).global_position) < RANGE:
				var mid: String = str(level.mission.id) if level.get("mission") else ""
				var lines: Array = TALK.get(mid, []) + TALK["any"]
				_talk = {"a": a, "b": b, "lines": lines[randi() % lines.size()], "i": 0, "t": 0.2}
				return

func _tick(delta: float) -> void:
	var a = _talk.a
	var b = _talk.b
	if not _calm(a) or not _calm(b):
		_stop()
		return
	var p: Node2D = level.get("player")
	var mid: Vector2 = ((a as Node2D).global_position + (b as Node2D).global_position) * 0.5
	var far := p == null or p.global_position.distance_to(mid) > LOSE_PLAYER
	# they turn to each other while they talk
	var ab: Vector2 = ((b as Node2D).global_position - (a as Node2D).global_position).normalized()
	a.facing = (a.facing as Vector2).slerp(ab, minf(1.0, delta * 5.0))
	b.facing = (b.facing as Vector2).slerp(-ab, minf(1.0, delta * 5.0))
	_talk.t = float(_talk.t) - delta
	if float(_talk.t) > 0.0:
		return
	var lines: Array = _talk.lines
	var i: int = _talk.i
	if i >= lines.size():
		_talk = {}
		return
	var who: Node2D = a if i % 2 == 0 else b
	var text := tr(str(lines[i]))
	var bl := BarkLayer.find(get_tree())
	if bl and not far:
		# out of earshot they keep talking - she just doesn't get to hear it
		bl.say(who, text, 2.2 + text.length() * 0.035, Color(0.85, 0.82, 0.78))
	_talk.i = i + 1
	_talk.t = 2.4 + text.length() * 0.04

func _stop() -> void:
	var bl := BarkLayer.find(get_tree())
	if bl:
		for k in ["a", "b"]:
			if is_instance_valid(_talk.get(k)):
				bl.clear(_talk[k])
	_talk = {}
