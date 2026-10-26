class_name PermanentUpgradesOverlay
extends Control
## Title-screen store for small, persistent elemental potency ranks.

const BODY := preload("res://assets/Fonts/Junicode.ttf")
const BUTTON_THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")
const STAR_COIN := preload("res://assets/Art/Items/starcoin.png")

var _coin_label: Label
var _grid: GridContainer


static func open_in(parent: Node) -> void:
	var existing := parent.get_node_or_null("PermanentUpgradesOverlay")
	if existing != null:
		existing.queue_free()
	var overlay := PermanentUpgradesOverlay.new()
	overlay.name = "PermanentUpgradesOverlay"
	parent.add_child(overlay)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.012, 0.03, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 620)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var heading := HBoxContainer.new()
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(heading)
	var title := _label("PERMANENT UPGRADES", 38, Color("ffe08a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var dev_coin := Button.new()
	dev_coin.theme = BUTTON_THEME
	dev_coin.theme_type_variation = &"WordWovenActionButton"
	dev_coin.text = "DEV +1 ★"
	dev_coin.tooltip_text = "Development shortcut: award one StarCoin."
	dev_coin.custom_minimum_size = Vector2(112, 34)
	dev_coin.pressed.connect(_add_dev_coin)
	heading.add_child(dev_coin)
	var coin_row := HBoxContainer.new()
	coin_row.custom_minimum_size = Vector2(0, 46)
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 10)
	content.add_child(coin_row)
	var coin_icon := TextureRect.new()
	coin_icon.custom_minimum_size = Vector2(42, 42)
	coin_icon.texture = _star_coin_badge()
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_row.add_child(coin_icon)
	_coin_label = _label("", 23, Color("f6d46f"))
	_coin_label.custom_minimum_size = Vector2(240, 0)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coin_row.add_child(_coin_label)
	content.add_child(_label("New combat words grant StarCoins once. Left-click invests; right-click refunds. Each rank adds 3% elemental potency.", 18, Color("d8cbb5")))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	var close := Button.new()
	close.theme = BUTTON_THEME
	close.theme_type_variation = &"WordWovenActionButton"
	close.text = "Back"
	close.custom_minimum_size = Vector2(180, 42)
	close.pressed.connect(queue_free)
	content.add_child(close)
	_refresh()


func _refresh() -> void:
	_coin_label.text = "Available StarCoins:  %d" % PlayerProfile.star_coins
	for child: Node in _grid.get_children():
		child.queue_free()
	for element: String in PlayerProfile.ELEMENTS:
		var rank := PlayerProfile.potency_level(element)
		var cost := PlayerProfile.upgrade_cost(element)
		var button := Button.new()
		button.custom_minimum_size = Vector2(310, 100)
		button.theme = BUTTON_THEME
		button.theme_type_variation = &"WordWovenActionButton"
		button.add_theme_font_override("font", BODY)
		button.add_theme_font_size_override("font_size", 19)
		button.text = "%s  •  Rank %d\n+%d%% potency  →  +%d%%\nLeft-click: invest 1 ★   •   Right-click: refund 1 ★" % [
			element.capitalize(), rank, rank * 3, (rank + 1) * 3,
		]
		button.add_theme_color_override("font_color", _element_color(element))
		button.add_theme_stylebox_override("normal", _upgrade_style(element, PlayerProfile.star_coins >= cost))
		button.add_theme_stylebox_override("hover", _upgrade_style(element, PlayerProfile.star_coins >= cost, true))
		button.pressed.connect(_buy_upgrade.bind(element))
		button.gui_input.connect(_on_upgrade_input.bind(element))
		_grid.add_child(button)


func _buy_upgrade(element: String) -> void:
	if PlayerProfile.buy_element_upgrade(element):
		_refresh()


func _on_upgrade_input(event: InputEvent, element: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index == MOUSE_BUTTON_RIGHT and click.pressed:
		if PlayerProfile.refund_element_upgrade(element):
			_refresh()


func _add_dev_coin() -> void:
	PlayerProfile.add_dev_star_coin()
	_refresh()


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _element_color(element: String) -> Color:
	match element:
		"fire": return Color("ef735d")
		"lightning": return Color("e4c34a")
		"water": return Color("63b4ef")
		"ice": return Color("a3e9f7")
		"nature": return Color("79d37a")
		_: return Color("ca9264")


func _upgrade_style(element: String, affordable: bool, hovered: bool = false) -> StyleBoxFlat:
	var color := _element_color(element)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a1d35") if not hovered else Color("3a2948")
	style.border_color = color if affordable else Color("725f70")
	style.set_border_width_all(3 if affordable else 2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	if affordable:
		style.shadow_color = Color(color, 0.72)
		style.shadow_size = 10
		style.shadow_offset = Vector2.ZERO
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171226")
	style.border_color = Color("c79b50")
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 22.0
	return style


func _star_coin_badge() -> AtlasTexture:
	var badge := AtlasTexture.new()
	badge.atlas = STAR_COIN
	# The supplied artwork has generous transparent canvas around the coin.
	badge.region = Rect2(150, 150, 980, 980)
	return badge
