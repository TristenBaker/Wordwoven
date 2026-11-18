extends Control
## Run this scene to browse all body/face pairings. -- --export writes a contact sheet.

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("171b26")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var sheet := Image.create(9 * 256, 3 * 256, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("171b26"))
	for kind in 3:
		var title := Label.new()
		title.text = CharacterFeatures.CLASS_NAMES[kind] + " — bodies across, faces within each group"
		title.add_theme_font_size_override("font_size", 26)
		column.add_child(title)
		var row := HBoxContainer.new()
		column.add_child(row)
		for body in 3:
			for face in 3:
				var texture := CharacterFeatures.combination(kind, body, face)
				var preview := TextureRect.new()
				preview.custom_minimum_size = Vector2(132, 132)
				preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				preview.texture = texture
				preview.tooltip_text = "%s / %s" % [CharacterFeatures.BODY_NAMES[kind][body], CharacterFeatures.FACE_NAMES[kind][face]]
				row.add_child(preview)
				sheet.blend_rect(texture.get_image(), Rect2i(0, 0, 256, 256), Vector2i((body * 3 + face) * 256, kind * 256))
	if "--export" in OS.get_cmdline_user_args():
		sheet.save_png("res://art/party/features/combinations_preview.png")
		get_tree().quit()
