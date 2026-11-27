extends PanelContainer

const RULES = preload("res://scripts/combat/tundra_cold.gd")
const FONT = preload("res://assets/Fonts/Junicode.ttf")
const BOLD_FONT = preload("res://assets/Fonts/Junicode-Bold.ttf")
const FIRE_ICON = preload("res://assets/Art/Items/fire.png")

var title: Label
var frost: Label
var help: Label
var flame: TextureRect
var fills: Array[Panel] = []
var _fill_tween: Tween
var _feedback_tween: Tween
var _last_heat := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size.x = 270.0
	size_flags_horizontal = Control.SIZE_SHRINK_END
	var frame := preload("res://assets/Themes/Combat_HUD_Panel.tres").duplicate() as StyleBoxFlat
	frame.content_margin_top = 7.0
	frame.content_margin_bottom = 7.0
	add_theme_stylebox_override("panel", frame)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 4)
	add_child(content)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 5)
	content.add_child(header)
	flame = TextureRect.new()
	flame.texture = FIRE_ICON
	flame.custom_minimum_size = Vector2(16, 16)
	flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(flame)
	title = _label(17, Color("ffda91"))
	title.add_theme_font_override("font", BOLD_FONT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	frost = _label(14, Color("c6d8eb"))
	header.add_child(frost)

	var track := HBoxContainer.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_constant_override("separation", 5)
	content.add_child(track)
	for index in RULES.MAX_HEAT:
		var segment := Panel.new()
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.custom_minimum_size = Vector2(0, 7)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var at_threshold := index + 1 == RULES.THAW_COST
		var outline := Color("ddba73") if at_threshold else Color("46546a")
		var recess := _style(Color("202c40"), outline, 3)
		if at_threshold:
			recess.set_border_width(SIDE_RIGHT, 3)
		segment.add_theme_stylebox_override("panel", recess)
		track.add_child(segment)

		var fill := Panel.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.add_child(fill)
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.offset_left = 1
		fill.offset_top = 1
		fill.offset_right = -3 if at_threshold else -1
		fill.offset_bottom = -1
		var ember := _style(Color("ab653f").lerp(Color("deb36a"), float(index) / float(maxi(1, RULES.MAX_HEAT - 1))),
			Color("d7ab68"), 2)
		fill.add_theme_stylebox_override("panel", ember)
		fill.modulate.a = 0.0
		fills.append(fill)

	help = _label(14, Color("d4dce8"))
	content.add_child(help)


func _style(fill: Color, outline: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func refresh(heat: int, turns: int, frozen_count: int, freeze_every: int,
		heat_per_word: int, frost_pending: bool) -> void:
	title.text = "Heat  %d / %d" % [heat, RULES.MAX_HEAT]
	var remaining := freeze_every - turns % freeze_every
	frost.text = "Frost pending" if frost_pending else "Frost in %d %s" % [
		remaining, "cast" if remaining == 1 else "casts"
	]
	var instruction := "Thaw: %d Heat" % RULES.THAW_COST
	if frozen_count > 0:
		instruction = "Click ice: %d Heat" % RULES.THAW_COST if heat >= RULES.THAW_COST \
			else "Need %d Heat to thaw" % RULES.THAW_COST
	help.text = "+%d per valid cast  •  %s" % [heat_per_word, instruction]
	tooltip_text = "Valid casts give +%d Heat. Frost checks every %d casts. Click a frozen letter to thaw it for %d Heat. The marked segment is the thaw threshold." % [
		heat_per_word, freeze_every, RULES.THAW_COST
	]
	if heat == _last_heat:
		return
	if _last_heat < 0:
		for index in fills.size():
			fills[index].modulate.a = 1.0 if index < heat else 0.0
	else:
		if _fill_tween != null:
			_fill_tween.kill()
		_fill_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		for index in fills.size():
			_fill_tween.tween_property(fills[index], "modulate:a", 1.0 if index < heat else 0.0, 0.25)
		if heat > _last_heat:
			_animate_feedback(flame, Color(1.12, 1.06, 0.94))
		else:
			_animate_feedback(title, Color("f3c98c"))
	_last_heat = heat


func deny_thaw() -> void:
	_animate_feedback(help, Color("ffb5aa"))


func _animate_feedback(target: Control, tint: Color) -> void:
	if _feedback_tween != null:
		_feedback_tween.kill()
	for control: Control in [flame, title, help]:
		control.modulate = Color.WHITE
	target.modulate = tint
	_feedback_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_feedback_tween.tween_property(target, "modulate", Color.WHITE, 0.32)
