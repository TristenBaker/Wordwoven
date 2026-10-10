extends PanelContainer
## Presentation only: reads the active modifier's existing display fields.

const HELPFUL := Color("a7d8b0")
const HARMFUL := Color("e5a49a")
const NEUTRAL := Color("ead9b0")

@onready var name_label: Label = $Content/ModifierName
@onready var effect_label: Label = $Content/Effect
var _dev_button: Control
var _timer_label: Control


func _ready() -> void:
	var style: StyleBox = get_theme_stylebox("panel").duplicate()
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", style)
	_dev_button = get_node_or_null("../DevKillButton")
	_timer_label = get_node_or_null("../StatusArea/TimerLabel")
	minimum_size_changed.connect(_queue_fit)
	if _timer_label != null:
		_timer_label.item_rect_changed.connect(_queue_fit)
	if _dev_button != null:
		_dev_button.item_rect_changed.connect(_queue_fit)
	_queue_fit()


func _queue_fit() -> void:
	_fit_below_timer.call_deferred()


func _fit_below_timer() -> void:
	if not is_inside_tree():
		return
	var minimum: Vector2 = get_combined_minimum_size()
	size = Vector2(_dev_button.size.x if _dev_button != null else minimum.x, minimum.y)
	if _timer_label != null:
		var timer_rect: Rect2 = _timer_label.get_global_rect()
		global_position = Vector2(timer_rect.position.x, timer_rect.end.y + 10.0)
	if _dev_button != null:
		_dev_button.global_position = Vector2(global_position.x, get_global_rect().end.y + 8.0)


func show_modifier(_word: String, modifier: Dictionary, _base: Dictionary, _applied: Dictionary, _player_factor: float) -> void:
	if modifier.is_empty():
		name_label.text = "No Active Modifier"
		name_label.add_theme_color_override("font_color", NEUTRAL)
		effect_label.text = ""
		effect_label.hide()
		tooltip_text = "No modifier is applied to this encounter."
	else:
		name_label.text = "Modifier: %s" % String(modifier.get("name", ""))
		effect_label.text = String(modifier.get("effect", ""))
		effect_label.show()
		var accent: Color = HELPFUL if modifier.get("beneficial", false) else HARMFUL
		name_label.add_theme_color_override("font_color", accent)
		effect_label.add_theme_color_override("font_color", accent)
		tooltip_text = ""
	_queue_fit()
