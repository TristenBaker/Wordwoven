extends Control
## Runs one combat encounter as a turn state machine: the player
## drafts a word, the enemy takes the damage, then retaliates.
## Delegates the rules to DeckManager, WordValidator,
## DamageCalculator, and EnemyFactory child nodes and keeps only
## the flow and the screen updates here.

enum State {
	PLAYER_INPUT,
	RESOLVING,
	ENEMY_TURN,
	WON,
	LOST,
}

const LETTER_TILE_SCENE: PackedScene = \
		preload("res://scenes/combat/letter_tile.tscn")

# Pause before and after the enemy's retaliation, in seconds.
const ENEMY_TURN_DELAY: float = 0.7

const PROMPT_ORDER: Array[String] = ["n", "v", "a", "r"]

var required_pos: String = "n"
var relic_choice_buttons: Array[Button] = []
var _offered_relic_ids: Array[String] = []

var _state: State = State.PLAYER_INPUT
var _relic_system: RelicSystem = RelicSystem.new()
var _continuing: bool = false

@onready var deck_manager: DeckManager = $Systems/DeckManager
@onready var validator: WordValidator = $Systems/WordValidator
@onready var calculator: DamageCalculator = \
		$Systems/DamageCalculator
@onready var factory: EnemyFactory = $Systems/EnemyFactory
@onready var enemy: Enemy = $Layout/EnemyArea/Enemy
@onready var hand_box: HBoxContainer = \
		$Layout/HandArea/HandBox
@onready var word_input: LineEdit = \
		$Layout/InputArea/InputRow/WordInput
@onready var submit_button: Button = \
		$Layout/InputArea/InputRow/SubmitButton
@onready var feedback_label: Label = \
		$Layout/InputArea/FeedbackLabel
@onready var prompt_label: Label = $Layout/InputArea/PromptLabel
@onready var log_label: RichTextLabel = \
		$Layout/SidePanel/LogLabel
@onready var player_health_bar: ProgressBar = \
		$Layout/StatusArea/PlayerHealthBar
@onready var player_health_label: Label = \
		$Layout/StatusArea/PlayerHealthBar/PlayerHealthLabel
@onready var gold_label: Label = $Layout/StatusArea/GoldLabel
@onready var stage_label: Label = $Layout/StatusArea/StageLabel
@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var victory_label: Label = \
		$VictoryPanel/VictoryBox/VictoryLabel
@onready var victory_story: RichTextLabel = \
		$VictoryPanel/VictoryBox/VictoryStory
@onready var relic_status_label: Label = \
		$VictoryPanel/VictoryBox/RelicStatusLabel
@onready var continue_button: Button = \
		$VictoryPanel/VictoryBox/ContinueButton


func _ready() -> void:
	submit_button.pressed.connect(_on_submit)
	word_input.text_submitted.connect(_on_text_submitted)
	word_input.text_changed.connect(_on_text_changed)
	continue_button.pressed.connect(_on_continue_pressed)
	relic_choice_buttons = [
		$VictoryPanel/VictoryBox/RelicChoices/QuillButton,
		$VictoryPanel/VictoryBox/RelicChoices/TomeButton,
		$VictoryPanel/VictoryBox/RelicChoices/BookmarkButton,
	]
	_setup_relic_choices()
	enemy.died.connect(_on_enemy_died)
	victory_panel.hide()
	_start_encounter()


func _start_encounter() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()
	required_pos = PROMPT_ORDER[
		(RunState.encounter_index - 1) % PROMPT_ORDER.size()
	]
	_refresh_prompt()
	validator.start_encounter()
	deck_manager.start_encounter()
	var spawn_data: Dictionary = _pick_spawn_data()
	enemy.setup(spawn_data)
	EventBus.emit_encounter_started(spawn_data)
	_rebuild_hand_tiles()
	_refresh_status()
	_log("A %s appears! Its nature: %s" % [
		spawn_data["name"], " • ".join(spawn_data["tags"])
	])
	_enter_player_input()
	_log("Opposites and thematic counters deal extra damage.")


func _pick_spawn_data() -> Dictionary:
	var enemy_id: String = RunState.next_enemy_id
	RunState.next_enemy_id = ""
	if enemy_id.is_empty():
		if RunState.is_boss_next():
			enemy_id = factory.boss_id()
		else:
			var choices: Array[String] = factory.ids_for_stage(
				RunState.encounter_index
			)
			enemy_id = choices.pick_random()
	return factory.build_spawn_data(enemy_id)


# --- Turn flow -----------------------------------------------------

func _enter_player_input() -> void:
	_state = State.PLAYER_INPUT
	word_input.editable = true
	submit_button.disabled = false
	word_input.grab_focus()


func _on_text_submitted(_text: String) -> void:
	_on_submit()


func _on_submit() -> void:
	if _state != State.PLAYER_INPUT:
		return
	var word: String = word_input.text.strip_edges().to_lower()
	var verdict: Dictionary = validator.validate(word, required_pos)
	if not verdict["valid"]:
		feedback_label.text = verdict["reason"]
		EventBus.emit_word_rejected(word, verdict["reason"])
		return
	_state = State.RESOLVING
	word_input.editable = false
	submit_button.disabled = true
	feedback_label.text = ""
	_resolve_word(word)


func _resolve_word(word: String) -> void:
	var split: Dictionary = deck_manager.split_word(word)
	var drawn: Array[LetterStats] = split["drawn"]
	var undrawn: Array[String] = split["undrawn"]
	var result: Dictionary = calculator.calculate(
		word, drawn, undrawn, enemy.tags, required_pos
	)
	validator.mark_played(word)
	RunState.record_word(
		word, enemy.enemy_name, enemy.tags, result["damage"],
		required_pos
	)
	if result["gold_bonus"] > 0:
		RunState.add_gold(result["gold_bonus"])
	if result["heal_amount"] > 0:
		RunState.heal_player(result["heal_amount"])
	EventBus.emit_word_resolved(result)
	_log(_describe_result(result))
	# Current-word numbers are frozen before the used letters grow.
	for stats: LetterStats in drawn:
		stats.gain_use_level()
	if not drawn.is_empty():
		EventBus.emit_deck_changed()
	_advance_prompt()
	deck_manager.spend_letters(drawn)
	_rebuild_hand_tiles()
	word_input.clear()
	_refresh_status()
	enemy.take_damage(result["damage"])
	if enemy.is_alive():
		_enemy_turn()


func _enemy_turn() -> void:
	_state = State.ENEMY_TURN
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	if _state != State.ENEMY_TURN:
		return
	_log("The %s retaliates for %d damage!" % [
		enemy.enemy_name, enemy.attack
	])
	RunState.damage_player(enemy.attack)
	_refresh_status()
	if RunState.player_health <= 0:
		_on_player_died()
		return
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	if _state == State.ENEMY_TURN:
		_enter_player_input()


func _on_enemy_died() -> void:
	if _state == State.WON:
		return
	_state = State.WON
	var earned: int = enemy.gold_reward
	# Newly selected Quills begin paying on the next victory.
	earned += int(_relic_system.total_effect("victory_gold"))
	RunState.add_gold(earned)
	RunState.complete_encounter()
	RunState.is_run_active = true
	EventBus.emit_encounter_won(earned)
	_refresh_status()
	victory_label.text = "%s defeated!\n+%d gold" % [
		enemy.enemy_name, earned
	]
	var bard: Storyteller = Storyteller.new()
	victory_story.text = bard.generate_for_encounter(
		RunState.encounter_index
	)
	_refresh_relic_choices()
	continue_button.text = "Complete the Tale" \
			if RunState.is_boss_next() else "To the Tavern"
	victory_panel.show()
	relic_choice_buttons[0].grab_focus()


func _on_player_died() -> void:
	_state = State.LOST
	get_tree().change_scene_to_file(ScenePaths.RUN_LOST)


func _on_continue_pressed() -> void:
	if _state != State.WON or _continuing:
		return
	if not RunState.relic_rewards.has(RunState.encounter_index):
		return
	_continuing = true
	continue_button.disabled = true
	var beaten_boss: bool = RunState.is_boss_next()
	RunState.advance_encounter()
	if beaten_boss:
		get_tree().change_scene_to_file(ScenePaths.RUN_WON)
	else:
		get_tree().change_scene_to_file(ScenePaths.TAVERN)


# --- Screen updates ------------------------------------------------

func _advance_prompt() -> void:
	var current: int = PROMPT_ORDER.find(required_pos)
	required_pos = PROMPT_ORDER[(current + 1) % PROMPT_ORDER.size()]
	_refresh_prompt()


func _refresh_prompt() -> void:
	var article: String = "an" if required_pos in ["a", "r"] else "a"
	prompt_label.text = "Write %s %s to shape your tale" % [
		article, WordNet.pos_name(required_pos),
	]
	if required_pos == "v":
		prompt_label.text += " (base form)"
	word_input.placeholder_text = "Enter a %s..." % \
			WordNet.pos_name(required_pos)


func _setup_relic_choices() -> void:
	for index: int in relic_choice_buttons.size():
		relic_choice_buttons[index].pressed.connect(
			_on_relic_button_pressed.bind(index)
		)


func _refresh_relic_choices() -> void:
	if _offered_relic_ids.is_empty():
		_offered_relic_ids = _relic_system.relic_ids()
		_offered_relic_ids.shuffle()
		_offered_relic_ids = _offered_relic_ids.slice(0, 3)
	var claimed: String = RunState.relic_rewards.get(
		RunState.encounter_index, ""
	)
	for index: int in relic_choice_buttons.size():
		var button: Button = relic_choice_buttons[index]
		var relic_id: String = _offered_relic_ids[index]
		var info: Dictionary = _relic_system.relic_info(relic_id)
		button.text = "%s\nOwned: %d" % [
			info.get("name", relic_id), RunState.relics.count(relic_id),
		]
		button.tooltip_text = info.get("description", "")
		button.disabled = not claimed.is_empty()
	continue_button.disabled = claimed.is_empty()
	if claimed.is_empty():
		relic_status_label.text = "Choose one free relic. Copies stack."
	else:
		relic_status_label.text = "Claimed: %s" % \
				_relic_system.relic_info(claimed).get("name", claimed)


func _on_relic_selected(relic_id: String) -> void:
	if _state != State.WON or _continuing:
		return
	if not _relic_system.grant_reward(
		relic_id, RunState.encounter_index
	):
		return
	_refresh_relic_choices()
	_refresh_status()


func _on_relic_button_pressed(index: int) -> void:
	if index < 0 or index >= _offered_relic_ids.size():
		return
	_on_relic_selected(_offered_relic_ids[index])


func _on_text_changed(new_text: String) -> void:
	var typing: bool = not new_text.strip_edges().is_empty()
	var split: Dictionary = deck_manager.split_word(
		new_text.strip_edges().to_lower()
	)
	var drawn: Array[LetterStats] = split["drawn"]
	for tile: LetterTile in hand_box.get_children():
		tile.set_used(drawn.has(tile.stats), typing)


func _rebuild_hand_tiles() -> void:
	for child: Node in hand_box.get_children():
		hand_box.remove_child(child)
		child.queue_free()
	for stats: LetterStats in deck_manager.hand():
		var tile: LetterTile = LETTER_TILE_SCENE.instantiate()
		hand_box.add_child(tile)
		tile.setup(stats)


func _refresh_status() -> void:
	player_health_bar.max_value = RunState.player_max_health
	player_health_bar.value = RunState.player_health
	player_health_label.text = "%d / %d" % [
		RunState.player_health, RunState.player_max_health
	]
	gold_label.text = "Gold: %d" % RunState.gold
	var stage_text: String = "Encounter %d of %d" % [
		RunState.encounter_index, RunState.ENCOUNTERS_PER_RUN
	]
	if RunState.is_boss_next():
		stage_text = "Final Encounter"
	stage_label.text = stage_text


func _describe_result(result: Dictionary) -> String:
	var counter: Dictionary = result["counter"]
	var lines: Array[String] = []
	lines.append("[b]%s[/b] hits for %.0f!" % [
		result["word"].to_upper(), result["damage"]
	])
	lines.append(
		"  power %.1f × length %.1f × %s %.2f × tag %.2f" % [
			result["base_power"],
			result["length_multiplier"],
			WordNet.pos_name(result["pos"]),
			result["pos_multiplier"],
			result["semantic_multiplier"],
		]
	)
	if not String(counter.get("tag", "")).is_empty():
		lines.append("  counter vs %s: %.2f (%s)" % [
			counter["tag"], counter["score"], counter["strategy"],
		])
	if result["heal_amount"] > 0:
		lines.append("  Healers restore %d HP." % result["heal_amount"])
	if result["gold_bonus"] > 0:
		lines.append("  Rogues collect %d gold." % result["gold_bonus"])
	return "\n".join(lines)


func _log(message: String) -> void:
	log_label.append_text(message + "\n")
