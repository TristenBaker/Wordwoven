extends Node
var failures := 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func _ready():
	DebugTools._toggle_character_matrix(true)
	await get_tree().process_frame
	var matrix = DebugTools._character_matrix
	check(matrix.visible and matrix.portraits.size() == 27, "Toggle opens all 27 combinations")
	var seen = {}
	for portrait in matrix.portraits:
		var stats = portrait.get_node("Appearance").stats
		seen[Vector3i(CharacterFeatures.archetype(stats.element), stats.body_feature, stats.face_feature)] = true
	check(seen.size() == 27, "Every class/body/face combination appears once")
	var cursor = Vector2(240, 180)
	var before = (cursor - matrix.content.position) / matrix.zoom
	matrix._zoom_at(2.0, cursor)
	check(before.is_equal_approx((cursor - matrix.content.position) / matrix.zoom), "Zoom keeps the cursor on the same character")
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	matrix._canvas_input(press)
	var motion = InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = Vector2(30, 20)
	var old_position = matrix.content.position
	matrix._canvas_input(motion)
	check(matrix.content.position == old_position + motion.relative, "Mouse drag pans the matrix")
	matrix.scar_stage = 3
	matrix._refresh()
	check(matrix.portraits[26].get_node("Appearance").stats.scar_count() == 3, "Scar control updates the whole matrix")
	matrix.scar_stage = 0
	matrix._refresh()
	matrix.fit_all()
	DebugTools._toggle_character_matrix(false)
	check(not matrix.visible, "Toggle hides the matrix")
	DebugTools._toggle_character_matrix(true)
	check(DebugTools._character_matrix == matrix, "Reopening reuses the window")
	if "--export" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		matrix.get_texture().get_image().save_png("res://.godot/character_matrix_preview.png")
	matrix.close_requested.emit()
	check(not matrix.visible and not DebugTools._matrix_toggle.button_pressed, "Window close resets debug toggle")
	print("Character matrix tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
