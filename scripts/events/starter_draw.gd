extends Control
## A short visual onboarding beat: reveal the starter tiles before the tale begins.

const BODY := preload("res://assets/Fonts/Junicode.ttf")
const BACKPACK := preload("res://assets/Art/Events/WW_backpack.png")
const LETTER_TILE_SCENE := preload("res://scenes/combat/letter_tile.tscn")

var reveal_bag: TextureButton
var items_hud: TextureRect
var tile_row: HBoxContainer
var prompt: Label
var effects: Control
var tiles: Array[LetterTile] = []
var phase := 0
var busy := false


func _ready() -> void:
	if not RunState.is_run_active:
		get_tree().change_scene_to_file(ScenePaths.BIOME_SELECT)
		return
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("171025")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	effects = Control.new()
	effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.z_index = 20
	add_child(effects)
	items_hud = TextureRect.new()
	items_hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	items_hud.position = Vector2(-110, -110)
	items_hud.size = Vector2(80, 80)
	items_hud.texture = BACKPACK
	items_hud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	items_hud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	items_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(items_hud)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(980, 480)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	box.add_child(_label("A BAG OF LETTERS", 44, Color("ffe08a")))
	box.add_child(_label("You come across a bag of letters.", 24, Color("f5e7cd")))
	reveal_bag = TextureButton.new()
	reveal_bag.custom_minimum_size = Vector2(180, 180)
	reveal_bag.ignore_texture_size = true
	reveal_bag.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	reveal_bag.texture_normal = BACKPACK
	reveal_bag.tooltip_text = "Open the bag"
	reveal_bag.pressed.connect(_open_bag)
	box.add_child(reveal_bag)
	tile_row = HBoxContainer.new()
	tile_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tile_row.add_theme_constant_override("separation", 8)
	box.add_child(tile_row)
	prompt = _label("CLICK THE BAG TO DRAW YOUR LETTERS", 20, Color("fff4d6"))
	box.add_child(prompt)
	gui_input.connect(_on_gui_input)


func _open_bag() -> void:
	if phase != 0 or busy:
		return
	busy = true
	reveal_bag.hide()
	prompt.text = "YOUR FIRST LETTERS"
	for item: LetterStats in RunState.combat_letters():
		var tile := LETTER_TILE_SCENE.instantiate() as LetterTile
		tile.custom_minimum_size = Vector2(82, 108)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile_row.add_child(tile)
		tile.setup(item)
		tile.pivot_offset = tile.custom_minimum_size * 0.5
		tile.scale = Vector2(0.25, 0.25)
		tile.modulate = Color(1, 1, 1, 0)
		tiles.append(tile)
		var appear := create_tween().set_parallel(true)
		appear.tween_property(tile, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		appear.tween_property(tile, "modulate:a", 1.0, 0.18)
		await get_tree().create_timer(0.055).timeout
	await get_tree().create_timer(0.3).timeout
	RunState.mark_inventory_items_unseen()
	phase = 1
	busy = false
	prompt.text = "CLICK ANYWHERE TO PACK THEM INTO YOUR BAG"


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed or busy:
		return
	if phase == 1:
		_pack_tiles()
	elif phase == 2:
		get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)


func _pack_tiles() -> void:
	busy = true
	prompt.hide()
	for index: int in tiles.size():
		var tile := tiles[index]
		var rect := tile.get_global_rect()
		tile.reparent(effects)
		tile.position = _effects_local(rect.position)
		tile.size = rect.size
		tile.pivot_offset = tile.size * 0.5
		var target := _effects_local(items_hud.get_global_rect().get_center() - tile.size * 0.5)
		var tween := create_tween()
		tween.tween_interval(float(index) * 0.035)
		tween.set_parallel(true)
		tween.tween_property(tile, "position", target, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(tile, "scale", Vector2(0.28, 0.28), 0.48)
		tween.tween_property(tile, "modulate:a", 0.0, 0.48)
		tween.chain().tween_callback(tile.queue_free)
	await get_tree().create_timer(0.72).timeout
	phase = 2
	busy = false
	prompt.text = "CLICK ANYWHERE TO BEGIN YOUR TALE"
	prompt.show()


func _effects_local(global_position: Vector2) -> Vector2:
	return global_position - effects.get_global_rect().position


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", BODY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
