extends Control
## All nine faces, each at zero through three scars. Run with -- --export.

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 2304)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(1024, 2304)
	background.color = Color("171b26")
	viewport.add_child(background)
	for kind in 3:
		for face in 3:
			for stage in 4:
				var stats := LetterStats.create("a")
				stats.element = [LetterStats.Element.FIRE, LetterStats.Element.WATER, LetterStats.Element.ICE][kind]
				stats.appearance_seed = 42 + kind * 7 + face * 3
				stats.body_feature = face
				stats.face_feature = face
				stats.accepted_uses = stage * 5
				var portrait := TextureRect.new()
				portrait.position = Vector2(stage * 256, (kind * 3 + face) * 256)
				portrait.size = Vector2(232, 232)
				portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				portrait.texture = CharacterFeatures.portrait(stats)
				portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				viewport.add_child(portrait)
				var appearance := preload("res://scripts/ui/letter_appearance.gd").new()
				appearance.stats = stats
				appearance.history_only = true
				portrait.add_child(appearance)
				appearance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				var caption := Label.new()
				caption.position = portrait.position + Vector2(8, 230)
				caption.text = "%s · %d · %s" % [CharacterFeatures.CLASS_NAMES[kind], stage, CharacterScars.EXPRESSION_NAMES[stage]]
				caption.add_theme_font_size_override("font_size", 16)
				viewport.add_child(caption)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var view := TextureRect.new()
	view.texture = viewport.get_texture()
	scroll.add_child(view)
	if "--export" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://.godot/scar_preview.png")
		get_tree().quit()
