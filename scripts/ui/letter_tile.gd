class_name LetterTile
extends PanelContainer
## One letter tile in the combat hand. Its fill signals class and its
## border signals rank; badges mark redraw selection and temporary
## conditions, with detailed mechanics available by tooltip.

signal pressed(stats: LetterStats)

# Used letters fade from the hand while their visual copy travels to the board.
const COLOR_IDLE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_USED: Color = Color(0.45, 0.45, 0.45, 0.35)
const COLOR_FROZEN_TINT: Color = Color(0.7, 0.88, 1.0, 1.0)
const COLOR_SELECTED_BORDER: Color = Color(1.0, 0.92, 0.35, 1.0)
const SELECTED_LIFT: float = 12.0

@export var tile_theme: LetterTileTheme = preload(
		"res://assets/Themes/letter_tiles/default_letter_tile_theme.tres"
)

var stats: LetterStats = null

var _selected: bool = false
var _frozen: bool = false
var _poisoned: bool = false
var _condition_text: String = ""

@onready var letter_label: Label = $Layout/LetterLabel
@onready var frozen_badge: Label = $Badges/FrozenBadge
@onready var poisoned_badge: Label = $Badges/PoisonedBadge
@onready var selected_badge: Label = $Badges/SelectedBadge


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(stats)
		accept_event()


func setup(new_stats: LetterStats) -> void:
	stats = new_stats
	letter_label.text = stats.letter.to_upper()
	letter_label.add_theme_color_override(
		"font_color", tile_theme.letter_color
	)
	_refresh_style()


## Brightens or dims the tile while a word is being typed.
func set_used(used: bool, typing: bool) -> void:
	if not typing:
		modulate = COLOR_IDLE
	elif used:
		modulate = COLOR_USED
	else:
		modulate = COLOR_IDLE
	if _frozen and modulate == COLOR_IDLE:
		modulate = COLOR_FROZEN_TINT


## Shows this instance's temporary conditions.
func set_conditions(frozen: bool, poisoned: bool, text: String) -> void:
	_frozen = frozen
	_poisoned = poisoned
	_condition_text = text
	frozen_badge.visible = frozen
	poisoned_badge.visible = poisoned
	if frozen and modulate == COLOR_IDLE:
		modulate = COLOR_FROZEN_TINT
	elif not frozen and modulate == COLOR_FROZEN_TINT:
		modulate = COLOR_IDLE
	_refresh_style()


## Marks the tile as chosen for a paid redraw.
func set_selected(selected: bool) -> void:
	_selected = selected
	selected_badge.visible = selected
	_refresh_style()


func is_selected() -> bool:
	return _selected


func _refresh_style() -> void:
	if stats == null:
		return
	add_theme_stylebox_override("panel", _tile_style())
	var lines: Array[String] = [stats.describe(), stats.effect_text()]
	if not _condition_text.is_empty():
		lines.append(_condition_text)
	lines.append(
		"Selected for redraw. Click to deselect." if _selected
		else "Click to select for a paid redraw."
	)
	tooltip_text = "\n".join(lines)


func _tile_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = tile_theme.fill_for(stats.letter_class)
	style.border_color = tile_theme.border_for(stats.level)
	if _selected:
		style.border_color = COLOR_SELECTED_BORDER
		style.expand_margin_top = SELECTED_LIFT
	style.set_border_width_all(6)
	style.set_corner_radius_all(10)
	style.shadow_color = tile_theme.shadow_color
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	return style
