extends Control
## Visual reward claim screen. Rewards were granted on victory; this scene
## celebrates and routes them into the player's backpack.

const BODY := preload("res://assets/Fonts/Junicode.ttf")
const COIN := preload("res://assets/Art/Events/coin.png")
const COIN_PILE := preload("res://assets/Art/Events/coin_pile.png")
const LETTER_TILE_SCENE := preload("res://scenes/combat/letter_tile.tscn")

var reward_stage: Control
var effects: Control
var reward_prompt: Label
var gold_reward: TextureRect
var tile_reward: LetterTile
var phase := 0
var busy := false


func _ready() -> void:
	if RunState.pending_victory_enemy.is_empty():
		get_tree().change_scene_to_file(ScenePaths.TAVERN)
		return
	$CenterBox.hide()
	_build_reward_stage()


func _build_reward_stage() -> void:
	effects = Control.new()
	effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.z_index = 30
	add_child(effects)
	reward_stage = Control.new()
	reward_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reward_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_stage.z_index = 20
	reward_stage.gui_input.connect(_on_reward_input)
	add_child(reward_stage)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_stage.add_child(center)
	var board := PanelContainer.new()
	board.custom_minimum_size = Vector2(660, 420)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_theme_stylebox_override("panel", _reward_board_style())
	center.add_child(board)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 14)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(content)
	content.add_child(_label("MONSTER DROPS", 42, Color("ffe08a")))
	content.add_child(_label("%s left behind:" % RunState.pending_victory_enemy, 22, Color("f6ead4")))
	var rewards := HBoxContainer.new()
	rewards.custom_minimum_size = Vector2(550, 176)
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override("separation", 54)
	rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rewards)
	var gold_slot := CenterContainer.new()
	gold_slot.custom_minimum_size = Vector2(220, 166)
	gold_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards.add_child(gold_slot)
	gold_reward = TextureRect.new()
	gold_reward.custom_minimum_size = Vector2(190, 150)
	gold_reward.texture = _cropped(COIN_PILE, Rect2(145, 245, 1000, 800))
	gold_reward.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_reward.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_slot.add_child(gold_reward)
	var gold_text := _label("%d GOLD" % RunState.pending_victory_gold, 23, Color.WHITE)
	gold_text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	gold_text.offset_top = -30
	gold_text.add_theme_color_override("font_outline_color", Color.BLACK)
	gold_text.add_theme_constant_override("outline_size", 5)
	gold_reward.add_child(gold_text)
	if RunState.pending_victory_letter != null:
		var tile_slot := CenterContainer.new()
		tile_slot.custom_minimum_size = Vector2(170, 166)
		tile_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rewards.add_child(tile_slot)
		tile_reward = LETTER_TILE_SCENE.instantiate() as LetterTile
		tile_reward.custom_minimum_size = Vector2(120, 150)
		tile_reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_slot.add_child(tile_reward)
		tile_reward.setup(RunState.pending_victory_letter)
	reward_prompt = _label("CLICK ANYWHERE TO CLAIM REWARDS", 20, Color.WHITE)
	reward_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	reward_prompt.position = Vector2(-210, -72)
	reward_prompt.size = Vector2(420, 32)
	reward_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	reward_prompt.add_theme_constant_override("outline_size", 5)
	reward_stage.add_child(reward_prompt)
func _on_reward_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed or busy:
		return
	if phase == 0:
		_claim_rewards()
	else:
		_finish_rewards()


func _claim_rewards() -> void:
	busy = true
	reward_prompt.hide()
	_scatter_coins(gold_reward)
	if tile_reward != null:
		await get_tree().create_timer(0.18).timeout
		_fly_tile_to_backpack(tile_reward)
	await get_tree().create_timer(0.65).timeout
	phase = 2
	busy = false
	reward_prompt.text = "CLICK ANYWHERE TO CONTINUE"
	reward_prompt.show()


func _scatter_coins(source: Control) -> void:
	var origin := source.get_global_rect().get_center()
	source.hide()
	var target := _effects_local(_backpack().get_global_rect().get_center() - Vector2(18, 18))
	for index: int in range(6):
		var coin := TextureRect.new()
		coin.texture = _cropped(COIN, Rect2(290, 310, 660, 660))
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size = Vector2(36, 36)
		coin.position = _effects_local(origin - coin.size * 0.5)
		coin.pivot_offset = coin.size * 0.5
		effects.add_child(coin)
		var angle := -2.75 + index * 0.55
		var burst := coin.position + Vector2(cos(angle), sin(angle)) * (54.0 + index * 8.0)
		var tween := create_tween()
		tween.tween_property(coin, "position", burst, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "position", target, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(coin, "scale", Vector2(0.4, 0.4), 0.52)
		tween.parallel().tween_property(coin, "modulate:a", 0.1, 0.52)
		tween.chain().tween_callback(coin.queue_free)


func _fly_tile_to_backpack(tile: LetterTile) -> void:
	var rect := tile.get_global_rect()
	tile.reparent(effects)
	tile.position = _effects_local(rect.position)
	tile.size = rect.size
	tile.pivot_offset = tile.size * 0.5
	var target := _effects_local(_backpack().get_global_rect().get_center() - tile.size * 0.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(tile, "position", target, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(tile, "scale", Vector2(0.3, 0.3), 0.58)
	tween.tween_property(tile, "modulate:a", 0.0, 0.58)
	tween.chain().tween_callback(tile.queue_free)


func _backpack() -> Control:
	return $EquipmentOverlay/EquipButton


func _effects_local(global_position: Vector2) -> Vector2:
	return global_position - effects.get_global_rect().position


func _cropped(source: Texture2D, region: Rect2) -> AtlasTexture:
	var cropped := AtlasTexture.new()
	cropped.atlas = source
	cropped.region = region
	return cropped


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _reward_board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a1a11")
	style.border_color = Color("9a6632")
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0, 0, 0, 0.58)
	style.shadow_size = 14
	style.content_margin_left = 34
	style.content_margin_top = 28
	style.content_margin_right = 34
	style.content_margin_bottom = 28
	return style


func _finish_rewards() -> void:
	var defeated_boss := RunState.is_boss_next()
	var visit_endless_shop := RunState.endless_shop_due()
	RunState.advance_encounter()
	RunState.clear_pending_victory()
	if defeated_boss:
		get_tree().change_scene_to_file(ScenePaths.RUN_WON)
	elif RunState.is_endless():
		get_tree().change_scene_to_file(
			ScenePaths.TAVERN if visit_endless_shop else ScenePaths.COMBAT
		)
	else:
		get_tree().change_scene_to_file(ScenePaths.TAVERN)
