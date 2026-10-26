extends Control
## Timed letter tracing. A tolerant stencil evaluates coverage, neatness, and pace.

const BODY := preload("res://assets/Fonts/Junicode.ttf")
const WORDS: Array[String] = ["rune", "fire", "ink", "word"]

class TraceBoard extends Control:
	signal letter_scored(coverage: float, neatness: float, pace: float)

	const TIME_LIMIT := 10.0
	const TOLERANCE := 0.075
	var target_letter := ""
	var target_strokes: Array = []
	var drawn_points: PackedVector2Array = PackedVector2Array()
	var drawing := false
	var elapsed := 0.0
	var active := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(true)
		gui_input.connect(_on_gui_input)

	func begin(letter: String) -> void:
		preview(letter)
		drawn_points = PackedVector2Array()
		elapsed = 0.0
		drawing = false
		active = true
		queue_redraw()

	func preview(letter: String) -> void:
		target_letter = letter.to_upper()
		target_strokes = _strokes_for(target_letter)
		drawn_points = PackedVector2Array()
		elapsed = 0.0
		drawing = false
		active = false
		queue_redraw()

	func _process(delta: float) -> void:
		if not active:
			return
		elapsed += delta
		queue_redraw()
		if elapsed >= TIME_LIMIT:
			finish()

	func finish() -> void:
		if not active:
			return
		active = false
		drawing = false
		var coverage := _coverage()
		var neatness := _neatness()
		var pace := clampf(1.0 - elapsed / TIME_LIMIT, 0.0, 1.0)
		queue_redraw()
		letter_scored.emit(coverage, neatness, pace)

	func _on_gui_input(event: InputEvent) -> void:
		if not active:
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			drawing = event.pressed
			if drawing:
				_add_point(event.position)
		elif event is InputEventMouseMotion and drawing:
			_add_point(event.position)

	func _add_point(position: Vector2) -> void:
		var normalized := _to_normalized(position)
		if normalized.x < 0.0 or normalized.x > 1.0 or normalized.y < 0.0 or normalized.y > 1.0:
			return
		if drawn_points.is_empty() or drawn_points[-1].distance_to(normalized) > 0.008:
			drawn_points.append(normalized)
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("121a24"), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color("75b5c7"), false, 3.0)
		var glyph := _glyph_rect()
		for stroke: PackedVector2Array in target_strokes:
			for index: int in range(stroke.size() - 1):
				var start := _to_screen(stroke[index], glyph)
				var end := _to_screen(stroke[index + 1], glyph)
				draw_line(start, end, Color("537784", 0.45), 3.0, true)
				for dot_index: int in range(9):
					var dot := start.lerp(end, float(dot_index) / 8.0)
					draw_circle(dot, 4.5, Color("b9d7dc", 0.72))
		for index: int in range(drawn_points.size() - 1):
			draw_line(_to_screen(drawn_points[index], glyph), _to_screen(drawn_points[index + 1], glyph), Color("f7cf72"), 10.0, true)
		if active:
			var remaining := maxf(0.0, TIME_LIMIT - elapsed)
			draw_string(BODY, Vector2(18, 30), "%0.1fs" % remaining, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f6ead4"))

	func _glyph_rect() -> Rect2:
		return Rect2(150, 32, maxf(1.0, size.x - 300.0), maxf(1.0, size.y - 64.0))

	func _to_normalized(position: Vector2) -> Vector2:
		var glyph := _glyph_rect()
		return (position - glyph.position) / glyph.size

	func _to_screen(point: Vector2, glyph: Rect2) -> Vector2:
		return glyph.position + point * glyph.size

	func _coverage() -> float:
		if drawn_points.is_empty():
			return 0.0
		var total := 0
		var hits := 0
		for stroke: PackedVector2Array in target_strokes:
			for index: int in range(stroke.size() - 1):
				for sample: int in range(13):
					total += 1
					var point := stroke[index].lerp(stroke[index + 1], float(sample) / 12.0)
					if _closest_distance(point) <= TOLERANCE:
						hits += 1
		return float(hits) / maxf(1.0, float(total))

	func _neatness() -> float:
		if drawn_points.is_empty():
			return 0.0
		var good := 0
		for point: Vector2 in drawn_points:
			if _closest_distance(point) <= TOLERANCE:
				good += 1
		return float(good) / float(drawn_points.size())

	func _closest_distance(point: Vector2) -> float:
		var nearest := INF
		for stroke: PackedVector2Array in target_strokes:
			for index: int in range(stroke.size() - 1):
				nearest = minf(nearest, _point_segment_distance(point, stroke[index], stroke[index + 1]))
		return nearest

	func _point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
		var line := end - start
		var ratio := clampf((point - start).dot(line) / maxf(line.length_squared(), 0.0001), 0.0, 1.0)
		return point.distance_to(start + line * ratio)

	func _strokes_for(letter: String) -> Array:
		var s := func(points: Array) -> PackedVector2Array:
			var stroke := PackedVector2Array()
			for point: Vector2 in points:
				stroke.append(point)
			return stroke
		match letter:
			"I": return [s.call([Vector2(.25,.15), Vector2(.75,.15)]), s.call([Vector2(.5,.15), Vector2(.5,.85)]), s.call([Vector2(.25,.85), Vector2(.75,.85)])]
			"N": return [s.call([Vector2(.2,.85), Vector2(.2,.15)]), s.call([Vector2(.2,.15), Vector2(.8,.85)]), s.call([Vector2(.8,.85), Vector2(.8,.15)])]
			"K": return [s.call([Vector2(.22,.15), Vector2(.22,.85)]), s.call([Vector2(.22,.52), Vector2(.8,.15)]), s.call([Vector2(.22,.52), Vector2(.8,.85)])]
			"R": return [s.call([Vector2(.22,.85), Vector2(.22,.15), Vector2(.64,.15), Vector2(.78,.3), Vector2(.64,.5), Vector2(.22,.5)]), s.call([Vector2(.5,.5), Vector2(.8,.85)])]
			"U": return [s.call([Vector2(.22,.15), Vector2(.22,.72), Vector2(.36,.85), Vector2(.64,.85), Vector2(.78,.72), Vector2(.78,.15)])]
			"E": return [s.call([Vector2(.75,.15), Vector2(.22,.15), Vector2(.22,.85), Vector2(.75,.85)]), s.call([Vector2(.22,.5), Vector2(.63,.5)])]
			"F": return [s.call([Vector2(.22,.85), Vector2(.22,.15), Vector2(.78,.15)]), s.call([Vector2(.22,.5), Vector2(.65,.5)])]
			"W": return [s.call([Vector2(.15,.15), Vector2(.3,.85), Vector2(.5,.48), Vector2(.7,.85), Vector2(.85,.15)])]
			"O": return [s.call([Vector2(.35,.15), Vector2(.65,.15), Vector2(.8,.3), Vector2(.8,.7), Vector2(.65,.85), Vector2(.35,.85), Vector2(.2,.7), Vector2(.2,.3), Vector2(.35,.15)])]
			"D": return [s.call([Vector2(.22,.15), Vector2(.22,.85), Vector2(.58,.85), Vector2(.8,.68), Vector2(.8,.32), Vector2(.58,.15), Vector2(.22,.15)])]
			_: return [s.call([Vector2(.2,.15), Vector2(.8,.85)])]

var word := ""
var letter_index := 0
var total_score := 0
var board: TraceBoard
var prompt: Label
var result: Label
var advance: Button
var intro_phase := 0
var round_active := false

func _ready() -> void:
	word = WORDS.pick_random().to_upper()
	_build_ui()
	_show_first_instruction()

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101823")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 620)
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_label("LETTER TRACING", 38, Color("a9e7f5")))
	prompt = _label("", 24, Color("f6ead4"))
	box.add_child(prompt)
	result = _label("Trace the pale stencil with your mouse.", 19, Color("b8cbd0"))
	box.add_child(result)
	board = TraceBoard.new()
	board.custom_minimum_size = Vector2(650, 300)
	board.hide()
	board.letter_scored.connect(_on_letter_scored)
	box.add_child(board)
	advance = Button.new()
	advance.text = "CONTINUE"
	advance.custom_minimum_size = Vector2(230, 42)
	advance.pressed.connect(_on_advance_pressed)
	box.add_child(advance)
	var back := Button.new()
	back.text = "Return to Tavern"
	back.pressed.connect(func(): get_tree().change_scene_to_file(ScenePaths.TAVERN))
	box.add_child(back)

func _show_first_instruction() -> void:
	prompt.text = "Trace the letters quickly!"
	result.text = "A word will appear one letter at a time. Follow its guide with your mouse."
	advance.text = "CONTINUE"

func _on_advance_pressed() -> void:
	if round_active:
		board.finish()
		return
	if intro_phase == 0:
		intro_phase = 1
		prompt.text = "You will draw the word: %s" % word
		result.text = "Take a moment to read it. The first letter is shown after you continue."
		advance.text = "BEGIN"
		return
	if intro_phase == 1:
		_start_countdown()

func _start_countdown() -> void:
	intro_phase = 2
	advance.disabled = true
	board.show()
	board.preview(word[letter_index])
	for count: int in [3, 2, 1]:
		prompt.text = "Get ready... %d" % count
		result.text = "The guide is ready. Drawing unlocks at one."
		await get_tree().create_timer(0.85).timeout
	prompt.text = "Trace %s  —  letter %d of %d" % [word[letter_index], letter_index + 1, word.length()]
	result.text = "Trace the guide, then finish when you are ready."
	round_active = true
	advance.disabled = false
	advance.text = "FINISH LETTER"
	board.begin(word[letter_index])

func _start_letter() -> void:
	prompt.text = "Trace %s  —  letter %d of %d" % [word[letter_index], letter_index + 1, word.length()]
	result.text = "Coverage, neatness, and speed all count."
	round_active = true
	advance.disabled = false
	advance.text = "FINISH LETTER"
	board.begin(word[letter_index])

func _on_letter_scored(coverage: float, neatness: float, pace: float) -> void:
	round_active = false
	var score := roundi((coverage * 0.55 + neatness * 0.3 + pace * 0.15) * 100.0)
	total_score += score
	result.text = "%d%%  •  coverage %d%%  •  neatness %d%%" % [score, roundi(coverage * 100), roundi(neatness * 100)]
	advance.disabled = true
	letter_index += 1
	if letter_index >= word.length():
		prompt.text = "%s complete — average score %d%%" % [word, roundi(float(total_score) / word.length())]
		result.text += "  The ink settles."
		advance.hide()
		return
	await get_tree().create_timer(1.1).timeout
	_start_letter()

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
	style.bg_color = Color("192532")
	style.border_color = Color("5c9ead")
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	return style
