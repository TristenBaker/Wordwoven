extends Button
## Uses the same opaque card and transparent outer shell as letter tooltips.
var detail_text := ""

func _make_custom_tooltip(_for_text: String) -> Object:
	var panel := PanelContainer.new()
	var card := LetterTooltip.new()
	panel.add_theme_stylebox_override("panel", card._panel_style())
	card.free()
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(330, 0)
	text.text = detail_text
	panel.add_child(text)
	return panel
