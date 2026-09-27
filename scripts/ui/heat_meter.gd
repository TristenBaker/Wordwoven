extends PanelContainer
## Compact, font-consistent meter with animated embers and a contextual hint.
const RULES = preload("res://scripts/combat/tundra_cold.gd")
var title: Label
var hint: Label
var pips: Array[Panel] = []
var _pulse: Tween
var _last_heat: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("182936")
	style.border_color = Color("638996")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	title = Label.new()
	title.add_theme_font_override("font", preload("res://assets/Fonts/Junicode.ttf"))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffcf8c"))
	row.add_child(title)
	for i in RULES.MAX_HEAT:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(13, 10)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ember := StyleBoxFlat.new()
		ember.bg_color = Color("ffc078")
		ember.set_corner_radius_all(4)
		pip.add_theme_stylebox_override("panel", ember)
		row.add_child(pip)
		pips.append(pip)
	hint = Label.new()
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("c0dce5"))
	row.add_child(hint)

func refresh(heat: int, turns: int, has_frozen: bool) -> void:
	title.text = "🔥 Heat: %d/%d" % [heat, RULES.MAX_HEAT]
	hint.text = "Frost in %d • Thaw: %d Heat" % [RULES.FREEZE_EVERY - turns % RULES.FREEZE_EVERY, RULES.THAW_COST]
	if has_frozen:
		hint.text = "Click ice to thaw • %d Heat" % RULES.THAW_COST if heat >= RULES.THAW_COST else "Thaw needs %d Heat • Cast to warm up" % RULES.THAW_COST
	for i in pips.size():
		pips[i].modulate = Color.WHITE if i < heat else Color(0.3, 0.4, 0.48, 0.5)
	if _last_heat >= 0 and _last_heat != heat:
		pulse(heat < _last_heat)
	_last_heat = heat

func pulse(spent: bool = false) -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	modulate = Color("ffb975") if spent else Color("ffe4ad")
	_pulse = create_tween()
	_pulse.tween_property(self, "modulate", Color.WHITE, 0.45)
