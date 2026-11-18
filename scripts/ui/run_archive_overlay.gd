class_name RunArchiveOverlay
extends Control
## Read-only final loadouts; never applies today's combat bonuses.
const THEME := preload("res://assets/Themes/WordWoven_Button_Theme.tres")
const FRAME := preload("res://assets/Themes/encounters/information_panel.tres")
const FONT := preload("res://assets/Fonts/Junicode.ttf")
const LETTER_SLOT := preload("res://scripts/ui/archived_letter_slot.gd")
const COLORS := [Color("ef735d"), Color("e4c34a"), Color("63b4ef"), Color("a3e9f7"), Color("79d37a"), Color("ca9264")]
var _record: Dictionary = {}
var _selected_tile: Dictionary = {}
var _details: VBoxContainer
var _runs: VBoxContainer


static func open_in(parent: Node, record: Dictionary = {}, tile: Dictionary = {}) -> void:
	if parent.get_node_or_null("RunArchiveOverlay") != null:
		return
	var overlay := RunArchiveOverlay.new()
	overlay.name = "RunArchiveOverlay"
	overlay._record = record
	overlay._selected_tile = tile
	parent.add_child(overlay)


func _ready() -> void:
	add_to_group("run_archive_overlay")
	z_index = 450
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.color = Color(0.025, 0.03, 0.05, 0.9)
	add_child(shade)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 32)
	add_child(outer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", FRAME)
	outer.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := _label("PAST LOADOUTS", 29, Color("f1d296"))
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(title)
	_action(heading, "Close", queue_free)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(columns)
	_runs = VBoxContainer.new()
	_runs.custom_minimum_size.x = 230
	_scroll(columns, _runs, false)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 12)
	_scroll(columns, _details, true)
	var records := RunArchive.new().entries()
	for run: Dictionary in records:
		var summary: Dictionary = run.summary
		_action(_runs, "%s\n%s · %s\nScore %d" % [_date(run.finished_at), summary.get("mode", "Story"),
			"Victory" if summary.get("victory", false) else "Defeat", int(summary.get("score", 0))], _show_run.bind(run))
	if _record.is_empty() and not records.is_empty():
		_record = records[0]
	_show_run(_record, _selected_tile)


func _scroll(parent: Node, content: Control, expand: bool) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	if expand:
		scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(scroll)
	scroll.add_child(content)


func _show_run(record: Dictionary, selected: Dictionary = {}) -> void:
	_record = record
	(_details.get_parent() as ScrollContainer).scroll_vertical = 0
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	if record.is_empty():
		_details.add_child(_label("No archived loadouts yet.\nFinish a run to save its final equipped letters and powers.", 21))
		return
	var summary: Dictionary = record.summary
	_details.add_child(_label("%s · %s · %s" % [summary.get("mode", "Story"),
		"Victory" if summary.get("victory", false) else "Defeat", _date(record.finished_at)], 24, Color("f1d296")))
	_details.add_child(_label("Score %d · %s" % [int(summary.get("score", 0)), summary.get("biome", "Unknown")], 18))
	if not selected.is_empty():
		var tile := RunArchive.letter_from_record(selected)
		var hero := HBoxContainer.new()
		hero.add_theme_constant_override("separation", 18)
		_details.add_child(hero)
		var cosmetic := PlayerProfile.cosmetic_resource(String(selected.get("cosmetic", "")))
		if cosmetic == null:
			cosmetic = PlayerProfile.default_combat_cosmetic(tile.element)
		var portrait := TextureRect.new()
		portrait.texture = cosmetic.portrait
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(110, 110)
		hero.add_child(portrait)
		var identity := "%s · %s\nFinal level %d\n%s" % [tile.letter.to_upper(), tile.element_name_text(), tile.level, cosmetic.display_name]
		if tile.modifier != LetterStats.Modifier.NONE:
			identity += "\n" + tile.modifier_name_text()
		var identity_label := _label(identity, 25, COLORS[tile.element])
		identity_label.name = "ArchivedLetterIdentity"
		hero.add_child(identity_label)
		_details.add_child(_label("This letter's final appearance and loadout from that run.", 17))
	_details.add_child(_label("FINAL EQUIPPED LETTERS", 20, Color("f1d296")))
	var tiles := GridContainer.new()
	tiles.name = "AlphabetSlots"
	tiles.columns = 9
	tiles.add_theme_constant_override("h_separation", 8)
	tiles.add_theme_constant_override("v_separation", 8)
	_details.add_child(tiles)
	var equipped: Dictionary = {}
	for saved: Dictionary in record.equipped_letters:
		equipped[String(saved.letter)] = saved
	for index: int in 26:
		var character := String.chr(97 + index)
		var saved: Dictionary = equipped.get(character, {})
		var button := LETTER_SLOT.new()
		button.name = "Slot_" + character.to_upper()
		tiles.add_child(button)
		button.setup(character, saved, not saved.is_empty() and selected == saved)
		if not saved.is_empty():
			button.pressed.connect(_show_run.bind(record, saved))
	if record.equipped_letters.is_empty():
		_details.add_child(_label("No letters equipped at the end of this run.", 18))
	_details.add_child(_label("FINAL POWERS", 20, Color("f1d296")))
	for power: Dictionary in record.powers:
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.add_theme_font_override("normal_font", FONT)
		text.add_theme_font_size_override("normal_font_size", 18)
		var quality: Color = RelicSystem.QUALITY_COLORS.get(String(power.get("quality", "common")), Color.WHITE)
		text.text = "[color=#%s][b]%s ×%d[/b][/color]\n%s" % [quality.to_html(false), power.name, int(power.count), power.combined_effect]
		_details.add_child(text)
	if record.powers.is_empty():
		_details.add_child(_label("No powers acquired in this run.", 18))


func _action(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.theme = THEME
	button.theme_type_variation = &"WordWovenActionButton"
	button.text = text
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(text: String, size: int, color: Color = Color("e8dfce")) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


static func _date(timestamp: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(timestamp)).replace("T", " ") + " UTC"
