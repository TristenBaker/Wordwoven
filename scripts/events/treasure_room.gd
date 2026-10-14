extends Control
const Balance = preload("res://data/balance/tuning.gd")
## A word opens the chest, then each visible reward must be claimed.

const BODY := preload("res://assets/Fonts/Junicode.ttf")
const CHEST_CLOSED: Texture2D = preload("res://assets/Art/Events/WW_chestclosed.png")
const CHEST_OPEN: Texture2D = preload("res://assets/Art/Events/WW_chestopen.png")
const BACKPACK: Texture2D = preload("res://assets/Art/Events/WW_backpack.png")
const COIN: Texture2D = preload("res://assets/Art/Events/coin.png")
const COIN_PILE: Texture2D = preload("res://assets/Art/Events/coin_pile.png")
const TREASURE_FLASH: Texture2D = preload("res://assets/Art/Events/treasure_flash.png")
const LETTER_TILE_SCENE := preload("res://scenes/combat/letter_tile.tscn")

var validator := WordValidator.new()
var input: LineEdit
var message: Label
var submit: Button
var chest_image: TextureRect
var loot_row: HBoxContainer
var room_panel: PanelContainer
var reward_stage: Control
var reward_prompt: Label
var gold_reward: TextureRect
var tile_reward: LetterTile
var items_hud: TextureRect
var effects: Control
var pending_gold := 0
var pending_item: LetterStats = null
var total_rewards := 0
var claimed_rewards := 0
var resolved := false
var reward_phase := 0
var reward_busy := false

func _ready() -> void:
	if not RunState.is_run_active or RunState.is_boss_next():
		get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)
		return
	add_child(validator)
	_build_ui()
	input.grab_focus()

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("100e1b")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	effects = Control.new()
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects.z_index = 30
	add_child(effects)
	items_hud = TextureRect.new()
	items_hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	items_hud.position = Vector2(-110, -110)
	items_hud.size = Vector2(80, 80)
	items_hud.texture = BACKPACK
	items_hud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	items_hud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	items_hud.tooltip_text = "Your backpack"
	add_child(items_hud)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	room_panel = PanelContainer.new()
	room_panel.custom_minimum_size = Vector2(640, 620)
	room_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(room_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	room_panel.add_child(box)
	box.add_child(_label("TREASURE ROOM", 40, Color("ffe08a")))
	box.add_child(_label("A sealed coffer waits in the quiet.", 21, Color("e6d8bc")))
	box.add_child(_build_chest())
	box.add_child(_label("The treasure felt ______.", 26, Color("fff4d4")))
	input = LineEdit.new()
	input.placeholder_text = "Enter an adjective"
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.custom_minimum_size = Vector2(390, 46)
	input.add_theme_font_override("font", BODY)
	input.add_theme_font_size_override("font_size", 23)
	input.text_submitted.connect(func(_text: String): _submit_word())
	box.add_child(input)
	message = _label("Choose a real adjective to open the coffer.", 18, Color("c9b99a"))
	box.add_child(message)
	submit = Button.new()
	submit.text = "OPEN THE COFFER"
	submit.custom_minimum_size = Vector2(300, 42)
	submit.pressed.connect(_submit_word)
	box.add_child(submit)
	loot_row = HBoxContainer.new()
	loot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	loot_row.add_theme_constant_override("separation", 14)
	loot_row.visible = false
	box.add_child(loot_row)

func _build_chest() -> Control:
	var chest := Control.new()
	chest.custom_minimum_size = Vector2(360, 220)
	chest_image = TextureRect.new()
	chest_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chest_image.texture = _chest_texture(CHEST_CLOSED)
	chest_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chest_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chest_image.pivot_offset = Vector2(180, 110)
	chest.add_child(chest_image)
	return chest

func _submit_word() -> void:
	if resolved:
		return
	if not WordNet.is_ready:
		message.text = "The lexicon is still opening."
		return
	var word := input.text.strip_edges().to_lower()
	var verdict: Dictionary = validator.validate(word, "a")
	if not verdict.valid:
		message.text = verdict.reason
		return
	resolved = true
	input.editable = false
	input.hide()
	submit.hide()
	var score := 0
	for character: String in word:
		score += int(LetterStats.BASE_POWER.get(character, 1))
	var tier := 0 if score < Balance.TREASURE_MID_SCORE else (1 if score < Balance.TREASURE_HIGH_SCORE else 2)
	pending_gold = Balance.TREASURE_GOLD[tier]
	total_rewards = 1
	if tier == 2 and RunState.use_itemized_letters:
		pending_item = RunState.rolled_letter_drop()
		total_rewards += 1
	message.text = "\"%s\" stirs the lock..." % word.capitalize()
	await _open_chest()
	await _play_reward_flash()
	message.text = "The chest opens. Claim your finds."
	await _show_loot()

func _open_chest() -> void:
	var close_tween := create_tween().set_parallel(true)
	close_tween.tween_property(chest_image, "scale", Vector2(1.08, 0.92), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	close_tween.tween_property(chest_image, "modulate", Color("ffe79d", 0.35), 0.18)
	await close_tween.finished
	chest_image.texture = _chest_texture(CHEST_OPEN)
	chest_image.scale = Vector2(0.9, 1.08)
	chest_image.modulate = Color("fff0ba")
	var open_tween := create_tween().set_parallel(true)
	open_tween.tween_property(chest_image, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(chest_image, "modulate", Color.WHITE, 0.34)
	await open_tween.finished

func _chest_texture(source: Texture2D) -> AtlasTexture:
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = Rect2(180, 180, 920, 820)
	return cropped

func _play_reward_flash() -> void:
	reward_stage = Control.new()
	reward_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_stage.z_index = 20
	reward_stage.gui_input.connect(_on_reward_stage_gui_input)
	add_child(reward_stage)
	var stage_center := CenterContainer.new()
	stage_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_stage.add_child(stage_center)
	var stage_content := VBoxContainer.new()
	stage_content.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_content.custom_minimum_size = Vector2(360, 190)
	stage_content.add_theme_constant_override("separation", 16)
	stage_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_center.add_child(stage_content)
	loot_row.reparent(stage_content)
	loot_row.custom_minimum_size = Vector2(360, 108)
	loot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_prompt = _label("CLICK ANYWHERE TO CLAIM", 20, Color.WHITE)
	reward_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	reward_prompt.position = Vector2(-180, -66)
	reward_prompt.size = Vector2(360, 32)
	reward_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	reward_prompt.add_theme_constant_override("outline_size", 5)
	reward_stage.add_child(reward_prompt)
	var flash := TextureRect.new()
	flash.texture = TREASURE_FLASH
	flash.z_index = -1
	flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flash.set_anchors_preset(Control.PRESET_CENTER)
	flash.position = Vector2(-190, -190)
	flash.size = Vector2(380, 380)
	flash.pivot_offset = Vector2(190, 190)
	flash.scale = Vector2(0.35, 0.35)
	flash.modulate = Color(1.0, 0.82, 0.74, 0.0)
	reward_stage.add_child(flash)
	var panel_fade := create_tween()
	panel_fade.tween_property(room_panel, "modulate:a", 0.18, 0.22)
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(flash, "scale", Vector2(1.08, 1.08), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(flash, "modulate:a", 0.8, 0.1)
	await reveal.finished
	var settle := create_tween()
	settle.tween_property(flash, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await settle.finished

func _show_loot() -> void:
	loot_row.show()
	gold_reward = TextureRect.new()
	gold_reward.custom_minimum_size = Vector2(154, 108)
	gold_reward.texture = _cropped_texture(COIN_PILE, Rect2(145, 245, 1000, 800))
	gold_reward.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_reward.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_row.add_child(gold_reward)
	var gold_label := _label("%d GOLD" % pending_gold, 21, Color.WHITE)
	gold_label.position = Vector2(0, 77)
	gold_label.size = Vector2(154, 26)
	gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_label.add_theme_color_override("font_outline_color", Color.BLACK)
	gold_label.add_theme_constant_override("outline_size", 5)
	gold_reward.add_child(gold_label)
	await _animate_reward_in(gold_reward)

func _animate_reward_in(reward: Control) -> void:
	reward.pivot_offset = reward.custom_minimum_size * 0.5
	reward.scale = Vector2(0.55, 0.55)
	reward.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(reward, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(reward, "modulate:a", 1.0, 0.18)
	await tween.finished

func _on_reward_stage_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed or reward_busy:
		return
	if reward_phase >= 2:
		_finish()
		return
	_claim_current_reward()

func _claim_current_reward() -> void:
	if reward_busy:
		return
	reward_busy = true
	reward_prompt.hide()
	if reward_phase == 0:
		_scatter_coins_to_backpack(gold_reward)
		RunState.add_gold(pending_gold)
		pending_gold = 0
		claimed_rewards += 1
		await get_tree().create_timer(0.62).timeout
		if pending_item != null:
			reward_phase = 1
			await _show_tile_reward()
			reward_busy = false
			reward_prompt.text = "CLICK ANYWHERE TO CLAIM"
			reward_prompt.show()
			return
		_finish_reward_claims()
		return
	if reward_phase == 1 and pending_item != null:
		var item: LetterStats = pending_item
		_fly_tile_to_items(tile_reward)
		RunState.add_letter_item(item)
		pending_item = null
		claimed_rewards += 1
		_finish_reward_claims()

func _show_tile_reward() -> void:
	tile_reward = LETTER_TILE_SCENE.instantiate() as LetterTile
	tile_reward.custom_minimum_size = Vector2(120, 132)
	tile_reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_row.add_child(tile_reward)
	tile_reward.setup(pending_item)
	await get_tree().process_frame
	var target_position := tile_reward.position
	tile_reward.position += Vector2(130, 0)
	tile_reward.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(tile_reward, "position", target_position, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile_reward, "modulate:a", 1.0, 0.2)
	await tween.finished

func _finish_reward_claims() -> void:
	reward_phase = 2
	reward_busy = false
	_check_claims()

func _fly_tile_to_items(tile: LetterTile) -> void:
	var source_rect := tile.get_global_rect()
	tile.reparent(effects)
	tile.position = _effects_local(source_rect.position)
	tile.size = source_rect.size
	tile.pivot_offset = tile.size * 0.5
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target := _effects_local(items_hud.get_global_rect().get_center() - tile.size * 0.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(tile, "position", target, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(tile, "scale", Vector2(0.42, 0.42), 0.58)
	tween.tween_property(tile, "modulate:a", 0.12, 0.58)
	tween.chain().tween_callback(tile.queue_free)

func _scatter_coins_to_backpack(source: Control) -> void:
	var source_center := source.get_global_rect().get_center()
	source.hide()
	var target := _effects_local(items_hud.get_global_rect().get_center() - Vector2(18, 18))
	for index: int in range(6):
		var coin := TextureRect.new()
		coin.texture = _cropped_texture(COIN, Rect2(290, 310, 660, 660))
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size = Vector2(36, 36)
		coin.position = _effects_local(source_center - coin.size * 0.5)
		coin.pivot_offset = coin.size * 0.5
		effects.add_child(coin)
		var angle := -2.75 + 0.55 * index
		var burst := coin.position + Vector2(cos(angle), sin(angle)) * (52.0 + index * 9.0)
		var tween := create_tween()
		tween.tween_property(coin, "position", burst, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "position", target, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(coin, "scale", Vector2(0.45, 0.45), 0.52)
		tween.parallel().tween_property(coin, "modulate:a", 0.15, 0.52)
		tween.chain().tween_callback(coin.queue_free)
	var cleanup := create_tween()
	cleanup.tween_interval(0.56)
	cleanup.tween_callback(source.queue_free)

func _cropped_texture(source: Texture2D, crop: Rect2) -> AtlasTexture:
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = crop
	return cropped

func _check_claims() -> void:
	if pending_gold <= 0 and pending_item == null:
		reward_prompt.text = "CLICK ANYWHERE TO RETURN TO TAVERN"
		reward_prompt.show()

func _effects_local(global_position: Vector2) -> Vector2:
	return global_position - effects.get_global_rect().position

func _finish() -> void:
	RunState.complete_treasure_room()
	RunState.advance_encounter()
	get_tree().change_scene_to_file(ScenePaths.TAVERN)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("292034")
	style.border_color = Color("c39a45")
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.shadow_color = Color("000000", 0.6)
	style.shadow_size = 16
	style.content_margin_left = 34.0
	style.content_margin_right = 34.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	return style
