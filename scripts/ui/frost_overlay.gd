extends Control
## Lightweight vector ice: faceted corners and branching crystals, above the glyph.
var amount: float = 0.0:
	set(value):
		amount = value
		queue_redraw()

func _draw() -> void:
	if amount <= 0.0:
		return
	var ice := Color(0.79, 0.94, 1.0, amount * 0.8)
	for corner: Vector2 in [Vector2(5, 5), Vector2(size.x - 5, size.y - 5)]:
		var direction: float = 1.0 if corner.x < size.x * 0.5 else -1.0
		draw_colored_polygon(PackedVector2Array([corner, corner + Vector2(30, 0) * direction,
			corner + Vector2(12, 16) * direction, corner + Vector2(0, 32) * direction]), Color(ice, amount * 0.32))
		var tip := corner + Vector2(25, 28) * direction
		draw_line(corner, tip, ice, 1.5, true)
		for distance: float in [0.35, 0.65]:
			var branch := corner.lerp(tip, distance)
			draw_line(branch, branch + Vector2(0, -9) * direction, ice, 1.2, true)
			draw_line(branch, branch + Vector2(-9, 0) * direction, ice, 1.2, true)
