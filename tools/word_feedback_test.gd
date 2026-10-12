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
		if biome == "tundra":
			check(is_equal_approx(banner.get_global_rect().position.x, combat.heat_meter.get_global_rect().position.x), "Banners align with heat column")
			check(banner.get_global_rect().position.y > combat.heat_meter.get_global_rect().end.y and banner.get_global_rect().position.y - combat.heat_meter.get_global_rect().end.y < 8, "Feedback directly below heat meter")
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
		var original_size: Vector2i = get_tree().root.size
		for resolution: Vector2i in AppSettings.RESOLUTIONS:
			get_tree().root.size = resolution
			await get_tree().process_frame
			await get_tree().process_frame
			var feedback_rect: Rect2 = banner.get_global_rect()
			var effectiveness_rect: Rect2 = indicator.get_global_rect()
			var cast_rect: Rect2 = combat.submit_button.get_global_rect()
			var hand_rect: Rect2 = combat.get_node("Layout/HandArea").get_global_rect()
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
		check(combat.feedback_label.visible and not combat.prompt_label.visible and not combat.feedback_label.text.is_empty(), "Validation message appears in banner")
		combat._set_player_feedback("")
		check(combat.prompt_label.visible and not combat.feedback_label.visible, "Prompt restored without duplicates")
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
	print("Word feedback: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
