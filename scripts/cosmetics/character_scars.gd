class_name CharacterScars
extends RefCounted
## Stable, ordered scars: later milestones never move or replace earlier marks.

const TYPE_NAMES := ["Slash", "Claw", "Stitched"]
const LOCATION_NAMES := ["Left cheek", "Right cheek", "Brow"]
const EXPRESSION_NAMES := ["Bright", "Watchful", "Stern", "Grim"]
const ANCHORS := [Vector2(110, 83), Vector2(148, 83), Vector2(120, 57)]


static func marks(stats: LetterStats) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = stats.appearance_seed ^ 0x53434152
	var types := [0, 1, 2]
	var face_sites := [0, 1, 2]
	var result: Array[Dictionary] = []
	for index in stats.scar_count():
		var type_slot := rng.randi_range(0, types.size() - 1)
		var scar_type: int = types.pop_at(type_slot)
		var site: int = face_sites.pop_at(rng.randi_range(0, face_sites.size() - 1))
		result.append({"type": scar_type, "site": site,
			"flip": -1.0 if rng.randf() < 0.5 else 1.0})
	return result


static func description(stats: LetterStats) -> String:
	var parts: Array[String] = []
	for mark in marks(stats):
		parts.append("%s: %s" % [LOCATION_NAMES[mark.site], TYPE_NAMES[mark.type]])
	return "%s expression%s" % [EXPRESSION_NAMES[stats.scar_count()],
		" · " + ", ".join(parts) if not parts.is_empty() else ""]


static func draw_mark(canvas: CanvasItem, mark: Dictionary, at: Vector2, scale: float) -> void:
	var dark := Color("8f2638")
	var light := Color("d94b50")
	var flip: float = mark.flip
	match int(mark.type):
		0: # A healed diagonal cut.
			_cut(canvas, at + Vector2(-4 * flip, -5) * scale, at + Vector2(4 * flip, 5) * scale, scale, dark, light)
		1: # Three short parallel rake marks.
			for i in 3:
				var p := at + Vector2((i - 1) * 4, 0) * scale
				_cut(canvas, p + Vector2(-2 * flip, -4) * scale, p + Vector2(2 * flip, 4) * scale, scale, dark, light)
		2: # A long seam with visible stitch bars.
			_cut(canvas, at + Vector2(0, -7) * scale, at + Vector2(0, 7) * scale, scale, dark, light)
			for i in 3:
				canvas.draw_line(at + Vector2(-3, (i - 1) * 4) * scale, at + Vector2(3, (i - 1) * 4) * scale, dark, maxf(1, scale))


static func _cut(canvas: CanvasItem, start: Vector2, end: Vector2, scale: float, dark: Color, light: Color) -> void:
	canvas.draw_line(start, end, dark, maxf(1.5, scale * 2.5))
	canvas.draw_line(start + Vector2(scale, 0), end + Vector2(scale, 0), light, maxf(0.8, scale))
