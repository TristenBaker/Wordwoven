extends CanvasLayer
## Developer overlay, toggled with F12. Shows the full damage
## breakdown for the last word played, offers a live similarity
## tester, and carries cheats: gold, healing, skipping to the
## tavern, and forcing enemy tags or drawn letters.

# Set from the overlay; EnemyFactory applies them at the next spawn.
var forced_tags: Array[String] = []

# Set from the overlay; DeckManager deals these at the next refill.
var forced_letters: String = ""

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
@onready var tags_input: LineEdit = $Panel/Box/ForceRow/TagsInput
@onready var letters_input: LineEdit = \
		$Panel/Box/ForceRow/LettersInput


func _ready() -> void:
	panel.hide()
	score_button.pressed.connect(_on_score_pressed)
	gold_button.pressed.connect(_on_gold_pressed)
	heal_button.pressed.connect(_on_heal_pressed)
	tavern_button.pressed.connect(_on_tavern_pressed)
	tags_input.text_changed.connect(_on_tags_changed)
	letters_input.text_changed.connect(_on_letters_changed)
	EventBus.word_resolved.connect(_on_word_resolved)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay_toggle"):
		panel.visible = not panel.visible
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
	if result["gold_bonus"] > 0:
		lines.append("rogue gold +%d" % result["gold_bonus"])
	if result["heal_amount"] > 0:
		lines.append("healer restore +%d" % result["heal_amount"])
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
	RunState.add_gold(100)


func _on_heal_pressed() -> void:
	RunState.heal_player(RunState.player_max_health)


func _on_tavern_pressed() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()
	get_tree().change_scene_to_file(ScenePaths.TAVERN)


func _on_tags_changed(new_text: String) -> void:
	forced_tags = []
	for tag: String in new_text.split(",", false):
		var cleaned: String = tag.strip_edges().to_lower()
		if not cleaned.is_empty():
			forced_tags.append(cleaned)


func _on_letters_changed(new_text: String) -> void:
	forced_letters = new_text.strip_edges().to_lower()
