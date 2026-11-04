class_name TalentAccessButton
extends TextureButton
## Shared mid-run access to the elemental tree.
signal talents_closed
const ICON := preload("res://assets/Art/Items/talent_medallion.png")
const STAR_COIN := preload("res://assets/Art/Items/starcoin.png")
var _bag: Control
var _point_count: Label
var _notification_dot: Panel

func _ready() -> void:
	texture_normal = ICON
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Elemental Talents — spend or refund your StarCoins"
	pressed.connect(_open_talents)
	mouse_entered.connect(func(): self_modulate = Color(1.2, 1.2, 1.2))
	mouse_exited.connect(func(): self_modulate = Color.WHITE)
	_build_point_badge()
	PlayerProfile.star_coins_changed.connect(_update_point_badge)
	_update_point_badge(PlayerProfile.star_coins)

func _build_point_badge() -> void:
	var coin := TextureRect.new()
	coin.name = "StarCoinIcon"
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.texture = STAR_COIN
	coin.position = Vector2(-4, 62)
	coin.size = Vector2(22, 22)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin)
	_point_count = Label.new()
	_point_count.name = "StarCoinCount"
	_point_count.position = Vector2(17, 62)
	_point_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_point_count.add_theme_font_override("font", preload("res://assets/Fonts/Junicode.ttf"))
	_point_count.add_theme_font_size_override("font_size", 17)
	_point_count.add_theme_color_override("font_color", Color("e3f2ff"))
	_point_count.add_theme_color_override("font_outline_color", Color("12061f"))
	_point_count.add_theme_constant_override("outline_size", 3)
	add_child(_point_count)
	_notification_dot = Panel.new()
	_notification_dot.name = "UnspentPointsDot"
	_notification_dot.position = Vector2(2, 2)
	_notification_dot.size = Vector2(18, 18)
	_notification_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e54646")
	style.border_color = Color("fff3df")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	_notification_dot.add_theme_stylebox_override("panel", style)
	add_child(_notification_dot)

func _update_point_badge(available: int) -> void:
	_point_count.text = str(available)
	_notification_dot.visible = available > 0

func _open_talents() -> void:
	if get_tree().paused or get_tree().get_first_node_in_group("talent_overlay") != null:
		return
	var owner_scene := get_tree().current_scene
	if owner_scene == null:
		return
	if owner_scene.has_method("can_open_talents") and not owner_scene.can_open_talents():
		tooltip_text = "Talents are available when choosing your next word."
		return
	tooltip_text = "Elemental Talents — spend or refund your StarCoins"
	PermanentUpgradesOverlay.open_in(owner_scene, true)
	var overlay := owner_scene.get_node_or_null("PermanentUpgradesOverlay")
	if overlay != null:
		overlay.tree_exited.connect(func(): talents_closed.emit())

static func beside_bag(parent: Control, bag: Control) -> TalentAccessButton:
	var button := TalentAccessButton.new()
	button.name = "TalentButton"
	button.z_index = 40
	button._bag = bag
	parent.add_child(button)
	parent.resized.connect(button._align_to_bag)
	button._align_to_bag.call_deferred()
	return button

func _align_to_bag() -> void:
	if not is_instance_valid(_bag):
		return
	var rect := _bag.get_global_rect()
	size = Vector2(78, 78)
	global_position = rect.position - Vector2(90, 0)
