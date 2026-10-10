class_name LetterInspector
extends CanvasLayer
## Reusable detail panel for any letter source. It is created on demand so
## combat, inventory, shops, and future Forge entries share one presentation.

const WARRIOR_PORTRAIT: Texture2D = preload(
	"res://art/party/portraits/warrior_1.png"
)
const HEALER_PORTRAIT: Texture2D = preload(
	"res://art/party/portraits/healer_1.png"
)
const ROGUE_PORTRAIT: Texture2D = preload(
	"res://art/party/portraits/rogue_1.png"
)

var _letter_label: Label
var _element_label: Label
var _level_label: Label
var _portrait: TextureRect
var _description_label: Label
var _throughput_label: Label
var _powers_list: VBoxContainer


static func open_for(stats: LetterStats) -> void:
	if stats == null:
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var existing: Node = tree.get_first_node_in_group("letter_inspector")
	if existing != null and existing is LetterInspector:
		var open_inspector: LetterInspector = existing as LetterInspector
		open_inspector.inspect(stats)
		return
	var inspector: LetterInspector = LetterInspector.new()
	tree.root.add_child(inspector)
	inspector.inspect(stats)


func _ready() -> void:
	add_to_group("letter_inspector")
	_build()


func inspect(stats: LetterStats) -> void:
	if _letter_label == null:
		return
	var color: Color = _element_color(stats.element)
	_letter_label.text = stats.letter.to_upper()
	_element_label.text = stats.element_name_text().to_upper()
	_element_label.add_theme_color_override("font_color", color)
	_level_label.text = "Level %d" % stats.level
	_portrait.texture = _portrait_for(stats.element)
	_description_label.text = stats.element_detail_text()
	_throughput_label.text = stats.throughput_text()
	_rebuild_powers(stats, color)


func _build() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -440.0
	panel.offset_top = 24.0
	panel.offset_right = -24.0
	panel.offset_bottom = -24.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var heading: HBoxContainer = HBoxContainer.new()
	content.add_child(heading)
	var title: Label = Label.new()
	title.text = "LETTER DETAILS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f6d797"))
	heading.add_child(title)
	var close: Button = Button.new()
	close.theme = preload("res://assets/Themes/WordWoven_Button_Theme.tres")
	close.theme_type_variation = &"WordWovenActionButton"
	close.text = "×"
	close.custom_minimum_size = Vector2(42.0, 36.0)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(queue_free)
	heading.add_child(close)

	var hero: HBoxContainer = HBoxContainer.new()
	hero.custom_minimum_size = Vector2(0.0, 132.0)
	content.add_child(hero)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(124.0, 124.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.add_child(_portrait)
	var identity: VBoxContainer = VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(identity)
	_letter_label = Label.new()
	_letter_label.add_theme_font_size_override("font_size", 60)
	_letter_label.add_theme_color_override("font_color", Color("fff7df"))
	identity.add_child(_letter_label)
	_element_label = Label.new()
	_element_label.add_theme_font_size_override("font_size", 23)
	identity.add_child(_element_label)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color("ddd1c2"))
	identity.add_child(_level_label)

	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.add_theme_font_size_override("font_size", 18)
	_description_label.add_theme_color_override("font_color", Color("f1e6d5"))
	content.add_child(_description_label)
	_throughput_label = Label.new()
	_throughput_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_throughput_label.add_theme_font_size_override("font_size", 18)
	_throughput_label.add_theme_color_override("font_color", Color("ffd98d"))
	content.add_child(_throughput_label)

	var divider: HSeparator = HSeparator.new()
	content.add_child(divider)
	var powers_title: Label = Label.new()
	powers_title.text = "AFFECTED POWERS"
	powers_title.add_theme_font_size_override("font_size", 18)
	powers_title.add_theme_color_override("font_color", Color("f6d797"))
	content.add_child(powers_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 180.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_powers_list = VBoxContainer.new()
	_powers_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_powers_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_powers_list)


func _rebuild_powers(stats: LetterStats, element_color: Color) -> void:
	for child: Node in _powers_list.get_children():
		_powers_list.remove_child(child)
		child.queue_free()
	var power_system: RelicSystem = RelicSystem.new()
	var power_ids: Array[String] = power_system.affecting_power_ids(stats.element)
	if power_ids.is_empty():
		var none: Label = Label.new()
		none.text = "No selected powers affect this letter yet."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_color_override("font_color", Color("c6b9aa"))
		_powers_list.add_child(none)
		return
	for power_id: String in power_ids:
		var info: Dictionary = power_system.relic_info(power_id)
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override(
			"panel", _power_style(power_system.quality_color(power_id))
		)
		_powers_list.add_child(card)
		var label: Label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 16)
		label.text = "%s ×%d\n%s" % [
			info.get("name", power_id), RunState.relics.count(power_id),
			info.get("description", ""),
		]
		label.add_theme_color_override("font_color", element_color)
		card.add_child(label)


func _portrait_for(element: int) -> Texture2D:
	match element:
		LetterStats.Element.FIRE, LetterStats.Element.EARTH:
			return WARRIOR_PORTRAIT
		LetterStats.Element.LIGHTNING, LetterStats.Element.ICE:
			return ROGUE_PORTRAIT
	return HEALER_PORTRAIT


func _element_color(element: int) -> Color:
	match element:
		LetterStats.Element.FIRE:
			return Color("ef735d")
		LetterStats.Element.LIGHTNING:
			return Color("e4c34a")
		LetterStats.Element.WATER:
			return Color("63b4ef")
		LetterStats.Element.ICE:
			return Color("a3e9f7")
		LetterStats.Element.NATURE:
			return Color("79d37a")
		_:
			return Color("ca9264")


func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.035, 0.08, 0.98)
	style.border_color = Color("cf8cf5")
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 22.0
	style.content_margin_top = 18.0
	style.content_margin_right = 22.0
	style.content_margin_bottom = 18.0
	return style


func _power_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.08, 0.16, 1.0)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style
