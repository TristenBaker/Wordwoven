class_name LetterTooltip
extends PanelContainer
## Rich tooltip card shared by every interactive letter presentation.

const BACKGROUND: Color = Color("303238")
const BORDER: Color = Color("070707")
static var _tooltip_shell_theme: Theme


## The TooltipPanel looks up styling from the control that requested it.
## Give each letter control this tiny theme so Godot's wrapper is transparent.
static func transparent_shell_theme() -> Theme:
	if _tooltip_shell_theme == null:
		_tooltip_shell_theme = Theme.new()
		_tooltip_shell_theme.set_stylebox(
			"panel", "TooltipPanel", StyleBoxEmpty.new()
		)
	return _tooltip_shell_theme


static func create_for(stats: LetterStats) -> LetterTooltip:
	var tooltip := LetterTooltip.new()
	tooltip.add_theme_stylebox_override("panel", tooltip._panel_style())
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.custom_minimum_size = Vector2(330, 0)
	text.text = tooltip._content_for(stats)
	tooltip.add_child(text)
	return tooltip


func _content_for(stats: LetterStats) -> String:
	var element_color: Color = _element_color(stats.element)
	var color_code: String = element_color.to_html(false)
	var lines: Array[String] = [
		"[center][font_size=24][b]%s[/b][/font_size][/center]" % stats.letter.to_upper(),
		"[center][color=#%s][b]%s[/b][/color][/center]" % [
			color_code, stats.element_name_text().to_upper(),
		],
		"Level: %d" % stats.level,
		"",
		stats.element_detail_text(),
		"[b]Base contribution:[/b] [color=#%s][b]%.1f %s damage[/b][/color] per use." % [
			color_code, stats.power(), stats.element_name_text(),
		],
		"",
		"[b]Affected by powers:[/b]",
	]
	var power_system := RelicSystem.new()
	var power_ids: Array[String] = power_system.affecting_power_ids(stats.element)
	if power_ids.is_empty():
		lines.append("• None selected yet")
	else:
		for power_id: String in power_ids:
			var info: Dictionary = power_system.relic_info(power_id)
			lines.append("• %s ×%d" % [
				info.get("name", power_id), RunState.relics.count(power_id),
			])
	return "\n".join(lines)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	return style


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
