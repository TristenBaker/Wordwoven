extends Window
## Independent debug viewer; never mutates the player's characters.

var canvas: Control
var content: Control
var zoom_label: Label
var portraits: Array[TextureRect] = []
var scar_stage := 0
var tint := 0
var gear_level := 1
var seed_value := 42
var zoom := 1.0
var dragging := false


func _ready() -> void:
	title = "Character matrix — 27 body / face combinations"
	size = Vector2i(1000, 620)
	min_size = Vector2i(480, 320)
	visible = false
	var root := VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toolbar := HFlowContainer.new()
	root.add_child(toolbar)
	_add_choice(toolbar, "Scars", ["0 · Bright", "1 · Watchful", "2 · Stern", "3 · Grim"], func(index: int):
		scar_stage = index
		_refresh())
	_add_choice(toolbar, "Tint", ["Original", "Warm", "Cool", "Green", "Violet", "Rose"], func(index: int):
		tint = index
		_refresh())
	_add_choice(toolbar, "Gear", ["Level 1", "Level 5", "Level 10", "Level 20"], func(index: int):
		gear_level = [1, 5, 10, 20][index]
		_refresh())
	var seed_label := Label.new()
	seed_label.text = "Scar seed"
	toolbar.add_child(seed_label)
	var seed_input := SpinBox.new()
	seed_input.max_value = 1000000
	seed_input.value = seed_value
	toolbar.add_child(seed_input)
	seed_input.value_changed.connect(func(value: float):
		seed_value = int(value)
		_refresh())
	var fit := Button.new()
	fit.text = "Fit all"
	fit.pressed.connect(fit_all)
	toolbar.add_child(fit)
	var actual := Button.new()
	actual.text = "100%"
	actual.pressed.connect(func(): _zoom_at(1.0, canvas.size * 0.5))
	toolbar.add_child(actual)
	zoom_label = Label.new()
	toolbar.add_child(zoom_label)
	var hint := Label.new()
	hint.text = "Drag to pan · Wheel to zoom at cursor · Drag window title to move · Resize window edges"
	root.add_child(hint)
	canvas = Control.new()
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
	root.add_child(canvas)
	canvas.gui_input.connect(_canvas_input)
	var background := ColorRect.new()
	background.color = Color("171b26")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = Vector2(2304, 936)
	canvas.add_child(content)
	for kind in 3:
		_label(CharacterFeatures.CLASS_NAMES[kind], Vector2(8, kind * 312), 24)
		for body in 3:
			for face in 3:
				var portrait := TextureRect.new()
				portrait.position = Vector2((body * 3 + face) * 256, kind * 312 + 32)
				portrait.size = Vector2(256, 256)
				portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
				content.add_child(portrait)
				portraits.append(portrait)
				var appearance := preload("res://scripts/ui/letter_appearance.gd").new()
				appearance.name = "Appearance"
				appearance.mouse_filter = Control.MOUSE_FILTER_IGNORE
				portrait.add_child(appearance)
				appearance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				_label("Body %d / Face %d" % [body + 1, face + 1], portrait.position + Vector2(8, 256), 16)
	_refresh()
	fit_all.call_deferred()
	focus_exited.connect(func(): dragging = false)


func _add_choice(parent: Control, caption: String, options: Array, callback: Callable) -> void:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	var choice := OptionButton.new()
	for option in options:
		choice.add_item(option)
	choice.item_selected.connect(callback)
	parent.add_child(choice)


func _label(text: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)


func _refresh() -> void:
	for index in portraits.size():
		var kind := index / 9
		var stats := LetterStats.create("")
		stats.element = [LetterStats.Element.FIRE, LetterStats.Element.WATER, LetterStats.Element.ICE][kind]
		stats.body_feature = (index % 9) / 3
		stats.face_feature = index % 3
		stats.appearance_seed = seed_value
		stats.accepted_uses = scar_stage * 5
		stats.level = gear_level
		var portrait := portraits[index]
		portrait.texture = CharacterFeatures.portrait(stats)
		portrait.self_modulate = [Color("ffffff"), Color("ffe2bd"), Color("d1e8ff"), Color("e0ffd4"), Color("f3d4ff"), Color("ffd6d6")][tint]
		var appearance = portrait.get_node("Appearance")
		appearance.stats = stats
		appearance.queue_redraw()


func fit_all() -> void:
	zoom = clampf(minf(canvas.size.x / content.size.x, canvas.size.y / content.size.y), 0.1, 8.0)
	content.scale = Vector2.ONE * zoom
	content.position = (canvas.size - content.size * zoom) * 0.5
	zoom_label.text = "%d%%" % roundi(zoom * 100)


func _zoom_at(value: float, cursor: Vector2) -> void:
	var point := (cursor - content.position) / zoom
	zoom = clampf(value, 0.1, 8.0)
	content.scale = Vector2.ONE * zoom
	content.position = cursor - point * zoom
	zoom_label.text = "%d%%" % roundi(zoom * 100)


func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), event.position)
		canvas.accept_event()
	elif event is InputEventMouseMotion and dragging:
		if event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE):
			content.position += event.relative
		else:
			dragging = false
		canvas.accept_event()
