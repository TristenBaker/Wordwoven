class_name LetterTile
extends PanelContainer
## One letter tile in the combat hand. Its fill signals class and its
## border signals rank; detailed mechanics remain available by tooltip.

# Used letters fade from the hand while their visual copy travels to the board.
const COLOR_IDLE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_USED: Color = Color(0.45, 0.45, 0.45, 0.35)

signal activated(tile: LetterTile)
var frozen: bool = false
var _affordable: bool = false
var _frost: Control
var _badge: Label
var _ice_tween: Tween
var _feedback_tween: Tween
var stats: LetterStats = null

func _ready() -> void:
	$Layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost = Control.new()
	_frost.set_script(preload("res://scripts/ui/frost_overlay.gd"))
	_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frost)
	_frost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge = Label.new()
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 11)
	_frost.add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_badge.offset_top = -21
	_badge.offset_bottom = -5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activated.emit(self)
		accept_event()

func set_frozen(value: bool, affordable: bool, animate: bool = false) -> void:
	if value == frozen and (not value or affordable == _affordable) and not animate:
		return
	_affordable = affordable
	var was_frozen: bool = frozen
	frozen = value
	var style := _tile_style()
	if frozen:
		style.bg_color = Color("315d79")
		style.border_color = Color("ffd19b") if affordable else Color("a4e3f4")
		style.set_border_width_all(3)
		style.shadow_color = Color(0.35, 0.72, 0.86, 0.3)
	add_theme_stylebox_override("panel", style)
	letter_label.add_theme_color_override("font_color", Color("e1faff") if frozen else tile_theme.letter_color)
	_badge.text = ("THAW · %d" % TundraCold.THAW_COST if affordable else "FROZEN") if frozen else ""
	_badge.add_theme_color_override("font_color", Color("ffdaaa") if affordable else Color("c5edf9"))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if frozen and affordable else Control.CURSOR_ARROW
	tooltip_text = "%s\n%s" % [stats.describe(), stats.effect_text()]
	if frozen:
		tooltip_text += "\nFrozen — click to thaw for %d Heat. Valid words grant +%d Heat." % [TundraCold.THAW_COST, TundraCold.HEAT_PER_WORD]
	if not animate and was_frozen == frozen and _ice_tween != null and _ice_tween.is_valid():
		return
	if _ice_tween != null and _ice_tween.is_valid():
		_ice_tween.kill()
	if animate:
		_ice_tween = create_tween().set_parallel(true)
		var target_fill: Color = style.bg_color
		var target_border: Color = style.border_color
		style.bg_color = tile_theme.fill_for(stats.letter_class) if frozen else Color("315d79")
		style.border_color = tile_theme.border_for(stats.level) if frozen else Color("ffd19b")
		_ice_tween.tween_property(style, "bg_color", target_fill, 0.4)
		_ice_tween.tween_property(style, "border_color", target_border, 0.4)
		_ice_tween.tween_property(_frost, "amount", 1.0 if frozen else 0.0, 0.45)
		modulate = Color("b3e9ff") if frozen else Color("ffd09a")
		_ice_tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	elif was_frozen != frozen or not frozen:
		_frost.set("amount", 1.0 if frozen else 0.0)

func deny_thaw() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_badge.text = "NEED %d HEAT" % TundraCold.THAW_COST
	_badge.modulate = Color("ffb185")
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_badge, "modulate", Color.WHITE, 0.5)


@export var tile_theme: LetterTileTheme = preload(
		"res://assets/Themes/letter_tiles/default_letter_tile_theme.tres"
)

@onready var letter_label: Label = $Layout/LetterLabel


func setup(new_stats: LetterStats) -> void:
	stats = new_stats
	letter_label.text = stats.letter.to_upper()
	letter_label.add_theme_color_override("font_color", tile_theme.letter_color)
	add_theme_stylebox_override("panel", _tile_style())
	tooltip_text = "%s\n%s" % [stats.describe(), stats.effect_text()]


## Brightens or dims the tile while a word is being typed.
func set_used(used: bool, typing: bool) -> void:
	if frozen:
		return
	if not typing:
		modulate = COLOR_IDLE
	elif used:
		modulate = COLOR_USED
	else:
		modulate = COLOR_IDLE


func _tile_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = tile_theme.fill_for(stats.letter_class)
	style.border_color = tile_theme.border_for(stats.level)
	style.set_border_width_all(6)
	style.set_corner_radius_all(10)
	style.shadow_color = tile_theme.shadow_color
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	return style
