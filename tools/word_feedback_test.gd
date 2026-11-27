extends Node
## Checks presentation against real calculator results without changing scoring.
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func _run() -> void:
	if not WordNet.is_ready:
		await WordNet.loading_finished
	for biome: String in ["", "tundra"]:
		RunState.start_new_run()
		RunState.selected_biome = biome
		RunState.encounter_index = 6
		RunState.next_enemy_id = "frost_wyrm" if biome == "tundra" else "dragon"
		var combat = load(ScenePaths.COMBAT).instantiate()
		add_child(combat)
		await get_tree().process_frame
		await get_tree().process_frame
		var banner: Control = combat.get_node("Layout/FeedbackBanner")
		var indicator = combat.effectiveness_indicator
		check(banner.get_global_rect().end.x < combat.submit_button.get_global_rect().position.x, "Banner clears Cast: " + biome)
		check(is_equal_approx(banner.get_global_rect().position.x, indicator.get_global_rect().position.x) and is_equal_approx(indicator.get_global_rect().end.x, combat.submit_button.get_global_rect().end.x), "Effectiveness spans word-entry through Cast: " + biome)
		check(indicator.get_global_rect().position.y > banner.get_global_rect().end.y and indicator.get_global_rect().position.y - banner.get_global_rect().end.y < 8, "Indicator directly below player feedback: " + biome)
		check(not indicator.get_global_rect().intersects(combat.get_node("Layout/HandArea").get_global_rect()), "Indicator clears hand: " + biome)
		check(not banner.get_global_rect().intersects(combat.submit_button.get_global_rect()) and not indicator.get_global_rect().intersects(combat.submit_button.get_global_rect()), "Both banners clear Cast: " + biome)
		var info_rect: Rect2 = combat.get_node("Layout/EnemyStatus/InfoFrame").get_global_rect()
		check(info_rect.position.x > combat.size.x * 0.5, "Enemy information in upper-right")
		var player_frame: PanelContainer = combat.get_node("Layout/StatusArea")
		var enemy_frame: PanelContainer = combat.get_node("Layout/EnemyStatus/InfoFrame")
		var player_heading: Label = player_frame.get_node("Content/HeadingSlot/PlayerHeading")
		var enemy_heading: Label = combat.enemy.name_label
		check(player_heading.text == "Player" and player_heading.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and player_heading.get_theme_font("font") == enemy_heading.get_theme_font("font") and player_heading.get_theme_font_size("font_size") == enemy_heading.get_theme_font_size("font_size"), "Player heading matches enemy heading")
		check(player_frame.size.x == 264.0 and player_frame.size.y <= 110.0, "Player panel retains its width and remains compact")
		check(combat.player_health_label.text == "%d / %d" % [RunState.player_health, RunState.player_max_health], "Health bar displays only its values")
		var player_style: StyleBoxFlat = player_frame.get_theme_stylebox("panel")
		var enemy_style: StyleBoxFlat = enemy_frame.get_theme_stylebox("panel")
		check(player_style.bg_color == enemy_style.bg_color and player_style.border_color == enemy_style.border_color and player_style.content_margin_top == enemy_style.content_margin_top, "Health panels share the same styling and padding")
		check(player_heading.get_global_rect().position.y - player_frame.get_global_rect().position.y >= 7.0 and enemy_heading.get_global_rect().position.y - info_rect.position.y >= 7.0, "Both headings clear the top borders")
		check(player_frame.get_global_rect().encloses(combat.player_health_bar.get_global_rect()) and info_rect.encloses(combat.enemy.health_bar.get_global_rect()), "Health bars fit inside their frames")
		if biome == "tundra":
			var heat_rect: Rect2 = combat.heat_meter.get_global_rect()
			check(is_equal_approx(heat_rect.end.x, info_rect.end.x) and heat_rect.size.x < info_rect.size.x, "Compact Heat meter aligns with enemy information")
			check(is_equal_approx(heat_rect.position.y, info_rect.end.y + 6.0), "Heat sits below enemy information")
		for panel: PanelContainer in [banner, indicator]:
			var style = panel.get_theme_stylebox("panel")
			check(style is StyleBoxFlat and style.bg_color.a > 0.0 and style.bg_color.a < 1.0 and style.bg_color.v < 0.1 and style.get_border_width(SIDE_LEFT) == 0 and style.get_border_width(SIDE_RIGHT) == 0 and style.get_border_width(SIDE_TOP) == 0 and style.get_border_width(SIDE_BOTTOM) == 0, "Plain dark translucent background without border")
		for label: Label in [combat.prompt_label, combat.feedback_label, indicator.label]:
			check(label.get_theme_font("font") == load("res://assets/Fonts/Junicode.ttf"), "Fantasy font")
		for pos: String in combat.PROMPT_ORDER:
			combat.required_pos = pos
			combat._refresh_prompt()
			await get_tree().process_frame
			await get_tree().process_frame
			check(indicator.get_global_rect().end.y < combat.get_node("Layout/HandArea").get_global_rect().position.y, "Prompt fits without overlap: " + pos)
		combat._set_player_feedback("Thaw needs 2 Heat. Each valid word gives +2.")
		await get_tree().process_frame
		await get_tree().process_frame
		check(banner.get_global_rect().encloses(combat.feedback_label.get_global_rect()) and banner.get_global_rect().end.y < combat.hand_box.get_global_rect().position.y, "Wrapped feedback stays inside its panel and clears the letter tiles")
		combat._set_player_feedback("")
		var original_size: Vector2i = get_tree().root.size
		for resolution: Vector2i in AppSettings.RESOLUTIONS:
			get_tree().root.size = resolution
			await get_tree().process_frame
			await get_tree().process_frame
			var feedback_rect: Rect2 = banner.get_global_rect()
			var effectiveness_rect: Rect2 = indicator.get_global_rect()
			var cast_rect: Rect2 = combat.submit_button.get_global_rect()
			var hand_rect: Rect2 = combat.get_node("Layout/HandArea").get_global_rect()
			var board_rect: Rect2 = combat.word_tile_board.get_global_rect()
			var quick_rect: Rect2 = combat.quick_cast_panel.get_global_rect()
			var log_rect: Rect2 = combat.side_panel.get_global_rect()
			var modifier_rect: Rect2 = combat.get_node("Layout/ActiveModifierPanel").get_global_rect()
			check(is_equal_approx(quick_rect.position.x, board_rect.position.x) and is_equal_approx(quick_rect.end.x, board_rect.end.x) and is_equal_approx(quick_rect.end.y + 6.0, board_rect.position.y), "Quick-cast follows the word field: " + str(resolution))
			check(log_rect.end.y < combat.log_toggle_button.get_global_rect().position.y and not log_rect.intersects(combat.hand_box.get_global_rect()) and not log_rect.intersects(board_rect) and not log_rect.intersects(modifier_rect) and not log_rect.intersects(player_frame.get_global_rect()), "Expanded log clears gameplay controls and player HUD: " + str(resolution))
			check(get_tree().root.size == resolution, "Resolution applied: " + str(resolution))
			check(is_equal_approx(feedback_rect.position.x, effectiveness_rect.position.x) and is_equal_approx(effectiveness_rect.end.x, cast_rect.end.x), "Resolution alignment: " + str(resolution))
			check(effectiveness_rect.position.y > feedback_rect.end.y and not feedback_rect.intersects(cast_rect) and not effectiveness_rect.intersects(cast_rect) and not feedback_rect.intersects(hand_rect) and not effectiveness_rect.intersects(hand_rect), "Resolution spacing without overlap: " + str(resolution))
		get_tree().root.size = original_size
		await get_tree().process_frame
		await get_tree().process_frame
		combat.required_pos = "a"
		combat._refresh_prompt()
		combat.enemy.tags.assign(["filthy"])
		var hp: int = RunState.player_health
		var enemy_hp: int = combat.enemy._health
		var hand: Array = combat.deck_manager.hand().duplicate()
		for word: String in ["clean", "dirty"]:
			combat.word_input.text = word
			combat._on_text_changed(word)
			var split: Dictionary = combat.deck_manager.split_word(word)
			var result: Dictionary = combat.calculator.calculate(word, split.drawn, split.undrawn, combat.enemy.tags, combat.required_pos, combat.enemy.affinities)
			check(indicator.tooltip_text.contains("Effectiveness %.2f" % result.effectiveness) and indicator.tooltip_text.contains("×%.2f" % result.semantic_multiplier), "Actual preview values: " + word)
			check(indicator.label.text == ("SUPER EFFECTIVE!" if word == "clean" else "THE WORD FINDS NO WEAKNESS"), "Actual preview message: " + word)
		check(RunState.player_health == hp and combat.enemy._health == enemy_hp and combat.deck_manager.hand() == hand and RunState.word_history.is_empty() and combat.validator._played_words.is_empty() and combat.cold.turns == 0, "Preview has no gameplay side effects")
		combat.word_input.text = ""
		combat._on_text_changed("")
		check(indicator.label.text.is_empty() and indicator.modulate.a == 0.0, "Empty input clears preview")
		combat.word_input.text = "zzzzzz"
		combat._on_submit()
		check(combat.feedback_label.visible and combat.prompt_label.visible and not combat.feedback_label.text.is_empty(), "Validation message keeps the prompt visible")
		await get_tree().create_timer(3.15).timeout
		check(combat.prompt_label.visible and not combat.feedback_label.visible and combat.feedback_label.text.is_empty(), "Validation error expires automatically")
		var synthetic: Dictionary = {"counter": {"strategy": "counter synonym", "score": 0.9, "tag": "filthy"}, "effectiveness": 0.9, "semantic_multiplier": 1.85}
		indicator.show_preview(synthetic)
		check(indicator.label.text == "EFFECTIVE!", "Original effective threshold")
		synthetic.semantic_multiplier = 2.0
		indicator.show_preview(synthetic)
		check(indicator.label.text == "SUPER EFFECTIVE!", "Original super-effective threshold")
		synthetic.semantic_multiplier = 1.0
		indicator.show_preview(synthetic)
		check(indicator.label.text == "THE WORD FINDS NO WEAKNESS", "Original advantage threshold")
		# The real cast result must outlive input clearing, then expire smoothly.
		combat.word_input.text = "clean"
		combat._on_submit()
		check(indicator.label.text == "SUPER EFFECTIVE!" and indicator._showing_result, "Cast shows real effectiveness after input resets")
		await get_tree().create_timer(1.6).timeout
		check(indicator.modulate.a > 0.0 and indicator.modulate.a < 1.0, "Result fades smoothly")
		await get_tree().create_timer(0.25).timeout
		check(indicator.label.text.is_empty() and indicator.modulate.a == 0.0, "Result clears after about 1.8 seconds")
		# A new preview must cancel an old result's delayed fade.
		var deadline: int = Time.get_ticks_msec() + 5000
		while combat._state != combat.State.PLAYER_INPUT and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		indicator.show_result(synthetic)
		combat.required_pos = "a"
		combat.word_input.text = "dirty"
		combat._on_text_changed("dirty")
		await get_tree().create_timer(1.9).timeout
		check(indicator.modulate.a == 1.0 and not indicator._showing_result, "New typing replaces result without stale fade")
		for audio: AudioStreamPlayer in combat.find_children("*", "AudioStreamPlayer", true, false):
			audio.stop()
			audio.stream = null
		combat.queue_free()
		await get_tree().process_frame
	RunState.start_new_run(RunState.RunMode.ENDLESS)
	var endless = load(ScenePaths.COMBAT).instantiate()
	add_child(endless)
	await get_tree().process_frame
	await get_tree().process_frame
	check(endless.get_node("Layout/StatusArea/Content/HeadingSlot/PlayerHeading").text == "Player", "Endless uses the same Player heading")
	var route: Rect2 = endless.endless_route.get_global_rect()
	check(endless.endless_route.visible and route.end.x < endless.enemy.info_box.get_global_rect().position.x, "Endless route clears upper-right enemy information")
	for count: int in [1, 4, 8, 12]:
		var letters: Array[LetterStats] = []
		for index in count:
			letters.append(LetterStats.create(char(97 + index)))
		endless.party_stage.sync_letters(letters)
		var left: float = endless.party_stage._slot_x(0)
		var right: float = endless.party_stage._slot_x(count - 1)
		check(is_equal_approx((left + right) * 0.5, endless.size.x * 0.25), "Party formation centers %d letters" % count)
	endless.queue_free()
	await get_tree().process_frame
	print("Word feedback: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
