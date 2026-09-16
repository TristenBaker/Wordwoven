extends Control
## Runs one combat encounter as a turn state machine: the player
## drafts a word, the enemy takes the damage, then retaliates.
## Delegates the rules to DeckManager, WordValidator,
## DamageCalculator, EnemyFactory, EncounterConditions, encounter
## abilities, and SpeedTimer, keeping only the flow and screen here.

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

const REDRAW_COST_PER_TILE: int = 2

# Log panel anchors while expanded and while showing only its header.
const LOG_EXPANDED_BOTTOM: float = 0.72
const LOG_COLLAPSED_BOTTOM: float = 0.08

var required_pos: String = "n"
var relic_choice_buttons: Array[Button] = []

# Injected before the scene enters the tree for deterministic tests.
var clock: GameClock = null
var rng: RandomNumberGenerator = null

var conditions: EncounterConditions = null
var abilities: EncounterAbilities = EncounterAbilities.new()
var speed_timer: SpeedTimer = null
var environment_id: String = EnvironmentCatalog.NORMAL

var _offered_relic_ids: Array[String] = []
var _state: State = State.PLAYER_INPUT
var _relic_system: RelicSystem = RelicSystem.new()
var _previous_drawn: Array[LetterStats] = []
var _damage_popup_tween: Tween = null
var _turn_number: int = 0
var _redraw_used: bool = false
var _selected_tiles: Array[LetterStats] = []
var _bonus_was_active: bool = false

@onready var background: TextureRect = $Background
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
@onready var redraw_button: Button = \
		$Layout/InputArea/InputRow/RedrawButton
@onready var word_tile_board: WordTileBoard = \
		$Layout/InputArea/WordComposerRow/WordTileBoard
@onready var damage_output: Label = \
		$Layout/InputArea/WordComposerRow/OutputCounters/Damage/Value
@onready var heal_output: Label = \
		$Layout/InputArea/WordComposerRow/OutputCounters/Heal/Value
@onready var gold_output: Label = \
		$Layout/InputArea/WordComposerRow/OutputCounters/Gold/Value
@onready var damage_popup: Label = $Layout/DamagePopup
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var dev_kill_button: Button = $Layout/DevKillButton
@onready var feedback_label: Label = \
		$Layout/InputArea/FeedbackLabel
@onready var prompt_label: Label = $Layout/InputArea/PromptLabel
@onready var side_panel: PanelContainer = $Layout/SidePanel
@onready var log_toggle_button: Button = \
		$Layout/SidePanel/LogBox/LogToggleButton
@onready var log_label: RichTextLabel = \
		$Layout/SidePanel/LogBox/LogLabel
@onready var player_health_bar: ProgressBar = \
		$Layout/StatusArea/PlayerHealthBar
@onready var player_health_label: Label = \
		$Layout/StatusArea/PlayerHealthBar/PlayerHealthLabel
@onready var player_heal_preview: ColorRect = \
		$Layout/StatusArea/PlayerHealthBar/HealPreview
@onready var gold_label: Label = $Layout/StatusArea/GoldLabel
@onready var stage_label: Label = $Layout/StatusArea/StageLabel
@onready var timer_label: Label = $Layout/StatusArea/TimerLabel
@onready var timer_bar: ProgressBar = $Layout/StatusArea/TimerBar
@onready var encounter_info_label: Label = \
		$Layout/StatusArea/EncounterInfoLabel
@onready var confirmer: ActionConfirmer = $ActionConfirmer


func _ready() -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	speed_timer = SpeedTimer.new(clock)
	conditions = EncounterConditions.new(rng)
	deck_manager.rng = rng
	# Enter normally makes a LineEdit release editing focus. The field is the
	# invisible keyboard source for the tile board, so retain that focus and
	# let the combat state machine decide when input is unavailable instead.
	word_input.keep_editing_on_text_submit = true
	submit_button.pressed.connect(_on_submit)
	redraw_button.pressed.connect(request_redraw)
	word_input.text_submitted.connect(_on_text_submitted)
	word_input.text_changed.connect(_on_text_changed)
	word_tile_board.focus_requested.connect(_focus_word_input)
	pause_menu.resumed.connect(_restore_composer_after_pause)
	dev_kill_button.pressed.connect(_on_dev_kill_pressed)
	log_toggle_button.toggled.connect(set_log_expanded)
	enemy.died.connect(_on_enemy_died)
	_start_encounter()


func _process(_delta: float) -> void:
	_refresh_timer_display()


func _start_encounter() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()
	required_pos = PROMPT_ORDER[
		(RunState.encounter_index - 1) % PROMPT_ORDER.size()
	]
	_refresh_prompt()
	validator.start_encounter()
	deck_manager.start_encounter()
	var spawn_data: Dictionary = _build_spawn_data()
	enemy.setup(spawn_data)
	abilities.add_entries(spawn_data.get("abilities", []))
	abilities.add_entries(EnvironmentCatalog.abilities(environment_id))
	_apply_background()
	_refresh_encounter_info(spawn_data)
	EventBus.emit_encounter_started(spawn_data)
	_refresh_status()
	_refresh_word_composer("")
	_log("A %s appears! Its nature: %s" % [
		spawn_data["name"], " • ".join(spawn_data["tags"])
	])
	_log("Terrain: " + EnvironmentCatalog.describe(environment_id))
	_log("Opposites and thematic counters deal extra damage.")
	_begin_player_turn()


# A confirmed encounter setup is used exactly as previewed; without
# one (debug tools and old saves) the stage rolls a foe as before.
func _build_spawn_data() -> Dictionary:
	var setup: Dictionary = RunState.take_pending_encounter()
	if not setup.is_empty() and factory.has_enemy(setup["enemy_id"]):
		RunState.next_enemy_id = ""
		environment_id = setup["environment"]
		if not EnvironmentCatalog.has_environment(environment_id):
			environment_id = EnvironmentCatalog.NORMAL
		return factory.build_configured_spawn_data(
			setup["enemy_id"], setup["tag"]
		)
	environment_id = EnvironmentCatalog.NORMAL
	return factory.build_spawn_data(_pick_enemy_id())


func _pick_enemy_id() -> String:
	var enemy_id: String = RunState.next_enemy_id
	RunState.next_enemy_id = ""
	if enemy_id.is_empty():
		if RunState.is_boss_next():
			enemy_id = factory.boss_id()
		else:
			var choices: Array[String] = factory.ids_for_stage(
				RunState.encounter_index
			)
			enemy_id = choices[rng.randi_range(0, choices.size() - 1)]
	return enemy_id


func _apply_background() -> void:
	var texture: Texture2D = EnvironmentCatalog.pick_background(
		environment_id, rng
	)
	if texture != null:
		background.texture = texture


# --- Turn flow -----------------------------------------------------

# Opens a new player turn: turn-start abilities resolve, then the
# swift-cast deadline starts as input becomes available.
func _begin_player_turn() -> void:
	if _state == State.WON or _state == State.LOST:
		return
	_turn_number += 1
	_redraw_used = false
	_selected_tiles = []
	for line: String in abilities.on_player_turn_start(_ability_context()):
		_log(line)
	_rebuild_hand_tiles()
	_refresh_word_composer(word_input.text)
	speed_timer.start()
	_enter_player_input()


func _enter_player_input() -> void:
	_state = State.PLAYER_INPUT
	word_input.editable = true
	submit_button.disabled = false
	_refresh_redraw_button()
	_focus_word_input()


func _focus_word_input() -> void:
	word_input.grab_focus()


func _restore_composer_after_pause() -> void:
	if _state == State.PLAYER_INPUT:
		call_deferred("_focus_word_input")


func _on_text_submitted(_text: String) -> void:
	_on_submit()


func _on_submit() -> void:
	if _state != State.PLAYER_INPUT:
		return
	# The deadline is judged by when the player submitted, not by how
	# long validation takes.
	var submitted_msec: int = speed_timer.now_msec()
	var word: String = word_input.text.strip_edges().to_lower()
	var verdict: Dictionary = validator.validate(word, required_pos)
	if not verdict["valid"]:
		feedback_label.text = verdict["reason"]
		EventBus.emit_word_rejected(word, verdict["reason"])
		# A rejected word never starts a turn. Reset the composer immediately,
		# then defer focus restoration so Enter/button submission cannot leave
		# the visually hidden LineEdit unfocused.
		word_input.clear()
		_enter_player_input()
		call_deferred("_focus_word_input")
		return
	var swift: bool = speed_timer.qualifies(submitted_msec)
	speed_timer.stop()
	_state = State.RESOLVING
	word_input.editable = false
	submit_button.disabled = true
	redraw_button.disabled = true
	feedback_label.text = ""
	_resolve_word(word, swift)


func _on_dev_kill_pressed() -> void:
	if _state in [State.WON, State.LOST] or enemy == null \
			or not enemy.is_alive():
		return
	word_input.editable = false
	submit_button.disabled = true
	enemy.take_damage(999999.0)


func _resolve_word(word: String, swift: bool = false) -> void:
	var split: Dictionary = deck_manager.split_word(word, conditions)
	var drawn: Array[LetterStats] = split["drawn"]
	var undrawn: Array[String] = split["undrawn"]
	var result: Dictionary = calculator.calculate(
		word, drawn, undrawn, enemy.tags, required_pos,
		_calculation_context(swift)
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
	var eligible: Array[LetterStats] = result["level_eligible"]
	for stats: LetterStats in eligible:
		stats.gain_use_level()
	if not eligible.is_empty():
		EventBus.emit_deck_changed()
	_advance_prompt()
	deck_manager.spend_letters(drawn)
	_selected_tiles = []
	_rebuild_hand_tiles()
	word_input.clear()
	_refresh_status()
	_show_damage_popup(result["damage"])
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
	for line: String in abilities.after_enemy_attack(_ability_context()):
		_log(line)
	_rebuild_hand_tiles()
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	if _state == State.ENEMY_TURN:
		# Defer once so a just-finished animation or button event cannot claim
		# focus from the hidden LineEdit after the next player turn opens.
		call_deferred("_begin_player_turn")


func _on_enemy_died() -> void:
	if _state == State.WON:
		return
	_state = State.WON
	speed_timer.stop()
	confirmer.decline()
	_selected_tiles = []
	_return_stolen_letters()
	_rebuild_hand_tiles()
	var earned: int = enemy.gold_reward
	# Newly selected Quills begin paying on the next victory.
	earned += int(_relic_system.total_effect("victory_gold"))
	RunState.add_gold(earned)
	RunState.complete_encounter()
	RunState.is_run_active = true
	RunState.begin_victory(enemy.enemy_name, earned)
	EventBus.emit_encounter_won(earned)
	get_tree().change_scene_to_file(ScenePaths.FIGHT_COMPLETION)


func _return_stolen_letters() -> void:
	var returned: Array[LetterStats] = conditions.release_stolen()
	if returned.is_empty():
		return
	deck_manager.return_to_discard(returned)
	var letters: Array[String] = []
	for stats: LetterStats in returned:
		letters.append(stats.letter.to_upper())
	_log("Your stolen tiles return: %s." % ", ".join(letters))


func _on_player_died() -> void:
	_state = State.LOST
	speed_timer.stop()
	get_tree().change_scene_to_file(ScenePaths.RUN_LOST)


func request_redraw() -> void:
	var problem: String = _redraw_problem(_selected_tiles)
	if not problem.is_empty():
		feedback_label.text = problem
		return
	var count: int = _selected_tiles.size()
	var message: String = (
		"Redraw %d tile(s) for %dg? This uses your one redraw this turn."
		+ " The enemy does not attack, and nothing levels."
	) % [count, redraw_cost(count)]
	confirmer.request(
		"Redraw tiles",
		message,
		_confirm_redraw.bind(_turn_number, _selected_tiles.duplicate())
	)


func _confirm_redraw(turn: int, letters: Array[LetterStats]) -> void:
	if turn != _turn_number:
		feedback_label.text = "That redraw is no longer available."
		return
	var problem: String = _redraw_problem(letters)
	if not problem.is_empty():
		feedback_label.text = problem
		return
	if not RunState.spend_gold(redraw_cost(letters.size())):
		feedback_label.text = "Not enough gold to redraw."
		return
	deck_manager.redraw(letters)
	_redraw_used = true
	_selected_tiles = []
	_log("You pay %dg to redraw %d tile(s)." % [
		redraw_cost(letters.size()), letters.size()
	])
	feedback_label.text = ""
	_rebuild_hand_tiles()
	_on_text_changed(word_input.text)
	_refresh_status()
	_refresh_redraw_button()
	call_deferred("_focus_word_input")


# Empty when the redraw can go ahead; otherwise the reason it cannot.
func _redraw_problem(letters: Array[LetterStats]) -> String:
	if _state != State.PLAYER_INPUT:
		return "You can only redraw during your turn."
	if _redraw_used:
		return "You have already redrawn this turn."
	if letters.is_empty():
		return "Click hand tiles to select them for a redraw."
	for stats: LetterStats in letters:
		if not deck_manager.hand().has(stats):
			return "Those tiles are no longer in your hand."
	if RunState.gold < redraw_cost(letters.size()):
		return "Redrawing %d tile(s) costs %dg." % [
			letters.size(), redraw_cost(letters.size())
		]
	if not deck_manager.can_redraw(letters.size()):
		return "Not enough letters remain to replace those tiles."
	return ""


func _refresh_redraw_button() -> void:
	var count: int = _selected_tiles.size()
	redraw_button.text = "Redraw" if count == 0 \
			else "Redraw (%dg)" % redraw_cost(count)
	redraw_button.disabled = _state != State.PLAYER_INPUT \
			or _redraw_used or count == 0
	if _redraw_used:
		redraw_button.text = "Redrawn"


# --- Screen updates ------------------------------------------------

## Shows or hides the battle log; hidden entries are preserved.
func set_log_expanded(expanded: bool) -> void:
	log_label.visible = expanded
	log_toggle_button.set_pressed_no_signal(expanded)
	log_toggle_button.text = "Battle Log ▾" if expanded \
			else "Battle Log ▸"
	side_panel.anchor_bottom = LOG_EXPANDED_BOTTOM if expanded \
			else LOG_COLLAPSED_BOTTOM


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


func _refresh_encounter_info(spawn_data: Dictionary) -> void:
	var lines: Array[String] = [factory.describe(spawn_data["id"])]
	lines.append(EnvironmentCatalog.describe(environment_id))
	encounter_info_label.text = "\n".join(lines)
	encounter_info_label.tooltip_text = encounter_info_label.text
	enemy.tooltip_text = factory.describe(spawn_data["id"])


func _refresh_timer_display() -> void:
	var active: bool = _state == State.PLAYER_INPUT \
			and speed_timer != null and speed_timer.remaining_msec() > 0
	var remaining: int = speed_timer.remaining_msec() \
			if speed_timer != null else 0
	timer_bar.value = float(remaining)
	if _state != State.PLAYER_INPUT:
		timer_label.text = "Swift bonus: waiting"
	elif active:
		timer_label.text = "Swift bonus ×%.1f: %.1fs" % [
			SpeedTimer.DAMAGE_MULTIPLIER, float(remaining) / 1000.0
		]
	else:
		timer_label.text = "Swift bonus missed"
	if active != _bonus_was_active:
		_bonus_was_active = active
		if _state == State.PLAYER_INPUT:
			_refresh_word_composer(word_input.text)


func _on_text_changed(new_text: String) -> void:
	var typing: bool = not new_text.strip_edges().is_empty()
	var split: Dictionary = deck_manager.split_word(
		new_text.strip_edges().to_lower(), conditions
	)
	var drawn: Array[LetterStats] = split["drawn"]
	_refresh_word_composer(new_text, split)
	_animate_new_tile_selections(drawn)
	_previous_drawn = drawn.duplicate()
	for tile: LetterTile in hand_box.get_children():
		tile.set_used(drawn.has(tile.stats), typing)


func _refresh_word_composer(
	raw_word: String, split: Dictionary = {}
) -> void:
	var word: String = raw_word.strip_edges().to_lower()
	if split.is_empty():
		split = deck_manager.split_word(word, conditions)
	var drawn: Array[LetterStats] = split["drawn"]
	var undrawn: Array[String] = split["undrawn"]
	word_tile_board.set_word(word, drawn)
	if word.is_empty() or enemy == null or not enemy.is_alive():
		_set_output_counters(0, 0, 0)
		_set_health_previews(0, 0)
		return
	var swift: bool = _state == State.PLAYER_INPUT \
			and speed_timer.remaining_msec() > 0
	var result: Dictionary = calculator.calculate(
		word, drawn, undrawn, enemy.tags, required_pos,
		_calculation_context(swift)
	)
	_set_output_counters(
		int(round(float(result["damage"]))),
		int(result["heal_amount"]), int(result["gold_bonus"])
	)
	_set_health_previews(
		int(round(float(result["damage"]))), int(result["heal_amount"])
	)


func _calculation_context(swift: bool) -> Dictionary:
	return {"conditions": conditions, "speed_bonus": swift}


func _ability_context() -> AbilityContext:
	return AbilityContext.new(conditions, deck_manager, enemy.enemy_name)


func _set_output_counters(damage: int, healing: int, gold: int) -> void:
	damage_output.text = str(damage)
	heal_output.text = str(healing)
	gold_output.text = str(gold)


func _set_health_previews(damage: int, healing: int) -> void:
	enemy.set_projected_damage(damage)
	var current_health: int = RunState.player_health
	var projected_health: int = mini(
		current_health + healing, RunState.player_max_health
	)
	player_heal_preview.anchor_left = float(current_health) \
		/ float(RunState.player_max_health)
	player_heal_preview.anchor_right = float(projected_health) \
		/ float(RunState.player_max_health)
	player_heal_preview.visible = projected_health > current_health


func _animate_new_tile_selections(drawn: Array[LetterStats]) -> void:
	if _state != State.PLAYER_INPUT:
		return
	for stats: LetterStats in drawn:
		if _previous_drawn.has(stats):
			continue
		var source: LetterTile = _hand_tile_for(stats)
		var target: Rect2 = word_tile_board.tile_global_rect_for(stats)
		if source != null and target.size != Vector2.ZERO:
			_fly_tile_to_board(source, stats, target)


func _hand_tile_for(stats: LetterStats) -> LetterTile:
	for tile: LetterTile in hand_box.get_children():
		if tile.stats == stats:
			return tile
	return null


func _fly_tile_to_board(
	source: LetterTile, stats: LetterStats, target: Rect2
) -> void:
	var flying: LetterTile = LETTER_TILE_SCENE.instantiate()
	add_child(flying)
	flying.setup(stats)
	flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flying.z_index = 20
	flying.global_position = source.global_position
	flying.size = source.size
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying, "global_position", target.position, 0.24)
	tween.tween_property(flying, "size", target.size, 0.24)
	tween.chain().tween_callback(flying.queue_free)


func _show_damage_popup(amount: float) -> void:
	if _damage_popup_tween != null and _damage_popup_tween.is_valid():
		_damage_popup_tween.kill()
	damage_popup.text = "-%d" % int(round(amount))
	damage_popup.show()
	damage_popup.modulate = Color(1.0, 0.25, 0.18, 1.0)
	damage_popup.pivot_offset = damage_popup.size * 0.5
	damage_popup.scale = Vector2(0.6, 0.6)
	_damage_popup_tween = create_tween().set_parallel(true)
	_damage_popup_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_damage_popup_tween.tween_property(
		damage_popup, "scale", Vector2(1.25, 1.25), 0.18
	)
	_damage_popup_tween.tween_property(
		damage_popup, "modulate", Color(1.0, 0.2, 0.12, 0.0), 1.25
	).set_delay(0.25)
	_damage_popup_tween.chain().tween_callback(damage_popup.hide)


func _rebuild_hand_tiles() -> void:
	for child: Node in hand_box.get_children():
		hand_box.remove_child(child)
		child.queue_free()
	for stats: LetterStats in deck_manager.hand():
		var tile: LetterTile = LETTER_TILE_SCENE.instantiate()
		hand_box.add_child(tile)
		tile.setup(stats)
		tile.set_conditions(
			conditions.is_frozen(stats), conditions.is_poisoned(stats),
			conditions.describe(stats)
		)
		tile.set_selected(_selected_tiles.has(stats))
		tile.pressed.connect(toggle_tile_selection)
	_refresh_redraw_button()


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
	if result["speed_bonus"]:
		lines.append("  Swift cast! ×%.1f damage." % \
				result["speed_multiplier"])
	if not String(counter.get("tag", "")).is_empty():
		lines.append("  counter vs %s: %.2f (%s)" % [
			counter["tag"], counter["score"], counter["strategy"],
		])
	if result["frozen_count"] > 0:
		lines.append("  %d frozen tile(s) gave only 20%% power." % \
				result["frozen_count"])
	if result["poisoned_count"] > 0:
		lines.append("  %d poisoned tile(s) were halved." % \
				result["poisoned_count"])
	if result["heal_amount"] > 0:
		lines.append("  Healers restore %d HP." % result["heal_amount"])
	if result["gold_bonus"] > 0:
		lines.append("  Rogues collect %d gold." % result["gold_bonus"])
	return "\n".join(lines)


func _log(message: String) -> void:
	log_label.append_text(message + "\n")
