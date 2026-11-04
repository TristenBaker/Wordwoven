class_name ElementalHitFx
extends Control
## Independent labels/effects let chained hits remain readable together.
signal finished
var amount := 0
var kind := "burn"
var _color := Color.WHITE
var _progress := 0.0:
	set(value):
		_progress = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 25
	_color = {"burn": Color("ff9650"), "poison": Color("83e579"), "lightning": Color("ffe16a"), "recoil": Color("eeb8ff")}.get(kind, Color.WHITE)
	var number := Label.new()
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: String = {"burn": "BURN", "poison": "POISON", "lightning": "ECHO", "recoil": "RECOIL"}.get(kind, "HIT")
	number.text = "%s  −%d" % [title, amount]
	number.position = Vector2(-150, -100)
	number.size = Vector2(300, 50)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_override("font", preload("res://assets/Fonts/Junicode-Bold.ttf"))
	number.add_theme_font_size_override("font_size", 34)
	number.add_theme_color_override("font_color", _color)
	number.add_theme_color_override("font_outline_color", Color("150f14"))
	number.add_theme_constant_override("outline_size", 5)
	add_child(number)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "_progress", 1.0, 0.7)
	tween.tween_property(number, "position:y", -170.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, 0.35).set_delay(0.35)
	tween.chain().tween_callback(func(): finished.emit(); queue_free())

func _draw() -> void:
	var color := Color(_color, (1.0 - _progress) * 0.85)
	var radius := 22.0 + _progress * 60.0
	if kind == "lightning":
		var bolt := PackedVector2Array([Vector2(-14, -65), Vector2(8, -26), Vector2(-8, -24), Vector2(17, 17), Vector2(0, -12), Vector2(16, -16)])
		draw_polyline(bolt, color, 5.0, true)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, color, 3, true)
	elif kind == "burn":
		for index: int in 5:
			var x := (index - 2) * 20.0
			var rise := -_progress * 65.0
			var flame := PackedVector2Array([Vector2(x - 10, rise + 12), Vector2(x - 13, rise - 8), Vector2(x, rise - 42 - (index % 2) * 14), Vector2(x + 12, rise - 5), Vector2(x + 9, rise + 12)])
			draw_colored_polygon(flame, color)
	else:
		for index: int in 7:
			var angle := index * TAU / 7.0
			var point := Vector2(cos(angle), sin(angle)) * radius - Vector2(0, _progress * 35.0)
			draw_circle(point, 5.0 + (index % 3) * 2, color)
