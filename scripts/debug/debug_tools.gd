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

@onready var panel: PanelContainer = $Panel
@onready var breakdown_label: RichTextLabel = \
		$Panel/Box/BreakdownLabel
@onready var sim_word_input: LineEdit = \
		$Panel/Box/SimRow/SimWordInput
@onready var sim_tag_input: LineEdit = \
		$Panel/Box/SimRow/SimTagInput
@onready var sim_result_label: Label = \
		$Panel/Box/SimResultLabel
@onready var score_button: Button = $Panel/Box/SimRow/ScoreButton
@onready var gold_button: Button = $Panel/Box/CheatRow/GoldButton
@onready var heal_button: Button = $Panel/Box/CheatRow/HealButton
@onready var tavern_button: Button = \
		$Panel/Box/CheatRow/TavernButton
@onready var auto_kill_button: Button = $Panel/Box/EncounterRow/AutoKillButton
@onready var free_map_button: Button = $Panel/Box/EncounterRow/FreeMapButton
@onready var hangman_tier_select: OptionButton = $Panel/Box/HangmanRow/TierSelect
@onready var hangman_reset_button: Button = $Panel/Box/HangmanRow/ResetButton
@onready var tags_input: LineEdit = $Panel/Box/ForceRow/TagsInput
@onready var letters_input: LineEdit = \
		$Panel/Box/ForceRow/LettersInput


func _ready() -> void:
	panel.hide()
	score_button.pressed.connect(_on_score_pressed)
	gold_button.pressed.connect(_on_gold_pressed)
	heal_button.pressed.connect(_on_heal_pressed)
	tavern_button.pressed.connect(_on_tavern_pressed)
	auto_kill_button.pressed.connect(_on_auto_kill_pressed)
	free_map_button.pressed.connect(_on_free_map_pressed)
	hangman_reset_button.pressed.connect(_on_hangman_reset_pressed)
	RunState.run_started.connect(func(): free_map_select = false)
	tags_input.text_changed.connect(_on_tags_changed)
	letters_input.text_changed.connect(_on_letters_changed)
	EventBus.word_resolved.connect(_on_word_resolved)


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
