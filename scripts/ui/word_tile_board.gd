extends Control
class_name WordTileBoard

## Visual word composer. The combat LineEdit remains the authoritative input;
## this control renders that text as individual tiles and returns focus on click.

signal focus_requested

const MIN_TILE_SIZE := 28.0
const MAX_TILE_SIZE := 56.0
const TILE_GAP := 7.0
const BOARD_PADDING := 14.0

var _word := ""
var _tile_stats: Array = []

@export var tile_theme: LetterTileTheme = preload(
		"res://assets/Themes/letter_tiles/default_letter_tile_theme.tres"
)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_word(word: String, drawn: Array[LetterStats]) -> void:
	_word = word.to_upper()
	_tile_stats = _stats_for_word(word.to_lower(), drawn)
	queue_redraw()


func _stats_for_word(
	word: String, drawn: Array[LetterStats]
) -> Array:
	var remaining: Array[LetterStats] = drawn.duplicate()
	var tile_stats: Array = []
	for letter: String in word:
		var matched: LetterStats = null
		for stats: LetterStats in remaining:
			if stats.letter == letter:
				matched = stats
				break
		if matched != null:
			remaining.erase(matched)
		tile_stats.append(matched)
	return tile_stats


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		focus_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_board_style(), board_rect)
	if _word.is_empty():
		_draw_empty_state()
		return

	var count := _word.length()
	var font := ThemeDB.fallback_font
	for index in range(count):
		var letter := _word.substr(index, 1)
		var tile_rect := _tile_rect_for_index(index)
		var font_size := int(clampf(
			tile_rect.size.x * 0.56, 18.0, 32.0
		))
		var stats: LetterStats = _tile_stats[index] \
				if index < _tile_stats.size() else null
		_draw_tile(tile_rect, letter, stats, font, font_size)


func tile_global_rect_for(stats: LetterStats) -> Rect2:
	for index in range(_tile_stats.size()):
		if _tile_stats[index] == stats:
			var tile_rect := _tile_rect_for_index(index)
			return Rect2(
				get_global_transform() * tile_rect.position,
				tile_rect.size
			)
	return Rect2()


func _tile_rect_for_index(index: int) -> Rect2:
	var count := maxi(_word.length(), 1)
	var available_width := maxf(1.0, size.x - BOARD_PADDING * 2.0)
	var tile_size := clampf(
		(available_width - TILE_GAP * float(count - 1)) / float(count),
		MIN_TILE_SIZE,
		MAX_TILE_SIZE
	)
	var total_width := tile_size * float(count - 1) \
			+ tile_size + TILE_GAP * float(count - 1)
	var start_x := maxf(BOARD_PADDING, (size.x - total_width) * 0.5)
	var start_y := maxf(6.0, (size.y - tile_size) * 0.5)
	return Rect2(
		start_x + float(index) * (tile_size + TILE_GAP),
		start_y, tile_size, tile_size
	)


func _draw_empty_state() -> void:
	draw_string(
		ThemeDB.fallback_font, Vector2(0, size.y * 0.5 + 7.0),
		"Type a word to build your tiles", HORIZONTAL_ALIGNMENT_CENTER,
		size.x, 18, Color("bda980")
	)


func _draw_tile(
	tile_rect: Rect2, letter: String, stats: LetterStats,
	font: Font, font_size: int
) -> void:
	var is_drawn := stats != null
	var shadow_rect := tile_rect.grow(1.0)
	shadow_rect.position += Vector2(2.0, 3.0)
	draw_style_box(
		_tile_style(tile_theme.shadow_color, Color("090604"), 2), shadow_rect
	)
	var fill := tile_theme.fill_for(stats.letter_class) \
			if is_drawn else Color("d9c08a")
	var border := tile_theme.border_for(stats.level) \
			if is_drawn else Color("8a6b37")
	var border_width := 4 if is_drawn else 2
	draw_style_box(_tile_style(fill, border, border_width), tile_rect)
	draw_string(
		font, Vector2(tile_rect.position.x, tile_rect.position.y + tile_rect.size.y * 0.68),
		letter, HORIZONTAL_ALIGNMENT_CENTER, tile_rect.size.x, font_size,
		tile_theme.letter_color if is_drawn else Color("3b2c18")
	)


func _board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("16100c")
	style.border_color = Color("b5843b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _tile_style(
	fill: Color, border: Color, border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style
