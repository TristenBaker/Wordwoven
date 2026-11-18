extends Control
## Shared portrait equipment and tile insignia; never changes combat power.
var stats: LetterStats
var tile_mode := false
var history_only := false

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	if stats == null:
		return
	if history_only:
		_draw_battle_history()
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
			draw_line(start, start + Vector2(-w * 0.06, h * 0.13), Color("d94b50"), 2.0)
		return
	# Small metal rank fittings preserve the authored clothing and silhouette.
	# Pixel-sized shadow/highlight steps match the detailed sprite materials.
	var fitting_size := maxf(1.0, minf(w, h) / 128.0)
	for i in range(tier + 1):
		var at := Vector2(w * 0.5 + (i - tier * 0.5) * fitting_size * 4, h * 0.49)
		draw_rect(Rect2(at, Vector2.ONE * fitting_size * 2), metal.darkened(0.5))
		draw_rect(Rect2(at, Vector2.ONE * fitting_size), metal.lightened(0.15))
	if tier == 3:
		var jewel := Vector2(w * 0.5, h * 0.52)
		draw_rect(Rect2(jewel, Vector2.ONE * fitting_size * 2), Color("284b6b"))
		draw_rect(Rect2(jewel, Vector2.ONE * fitting_size), Color("9dd6df"))
	_draw_battle_history()


func _draw_battle_history() -> void:
	var count := stats.scar_count()
	if count == 0:
		return
	var portrait := get_parent() as TextureRect
	var source_size := Vector2(256, 256)
	if portrait != null and portrait.texture != null:
		source_size = portrait.texture.get_size()
	var fit := minf(size.x / source_size.x, size.y / source_size.y)
	var drawn_size := source_size * fit
	var origin := (size - drawn_size) * 0.5
	var unit := drawn_size / 256.0
	var custom := not PlayerProfile.cosmetic_for_letter(stats.letter).is_empty()
	if not custom:
		_draw_expression(origin, unit, count)
	for mark in CharacterScars.marks(stats):
		var anchor: Vector2 = CharacterScars.ANCHORS[mark.site]
		if custom and int(mark.site) < 3:
			anchor.y *= 0.7
		CharacterScars.draw_mark(self, mark, origin + anchor * unit, minf(unit.x, unit.y))


func _draw_expression(origin: Vector2, unit: Vector2, severity: int) -> void:
	var kind := CharacterFeatures.archetype(stats.element)
	var selected := CharacterFeatures.choices(stats)
	var image := CharacterFeatures.combination(kind, selected.x, selected.y).get_image()
	# The modular heads share facial landmarks. Cover the original smile with
	# a local skin sample (or beard sample), then draw the new mouth and brows.
	var mouth_y := 89.0 if kind != 2 else 92.0
	var sample := Vector2i(118, 85)
	var bearded := kind == 0 and selected.y == 2
	var skin := image.get_pixelv(sample)
	var dark := Color("493237")
	var mouth_rect := Rect2(origin + Vector2(115, mouth_y - 5) * unit, Vector2(27, 12) * unit)
	# Preserve the detailed beard shading instead of painting a flat patch
	# over the moustache. Its authored neutral mouth supports the brow changes.
	if not bearded:
		draw_rect(mouth_rect, skin)
	var mouth := PackedVector2Array()
	var drop := float(severity - 1) * 1.8
	for point in [Vector2(119, mouth_y + drop), Vector2(128, mouth_y), Vector2(137, mouth_y + drop)]:
		mouth.append(origin + point * unit)
	if not bearded:
		draw_polyline(mouth, dark, maxf(1.0, unit.x * 2.0))
	var eye_y := 66.0 if kind == 0 else (70.0 if kind == 1 else 75.0)
	# Brows descend toward the nose; later stages add heavier upper lids and
	# tired under-eye shading rather than tinting the entire face darker.
	for side in [-1.0, 1.0]:
		var outer := Vector2(128 + side * 27, eye_y - 9)
		var inner := Vector2(128 + side * 10, eye_y - 7 + severity * 1.8)
		draw_line(origin + outer * unit, origin + inner * unit, dark, maxf(1.0, unit.x * (2 + severity)))
		if severity >= 2:
			var lid := Vector2(128 + side * 19, eye_y - 1)
			draw_line(origin + (lid + Vector2(-6, 0)) * unit, origin + (lid + Vector2(6, 0)) * unit, dark, maxf(1.0, unit.x * severity))
		if severity == 3:
			var tired := Vector2(128 + side * 19, eye_y + 10)
			draw_line(origin + (tired + Vector2(-5, 0)) * unit, origin + (tired + Vector2(5, 0)) * unit, Color(0.25, 0.16, 0.18, 0.5), maxf(1.0, unit.x * 2))

