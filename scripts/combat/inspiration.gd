class_name Inspiration
extends RefCounted
## Rules for the six-point Inspiration meter, which RunState carries
## between fights. Drawn-only words earn two points, reusing the
## Threaded Letter earns one, and Inspired letters add their own.
## A full meter may be spent before a cast to double drawn-letter
## power, healing, gold, and numerical modifier effects.

const MAX_POINTS: int = 6
const DRAWN_ONLY_POINTS: int = 2
const THREAD_POINTS: int = 1


## Points a resolved word earns, from its calculator breakdown.
static func points_for(result: Dictionary) -> int:
	var points: int = 0
	if bool(result.get("drawn_only", false)):
		points += DRAWN_ONLY_POINTS
	if bool(result.get("threaded_used", false)):
		points += THREAD_POINTS
	points += int(result.get("modifier_inspiration", 0))
	return points


## Why the word earns its points, for the log and preview.
static func explain(result: Dictionary) -> String:
	var parts: Array[String] = []
	if bool(result.get("drawn_only", false)):
		parts.append("+%d drawn-only" % DRAWN_ONLY_POINTS)
	if bool(result.get("threaded_used", false)):
		parts.append("+%d Threaded Letter" % THREAD_POINTS)
	var from_modifiers: int = int(result.get("modifier_inspiration", 0))
	if from_modifiers > 0:
		parts.append("+%d Inspired" % from_modifiers)
	return ", ".join(parts)


static func is_full(points: int) -> bool:
	return points >= MAX_POINTS


static func clamp_points(points: int) -> int:
	return clampi(points, 0, MAX_POINTS)
