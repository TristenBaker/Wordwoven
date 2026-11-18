extends Control
## Context check against the actual tundra backdrop and Glacier Bear sprite.

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := TextureRect.new()
	background.texture = load("res://art/backgrounds/Tundra Biome/T1.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.size = Vector2(1280, 720)
	viewport.add_child(background)
	for kind in 3:
		var stats := LetterStats.create("a")
		stats.element = [LetterStats.Element.FIRE, LetterStats.Element.WATER, LetterStats.Element.ICE][kind]
		stats.appearance_seed = 42
		stats.body_feature = kind
		stats.face_feature = kind
		stats.accepted_uses = 10
		var portrait := TextureRect.new()
		portrait.texture = CharacterFeatures.portrait(stats)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.size = Vector2(256, 256)
		portrait.position = Vector2(60 + kind * 225, 365)
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		viewport.add_child(portrait)
		var appearance := preload("res://scripts/ui/letter_appearance.gd").new()
		appearance.stats = stats
		portrait.add_child(appearance)
		appearance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bear_sheet: Texture2D = load("res://assets/Art/Enemies/Tundra Monsters/Bear/Glacier Bear Idle.png")
	var bear_frame := AtlasTexture.new()
	bear_frame.atlas = bear_sheet
	bear_frame.region = Rect2(0, 0, bear_sheet.get_width() / 4.0, bear_sheet.get_height())
	var bear := TextureRect.new()
	bear.texture = bear_frame
	bear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bear.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bear.size = Vector2(440, 440)
	bear.position = Vector2(800, 245)
	bear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(bear)
	var preview := TextureRect.new()
	preview.texture = viewport.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(preview)
	if "--export" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://art/party/features/style_context_preview.png")
		get_tree().quit()
