extends CanvasLayer
## Developer overlay, toggled with F12. Shows the full damage
## breakdown for the last word played, offers a live similarity
## tester, and carries cheats: gold, healing, skipping to the
## tavern, and forcing enemy tags or drawn letters.

signal auto_kill_requested
signal hangman_reset_requested(tier_override: int)

# Set from the overlay; EnemyFactory applies them at the next spawn.
var forced_tags: Array[String] = []

# Set from the overlay; DeckManager deals these at the next refill.
var forced_letters: String = ""
var free_map_select: bool = false
var _profile_letters: Array[LetterStats] = []
var _character_matrix: Window
var _matrix_toggle: CheckButton

@onready var profile_select: OptionButton = $Panel/Scroll/Box/ProfileRow/LetterSelect
@onready var profile_one_button: Button = $Panel/Scroll/Box/ProfileRow/OneUse
@onready var profile_five_button: Button = $Panel/Scroll/Box/ProfileRow/FiveUses

@onready var panel: PanelContainer = $Panel
@onready var breakdown_label: RichTextLabel = \
		$Panel/Scroll/Box/BreakdownLabel
@onready var sim_word_input: LineEdit = \
		$Panel/Scroll/Box/SimRow/SimWordInput
@onready var sim_tag_input: LineEdit = \
		$Panel/Scroll/Box/SimRow/SimTagInput
@onready var sim_result_label: Label = \
		$Panel/Scroll/Box/SimResultLabel
@onready var score_button: Button = $Panel/Scroll/Box/SimRow/ScoreButton
@onready var gold_button: Button = $Panel/Scroll/Box/CheatRow/GoldButton
@onready var heal_button: Button = $Panel/Scroll/Box/CheatRow/HealButton
@onready var tavern_button: Button = \
		$Panel/Scroll/Box/CheatRow/TavernButton
@onready var auto_kill_button: Button = $Panel/Scroll/Box/EncounterRow/AutoKillButton
@onready var free_map_button: Button = $Panel/Scroll/Box/EncounterRow/FreeMapButton
@onready var playtest_run_button: Button = $Panel/Scroll/Box/PlaytestRunButton
@onready var hangman_tier_select: OptionButton = $Panel/Scroll/Box/HangmanRow/TierSelect
@onready var hangman_reset_button: Button = $Panel/Scroll/Box/HangmanRow/ResetButton
@onready var tags_input: LineEdit = $Panel/Scroll/Box/ForceRow/TagsInput
@onready var letters_input: LineEdit = \
		$Panel/Scroll/Box/ForceRow/LettersInput


func _ready() -> void:
	panel.hide()
	_matrix_toggle = CheckButton.new()
	_matrix_toggle.text = "Character matrix"
	$Panel/Scroll/Box.add_child(_matrix_toggle)
	$Panel/Scroll/Box.move_child(_matrix_toggle, $Panel/Scroll/Box/FeatureRow.get_index() + 1)
	_matrix_toggle.toggled.connect(_toggle_character_matrix)
	get_viewport().size_changed.connect(_fit_panel_to_viewport)
	_fit_panel_to_viewport()
	profile_one_button.pressed.connect(_simulate_profile_uses.bind(1))
	profile_five_button.pressed.connect(_simulate_profile_uses.bind(5))
	$Panel/Scroll/Box/FeatureRow/BodyButton.pressed.connect(_cycle_profile_feature.bind(true))
	$Panel/Scroll/Box/FeatureRow/FaceButton.pressed.connect(_cycle_profile_feature.bind(false))
	score_button.pressed.connect(_on_score_pressed)
	gold_button.pressed.connect(_on_gold_pressed)
	heal_button.pressed.connect(_on_heal_pressed)
	tavern_button.pressed.connect(_on_tavern_pressed)
	auto_kill_button.pressed.connect(_on_auto_kill_pressed)
	free_map_button.pressed.connect(_on_free_map_pressed)
	playtest_run_button.pressed.connect(_on_playtest_run_pressed)
	hangman_reset_button.pressed.connect(_on_hangman_reset_pressed)
	RunState.run_started.connect(func(): free_map_select = false)
	tags_input.text_changed.connect(_on_tags_changed)
	letters_input.text_changed.connect(_on_letters_changed)
	EventBus.word_resolved.connect(_on_word_resolved)


func _toggle_character_matrix(open: bool) -> void:
	if not is_instance_valid(_character_matrix):
		if not open:
			return
		_character_matrix = preload("res://scripts/debug/character_matrix.gd").new()
		add_child(_character_matrix)
		_character_matrix.close_requested.connect(func():
			_character_matrix.hide()
			_matrix_toggle.set_pressed_no_signal(false))
	if open:
		_character_matrix.popup_centered(Vector2i(1000, 620).min(Vector2i(get_viewport().get_visible_rect().size) - Vector2i(40, 60)))
	else:
		_character_matrix.hide()


func _fit_panel_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(412.0, maxf(0.0, viewport_size.x - 16.0)),
		minf(672.0, maxf(0.0, viewport_size.y - 16.0)))
	panel.position = Vector2(viewport_size.x - panel.size.x - 8.0, 8.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay_toggle"):
		panel.visible = not panel.visible
		if panel.visible:
			_refresh_encounter_buttons()
		EventBus.emit_debug_toggled(panel.visible)


# --- Breakdown display ---------------------------------------------

func _on_word_resolved(result: Dictionary) -> void:
	var similarity: Dictionary = result["similarity"]
	var lines: Array[String] = []
	lines.append("[b]%s[/b] -> %.1f damage" % [
		result["word"].to_upper(), result["damage"]
	])
	var letter_bits: Array[String] = []
	for row: Dictionary in result["letters"]:
		var marker: String = "" if row["drawn"] else "*"
		letter_bits.append("%s%s %.1f" % [
			row["letter"], marker, row["power"]
		])
	lines.append("letters: " + ", ".join(letter_bits))
	lines.append("(* = not drawn from hand)")
	lines.append("base power: %.1f" % result["base_power"])
	lines.append(
		"length x%.2f" % result["length_multiplier"]
	)
	lines.append("pos %s x%.2f" % [
		WordNet.pos_name(result["pos"]),
		result["pos_multiplier"],
	])
	lines.append("wordnet %.3f (%s: %s) vs '%s'" % [
		similarity["score"],
		similarity["strategy"],
		similarity["detail"],
		similarity.get("tag", ""),
	])
	lines.append("effectiveness %.2f -> semantic x%.2f" % [
		result["effectiveness"],
		result["semantic_multiplier"],
	])
	var elemental_damage: Dictionary = result["elemental_damage"]
	for element_name: String in elemental_damage:
		var amount: float = elemental_damage[element_name]
		if amount > 0.0:
			lines.append("%s %.1f" % [element_name, amount])
	if result["lightning_procs"] > 0:
		lines.append("lightning echoes %d" % result["lightning_procs"])
	breakdown_label.text = "\n".join(lines)


# --- Similarity tester ---------------------------------------------

func _on_score_pressed() -> void:
	var word: String = sim_word_input.text.strip_edges()
	var tag: String = sim_tag_input.text.strip_edges()
	if word.is_empty() or tag.is_empty():
		sim_result_label.text = "enter word and tag"
		return
	var result: Dictionary = WordNet.similarity_detailed(
		word, tag
	)
	sim_result_label.text = "%.3f (%s: %s)" % [
		result["score"], result["strategy"], result["detail"]
	]


# --- Cheats --------------------------------------------------------

func _on_gold_pressed() -> void:
	PlayerStats.mark_debug_assisted()
	RunState.add_gold(100)


func _on_heal_pressed() -> void:
	PlayerStats.mark_debug_assisted()
	RunState.heal_player(RunState.player_max_health)


func _on_tavern_pressed() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()
	PlayerStats.mark_debug_assisted()
	get_tree().change_scene_to_file(ScenePaths.TAVERN)


func _refresh_encounter_buttons() -> void:
	_refresh_profile_letters()
	auto_kill_button.disabled = get_tree().current_scene == null or \
		get_tree().current_scene.scene_file_path != ScenePaths.COMBAT
	var in_hangman: bool = get_tree().current_scene != null and \
		get_tree().current_scene.scene_file_path == ScenePaths.HANGMAN
	hangman_tier_select.disabled = not in_hangman or not WordNet.is_ready
	hangman_reset_button.disabled = not in_hangman or not WordNet.is_ready


func _on_auto_kill_pressed() -> void:
	PlayerStats.mark_debug_assisted()
	auto_kill_requested.emit()
	panel.hide()
	EventBus.emit_debug_toggled(false)


func _on_free_map_pressed() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()
	PlayerStats.mark_debug_assisted()
	free_map_select = true
	RunState.selected_biome = "tundra"
	RunState.ensure_tundra_route_plan()
	panel.hide()
	EventBus.emit_debug_toggled(false)
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)


func _on_playtest_run_pressed() -> void:
	free_map_select = false
	RunState.start_playtest_run()
	PlayerStats.mark_debug_assisted()
	panel.hide()
	EventBus.emit_debug_toggled(false)
	get_tree().change_scene_to_file(ScenePaths.ENCOUNTER_SELECT)


func _on_hangman_reset_pressed() -> void:
	PlayerStats.mark_debug_assisted()
	var tier_override: int = hangman_tier_select.selected - 1
	hangman_reset_requested.emit(tier_override)
	panel.hide()
	EventBus.emit_debug_toggled(false)


func _on_tags_changed(new_text: String) -> void:
	PlayerStats.mark_debug_assisted()
	forced_tags = []
	for tag: String in new_text.split(",", false):
		var cleaned: String = tag.strip_edges().to_lower()
		if not cleaned.is_empty():
			forced_tags.append(cleaned)


func _on_letters_changed(new_text: String) -> void:
	PlayerStats.mark_debug_assisted()
	forced_letters = new_text.strip_edges().to_lower()


func _refresh_profile_letters() -> void:
	var previous: LetterStats = null
	if profile_select.selected >= 0 and profile_select.selected < _profile_letters.size():
		previous = _profile_letters[profile_select.selected]
	_profile_letters = RunState.combat_letters().duplicate()
	for stats: LetterStats in RunState.letter_inventory:
		if not _profile_letters.has(stats):
			_profile_letters.append(stats)
	profile_select.clear()
	for index in _profile_letters.size():
		var stats: LetterStats = _profile_letters[index]
		profile_select.add_item("%d: %s %s · %d uses · %d scars" % [
			index + 1, stats.letter.to_upper(), stats.element_name_text(),
			stats.accepted_uses, stats.scar_count()])
		if stats == previous:
			profile_select.select(index)
	var empty := _profile_letters.is_empty()
	if empty:
		profile_select.add_item("Start a run to test letters")
	profile_select.disabled = empty
	profile_one_button.disabled = empty
	profile_five_button.disabled = empty
	$Panel/Scroll/Box/FeatureRow/BodyButton.disabled = empty
	$Panel/Scroll/Box/FeatureRow/FaceButton.disabled = empty


func _cycle_profile_feature(body: bool) -> void:
	_refresh_profile_letters()
	if _profile_letters.is_empty():
		return
	var stats := _profile_letters[profile_select.selected]
	if not PlayerProfile.cosmetic_for_letter(stats.letter).is_empty():
		sim_result_label.text = "Choose Default in Cosmetics to preview these features."
		return
	PlayerStats.mark_debug_assisted()
	var selected := CharacterFeatures.choices(stats)
	if body:
		stats.body_feature = (selected.x + 1) % 3
	else:
		stats.face_feature = (selected.y + 1) % 3
	EventBus.emit_deck_changed()
	panel.hide()
	EventBus.emit_debug_toggled(false)
	LetterInspector.open_for(stats)


func _simulate_profile_uses(count: int) -> void:
	# Refresh first so a replaced/sold item cannot be modified by a stale selection.
	_refresh_profile_letters()
	if _profile_letters.is_empty():
		return
	var stats: LetterStats = _profile_letters[profile_select.selected]
	PlayerStats.mark_debug_assisted()
	for unused in count:
		stats.record_word_use("DEBUG", 0.0)
	EventBus.emit_deck_changed()
	_refresh_profile_letters()
	panel.hide()
	EventBus.emit_debug_toggled(false)
	LetterInspector.open_for(stats)
