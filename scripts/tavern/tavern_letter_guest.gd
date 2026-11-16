extends Node2D
## A cosmetic actor in panorama coordinates, independent of combat actions.
const WALK_SPEED := 82.0
const COLORS := [Color("ef735d"), Color("e4c34a"), Color("63b4ef"), Color("a3e9f7"), Color("79d37a"), Color("ca9264")]

var stats: LetterStats
var cosmetic: CharacterCosmetic
var floor_area: Rect2
var blocked: Callable
var sprite: AnimatedSprite2D
var info_button: LetterInfoButton
var _destination := Vector2.ZERO
var _rest := 0.8
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func setup(letter: LetterStats, area: Rect2) -> void:
	stats = letter
	floor_area = area
	cosmetic = PlayerProfile.combat_cosmetic_for(stats)
	sprite.sprite_frames = cosmetic.sprite_frames
	_play(&"idle")
	var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	var factor := 88.0 / frame.get_height() * cosmetic.render_scale
	sprite.scale = Vector2.ONE * factor
	sprite.position.y = -frame.get_height() * factor * 0.5
	var label := Label.new()
	label.name = "LetterName"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "%s · %s" % [stats.letter.to_upper(), stats.element_name_text()]
	label.position = Vector2(-90, -frame.get_height() * factor - 30)
	label.size = Vector2(180, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://assets/Fonts/Junicode-Bold.ttf"))
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", COLORS[stats.element])
	label.add_theme_color_override("font_outline_color", Color("100b08"))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	info_button = LetterInfoButton.new()
	info_button.name = "InspectLetter"
	info_button.position = Vector2(-76, -frame.get_height() * factor - 32)
	info_button.size = Vector2(152, frame.get_height() * factor + 42)
	info_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		info_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(info_button)
	info_button.set_letter_stats(stats)
	info_button.pressed.connect(_open_information)
	info_button.mouse_entered.connect(func(): sprite.self_modulate = Color(1.15, 1.15, 1.15))
	info_button.mouse_exited.connect(func(): sprite.self_modulate = Color.WHITE)
	_destination = position
	queue_redraw()


func _process(delta: float) -> void:
	if stats == null:
		return
	if get_tree().paused or info_button.button_pressed or (blocked.is_valid() and bool(blocked.call())):
		sprite.pause()
		return
	if not sprite.is_playing():
		sprite.play()
	if _rest > 0:
		_rest -= delta
		if _rest <= 0:
			_choose_destination()
		return
	var movement := _destination - position
	if absf(movement.x) > 1.0:
		sprite.flip_h = movement.x < 0
	position = position.move_toward(_destination, WALK_SPEED * delta)
	if position.distance_to(_destination) < 1:
		_rest = _random.randf_range(1.3, 3.2)
		_play(&"idle")


func _choose_destination() -> void:
	# Keep walks local and feet on the open floor, away from tables and the bar.
	var offset := Vector2(_random.randf_range(-340, 340), _random.randf_range(-55, 55))
	if absf(offset.x) < 100:
		offset.x = 100 if offset.x >= 0 else -100
	_destination = (position + offset).clamp(floor_area.position, floor_area.end - Vector2.ONE)
	_play(&"walk")


func _play(action: StringName) -> void:
	if cosmetic.has_action(action):
		sprite.play(cosmetic.animation_for(action))
	elif cosmetic.has_action(&"idle"):
		sprite.play(cosmetic.animation_for(&"idle"))
	else:
		var animations := cosmetic.sprite_frames.get_animation_names()
		if not animations.is_empty():
			sprite.play(animations[0])


func _open_information() -> void:
	if get_tree().paused or (blocked.is_valid() and bool(blocked.call())):
		return
	LetterInspector.open_for(stats)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, 25, Color(0, 0, 0, 0.3))
