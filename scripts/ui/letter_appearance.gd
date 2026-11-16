extends Control
## Shared portrait equipment and tile insignia; never changes combat power.
var stats: LetterStats
var tile_mode := false

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	if stats == null:
		return
	var tier := stats.gear_tier()
	var metal: Color = [Color("96704e"), Color("a9bdc9"), Color("e5bd62"), Color("e5d6ff")][tier]
	var cloth := stats.appearance_color().darkened(0.35)
	var w := size.x
	var h := size.y
	if tile_mode:
		# A personal cloth tab, rank studs, and edge scratches leave the glyph clear.
		draw_rect(Rect2(w * 0.15, h * 0.08, w * 0.13, h * 0.12), cloth)
		for i in range(tier + 1):
			draw_circle(Vector2(w * 0.35 + i * w * 0.1, h * 0.89), w * 0.025, metal)
		for i in range(stats.scar_count()):
			var start := Vector2(w * 0.78 + i * w * 0.045, h * 0.18)
			draw_line(start, start + Vector2(-w * 0.06, h * 0.13), Color("edb8a2"), 2.0)
		return
	# Layered shoulder armor: leather, steel, gilded, then jeweled champion gear.
	for side in [-1.0, 1.0]:
		var x: float = w * (0.5 + side * 0.18)
		var armor := PackedVector2Array([
			Vector2(x - w * 0.08, h * 0.46), Vector2(x, h * 0.39),
			Vector2(x + w * 0.08, h * 0.46), Vector2(x + w * 0.05, h * 0.57),
			Vector2(x - w * 0.05, h * 0.57)])
		draw_colored_polygon(armor, metal.darkened(0.3))
		draw_polyline(armor, metal, 3.0)
		for i in range(tier):
			draw_line(Vector2(x - w * 0.05, h * (0.47 + i * 0.025)), Vector2(x + w * 0.05, h * (0.47 + i * 0.025)), metal, 2.0)
		if tier == 3:
			draw_circle(Vector2(x, h * 0.46), w * 0.025, Color("83e8f4"))
	draw_rect(Rect2(w * 0.42, h * 0.55, w * 0.16, h * 0.10), cloth)
	for i in range(stats.scar_count()):
		var start := Vector2(w * (0.57 + i * 0.035), h * 0.25)
		draw_line(start, start + Vector2(-w * 0.045, h * 0.07), Color("793e40"), 3.0)
		draw_line(start + Vector2(2, 0), start + Vector2(-w * 0.045 + 2, h * 0.07), Color("edb8a2"), 1.0)

