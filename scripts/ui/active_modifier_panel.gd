extends PanelContainer
## Presentation only: reads the active modifier's existing display fields.

const HELPFUL := Color("a7d8b0")
const HARMFUL := Color("e5a49a")
const NEUTRAL := Color("ead9b0")

@onready var name_label: Label = $Content/ModifierName
@onready var effect_label: Label = $Content/Effect
var _player_panel: Control


func _ready() -> void:
	_player_panel = get_node_or_null("../StatusArea")
	if _player_panel != null:
		var frame := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		frame.content_margin_top = 8.0
		frame.content_margin_bottom = 8.0
		add_theme_stylebox_override("panel", frame)
		effect_label.add_theme_constant_override("line_spacing", 4)
	minimum_size_changed.connect(_queue_fit)
	if _player_panel != null:
		_player_panel.item_rect_changed.connect(_queue_fit)
	_queue_fit()


func _queue_fit() -> void:
	_fit_below_player.call_deferred()


func _fit_below_player() -> void:
	if not is_inside_tree():
		return
	if _player_panel != null:
		var player_rect := _player_panel.get_global_rect()
		size = Vector2(player_rect.size.x, get_combined_minimum_size().y)
		global_position = Vector2(player_rect.position.x, player_rect.end.y + 6.0)
	else:
		var minimum := get_combined_minimum_size()
		size = Vector2(maxf(264.0, minimum.x), minimum.y)



func show_modifier(_word: String, modifier: Dictionary, _base: Dictionary, _applied: Dictionary, _player_factor: float) -> void:
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if _player_panel != null else TextServer.AUTOWRAP_OFF
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
		tooltip_text = ""
	_queue_fit()

## These two status strings give the full rule, including any threshold.
func show_status(modifier: Dictionary, status: String) -> void:
	if status.is_empty(): return
	var text: String = status if modifier.get("id") in ["frostbite_tax", "long_winded"] else "%s\n%s" % [modifier.effect, status]
	if effect_label.text == text: return
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.text = text
	_queue_fit()
