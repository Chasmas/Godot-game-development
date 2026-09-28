class_name TitleScreenClock
extends RefCounted
## m:ss for best times on the chapter select.

static func clock(t: float) -> String:
	if t <= 0.0:
		return "-"
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
