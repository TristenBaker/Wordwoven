extends Control
## Runs one combat encounter as a turn state machine: the player
## drafts a word, the enemy takes the damage, the player may thread
## one used letter into the next turn, then the enemy retaliates.
## Delegates the rules to DeckManager, WordValidator,
## DamageCalculator, EnemyFactory, EncounterConditions, encounter
## abilities, EnemyRuleTracker, LetterThread, and SpeedTimer,
## keeping only the flow and screen here.

enum State {
	PLAYER_INPUT,
	RESOLVING,
	THREAD_CHOICE,
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
const AUTOCORRECT_COST: int = 5

# Log panel anchors while expanded and while showing only its header.
const LOG_EXPANDED_BOTTOM: float = 0.72
const LOG_COLLAPSED_BOTTOM: float = 0.08

var required_pos: String = "n"

# Injected before the scene enters the tree for deterministic tests.
var clock: GameClock = null
var rng: RandomNumberGenerator = null
# Receives the next scene path; tests capture it instead of leaving.
var navigate: Callable = Callable()

var conditions: EncounterConditions = null
var abilities: EncounterAbilities = EncounterAbilities.new()
var speed_timer: SpeedTimer = null
var environment_id: String = EnvironmentCatalog.NORMAL
var rule_tracker: EnemyRuleTracker = null
var thread: LetterThread = LetterThread.new()

var _state: State = State.PLAYER_INPUT
var _relic_system: RelicSystem = RelicSystem.new()
var _previous_drawn: Array[LetterStats] = []
var _damage_popup_tween: Tween = null
var _turn_number: int = 0
var _redraw_used: bool = false
var _selected_tiles: Array[LetterStats] = []
var _bonus_was_active: bool = false
var _suggestions: Array[String] = []
var _suggestion_source: String = ""
var _inspire_armed: bool = false
var _exclaim_armed: bool = false
# The accepted word's drawn instances while a thread is being chosen.
var _thread_drawn: Array[LetterStats] = []

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
@onready var autocorrect_button: Button = \
		$Layout/InputArea/InputRow/AutocorrectButton
@onready var inspire_button: Button = \
		$Layout/InputArea/BoostRow/InspireButton
@onready var exclaim_button: Button = \
		$Layout/InputArea/BoostRow/ExclaimButton
@onready var thread_bar: HBoxContainer = $Layout/InputArea/ThreadBar
@onready var thread_choices: HBoxContainer = \
		$Layout/InputArea/ThreadBar/ThreadChoices
@onready var let_go_button: Button = \
		$Layout/InputArea/ThreadBar/LetGoButton
@onready var preview_label: Label = $Layout/InputArea/PreviewLabel
@onready var inspiration_label: Label = \
		$Layout/GuidanceArea/InspirationLabel
@onready var inspiration_bar: ProgressBar = \
		$Layout/GuidanceArea/InspirationBar
@onready var rules_label: Label = $Layout/GuidanceArea/RulesLabel
@onready var suggestion_menu: PopupMenu = \
		$Layout/InputArea/InputRow/AutocorrectButton/SuggestionMenu
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
	autocorrect_button.pressed.connect(request_autocorrect)
	suggestion_menu.id_pressed.connect(choose_suggestion)
	inspire_button.toggled.connect(set_inspire_armed)
	exclaim_button.toggled.connect(set_exclaim_armed)
	let_go_button.pressed.connect(skip_thread)
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
	_start_rules(spawn_data)
	_refresh_encounter_info(spawn_data)
	EventBus.emit_encounter_started(spawn_data)
	_refresh_status()
	_refresh_word_composer("")
	_log("A %s appears! Its nature: %s" % [
		spawn_data["name"], " • ".join(spawn_data["tags"])
	])
	_log("Terrain: " + EnvironmentCatalog.describe(environment_id))
	_log("Opposites and thematic counters deal extra damage.")
	_log_rules()
	_begin_player_turn()


# The foe's rotating rule must fit the encounter's fixed rules: any
# accepted vow and the run-long forgotten letter.
func _start_rules(spawn_data: Dictionary) -> void:
	var pool: Array[String] = []
	for rule_type: Variant in spawn_data.get("rules", []):
		pool.append(String(rule_type))
	rule_tracker = EnemyRuleTracker.new(
		pool, enemy.tags, RunState.fixed_combat_rules(), rng
	)
	rule_tracker.roll(required_pos)


func _log_rules() -> void:
	for rule: Dictionary in rule_tracker.active_rules():
		_log("[i]%s[/i]: %s" % [
			WordRules.display_name(rule), WordRules.describe(rule),
		])


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
	deck_manager.begin_turn()
	for line: String in abilities.on_player_turn_start(_ability_context()):
		_log(line)
	thread.validate(deck_manager.hand())
	_rebuild_hand_tiles()
	_refresh_word_composer(word_input.text)
	speed_timer.start()
	_enter_player_input()


func _enter_player_input() -> void:
	_state = State.PLAYER_INPUT
	word_input.editable = true
	submit_button.disabled = false
	autocorrect_button.disabled = false
	_refresh_redraw_button()
	_refresh_boost_buttons()
	_focus_word_input()


func _focus_word_input() -> void:
	word_input.grab_focus()


func _restore_composer_after_pause() -> void:
	if _state == State.PLAYER_INPUT:
		call_deferred("_focus_word_input")


func _on_text_submitted(_text: String) -> void:
	if _state == State.THREAD_CHOICE:
		skip_thread()
		return
	_on_submit()


func _on_submit() -> void:
	if _state != State.PLAYER_INPUT:
		return
	# The deadline is judged by when the player submitted, not by how
	# long validation takes.
	var submitted_msec: int = speed_timer.now_msec()
	var parsed: Dictionary = PunctuationCatalog.split_marks(
		word_input.text
	)
	var word: String = parsed["word"]
	var typed_marks: Array[String] = parsed["marks"]
	var marks: Array[String] = _armed_marks(typed_marks)
	var verdict: Dictionary = _check_cast(word, typed_marks)
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
	autocorrect_button.disabled = true
	suggestion_menu.hide()
	feedback_label.text = ""
	_resolve_word(word, swift, marks)


# Dictionary rules first, then carried punctuation and forbidding
# rules such as amnesia, each refusing without using the turn.
func _check_cast(word: String, typed_marks: Array[String]) -> Dictionary:
	var verdict: Dictionary = validator.validate(word, required_pos)
	if not verdict["valid"]:
		return verdict
	for mark: String in typed_marks:
		if RunState.punctuation_count(mark) <= 0:
			return {"valid": false, "reason": "You carry no %s." % mark}
	var broken: Dictionary = WordRules.first_forbidden(
		rule_tracker.active_rules(), word
	)
	if not broken.is_empty():
		return {"valid": false, "reason": WordRules.describe(broken)}
	return verdict


# Typed marks plus an armed button, limited to marks actually carried.
func _armed_marks(typed_marks: Array[String]) -> Array[String]:
	var marks: Array[String] = []
	for mark: String in typed_marks:
		if not marks.has(mark):
			marks.append(mark)
	var exclamation: String = PunctuationCatalog.EXCLAMATION
	if _exclaim_armed and not marks.has(exclamation):
		marks.append(exclamation)
	var carried: Array[String] = []
	for mark: String in marks:
		if RunState.punctuation_count(mark) > 0:
			carried.append(mark)
	return carried


func _on_dev_kill_pressed() -> void:
	if _state in [State.WON, State.LOST] or enemy == null \
			or not enemy.is_alive():
		return
	word_input.editable = false
	submit_button.disabled = true
	enemy.take_damage(999999.0)


func _resolve_word(
	word: String, swift: bool = false, marks: Array[String] = []
) -> void:
	var split: Dictionary = deck_manager.split_word(
		word, conditions, thread.threaded()
	)
	var drawn: Array[LetterStats] = split["drawn"]
	var undrawn: Array[String] = split["undrawn"]
	# A full meter is spent only once the cast is accepted.
	var inspired: bool = _inspire_armed and RunState.spend_inspiration()
	var context: Dictionary = _calculation_context(swift, marks)
	context["inspired"] = inspired
	var result: Dictionary = calculator.calculate(
		word, drawn, undrawn, enemy.tags, required_pos, context
	)
	for mark: String in marks:
		RunState.consume_punctuation(mark)
	_inspire_armed = false
	_exclaim_armed = false
	RunState.add_inspiration(int(result["inspiration_gain"]))
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
	thread.note_accepted(drawn)
	if rule_tracker.after_accepted(result["rules_met"], required_pos):
		_log_rules()
	_selected_tiles = []
	word_input.clear()
	_refresh_status()
	_show_damage_popup(result["damage"])
	enemy.take_damage(result["damage"])
	if not enemy.is_alive():
		return
	if thread.can_thread() and not drawn.is_empty():
		_offer_thread(drawn)
		return
	if not thread.can_thread():
		_log("The thread frays: the Threaded Letter went unused.")
	_finish_thread_choice(drawn, null)


# --- Threading -----------------------------------------------------

func _offer_thread(drawn: Array[LetterStats]) -> void:
	_state = State.THREAD_CHOICE
	_thread_drawn = drawn.duplicate()
	for child: Node in thread_choices.get_children():
		thread_choices.remove_child(child)
		child.queue_free()
	for stats: LetterStats in _thread_drawn:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(52, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 20)
		button.text = stats.letter.to_upper()
		button.tooltip_text = "Keep %s in hand for the next turn.\n%s" % [
			stats.describe(), stats.full_effect_text(),
		]
		button.pressed.connect(choose_thread.bind(stats))
		thread_choices.add_child(button)
	_rebuild_hand_tiles()
	thread_bar.show()
	_focus_word_input()


## Letters the player may thread right now; empty outside the choice.
func thread_candidates() -> Array[LetterStats]:
	if _state != State.THREAD_CHOICE:
		return []
	return _thread_drawn.duplicate()


## Keeps one used instance in hand for the next turn.
func choose_thread(stats: LetterStats) -> void:
	if _state != State.THREAD_CHOICE:
		return
	if not thread.choose(stats, _thread_drawn):
		return
	_log("%s is threaded into your next turn." % stats.tag_text())
	_finish_thread_choice(_thread_drawn, stats)


## Declines to thread; every used letter is spent.
func skip_thread() -> void:
	if _state != State.THREAD_CHOICE:
		return
	_finish_thread_choice(_thread_drawn, null)


func _finish_thread_choice(
	drawn: Array[LetterStats], keep: LetterStats
) -> void:
	thread_bar.hide()
	_thread_drawn = []
	deck_manager.spend_letters(drawn, keep)
	_rebuild_hand_tiles()
	_refresh_status()
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
	thread.validate(deck_manager.hand())
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
	suggestion_menu.hide()
	autocorrect_button.disabled = true
	_selected_tiles = []
	_return_stolen_letters()
	_rebuild_hand_tiles()
	var earned: int = enemy.gold_reward
	# Newly selected Quills begin paying on the next victory.
	earned += int(_relic_system.total_effect("victory_gold"))
	RunState.add_gold(earned)
	RunState.complete_encounter()
	RunState.is_run_active = true
	var notes: Array[String] = RunState.return_pilgrims()
	RunState.begin_victory(enemy.enemy_name, earned, notes)
	EventBus.emit_encounter_won(earned)
	_go(ScenePaths.FIGHT_COMPLETION)


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
	_go(ScenePaths.RUN_LOST)


# --- Redraw --------------------------------------------------------

## Selects or deselects a hand tile for this turn's paid redraw.
func toggle_tile_selection(stats: LetterStats) -> void:
	if _state != State.PLAYER_INPUT or _redraw_used:
		return
	if not deck_manager.hand().has(stats):
		return
	if _selected_tiles.has(stats):
		_selected_tiles.erase(stats)
	else:
		_selected_tiles.append(stats)
	for tile: LetterTile in hand_box.get_children():
		tile.set_selected(_selected_tiles.has(tile.stats))
	_refresh_redraw_button()
	call_deferred("_focus_word_input")


func selected_tiles() -> Array[LetterStats]:
	return _selected_tiles.duplicate()


func redraw_cost(count: int) -> int:
	return count * REDRAW_COST_PER_TILE


## Asks the player to confirm redrawing the selected tiles.
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
	thread.validate(deck_manager.hand())
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


# --- Autocorrect ---------------------------------------------------

## Offers paid spelling corrections for the current input. Finding
## no suggestions costs nothing, and the swift timer keeps running.
func request_autocorrect() -> void:
	var word: String = word_input.text.strip_edges().to_lower()
	if _state != State.PLAYER_INPUT or word.is_empty():
		feedback_label.text = "Type a word to autocorrect."
		return
	if confirmer.is_pending():
		return
	_suggestions = WordNet.spelling_suggestions(
		word, required_pos, validator.played_words()
	)
	_suggestion_source = word
	if _suggestions.is_empty():
		feedback_label.text = "No spelling suggestions for '%s'." % word
		return
	if RunState.gold < AUTOCORRECT_COST:
		feedback_label.text = "Autocorrect costs %dg." % AUTOCORRECT_COST
		return
	suggestion_menu.clear()
	for index: int in _suggestions.size():
		suggestion_menu.add_item(_suggestions[index], index)
	var anchor: Vector2 = autocorrect_button.get_screen_position()
	suggestion_menu.popup(Rect2i(
		Vector2i(anchor) + Vector2i(0, int(autocorrect_button.size.y)),
		Vector2i.ZERO
	))


func current_suggestions() -> Array[String]:
	return _suggestions.duplicate()


## Asks to confirm replacing the input with one suggestion.
func choose_suggestion(index: int) -> void:
	if index < 0 or index >= _suggestions.size():
		return
	var suggestion: String = _suggestions[index]
	confirmer.request(
		"Autocorrect",
		"Replace '%s' with '%s' for %dg? The word is not cast." % [
			_suggestion_source, suggestion, AUTOCORRECT_COST,
		],
		_confirm_autocorrect.bind(
			_turn_number, _suggestion_source, suggestion
		)
	)


func _confirm_autocorrect(
	turn: int, original: String, suggestion: String
) -> void:
	var current: String = word_input.text.strip_edges().to_lower()
	if _state != State.PLAYER_INPUT or turn != _turn_number \
			or current != original:
		feedback_label.text = "That correction no longer applies."
		return
	var still_valid: Dictionary = WordValidator.check_word(
		suggestion, required_pos, validator.played_words()
	)
	if not still_valid["valid"]:
		feedback_label.text = "That correction no longer applies."
		return
	if not RunState.spend_gold(AUTOCORRECT_COST):
		feedback_label.text = "Autocorrect costs %dg." % AUTOCORRECT_COST
		return
	_suggestions = []
	word_input.text = suggestion
	word_input.caret_column = suggestion.length()
	_on_text_changed(suggestion)
	feedback_label.text = ""
	_log("You pay %dg to correct '%s' to '%s'." % [
		AUTOCORRECT_COST, original, suggestion
	])
	_refresh_status()
	call_deferred("_focus_word_input")


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
	var typed: String = PunctuationCatalog.split_marks(new_text)["word"]
	var split: Dictionary = deck_manager.split_word(
		typed, conditions, thread.threaded()
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
	var parsed: Dictionary = PunctuationCatalog.split_marks(raw_word)
	var word: String = parsed["word"]
	if split.is_empty():
		split = deck_manager.split_word(
			word, conditions, thread.threaded()
		)
	var drawn: Array[LetterStats] = split["drawn"]
	var undrawn: Array[String] = split["undrawn"]
	word_tile_board.set_word(word, drawn)
	if word.is_empty() or enemy == null or not enemy.is_alive():
		_set_output_counters(0, 0, 0)
		_set_health_previews(0, 0)
		preview_label.text = _idle_preview_text()
		return
	var swift: bool = _state == State.PLAYER_INPUT \
			and speed_timer.remaining_msec() > 0
	var context: Dictionary = _calculation_context(
		swift, _armed_marks(parsed["marks"])
	)
	context["inspired"] = _inspire_armed \
			and Inspiration.is_full(RunState.inspiration)
	var result: Dictionary = calculator.calculate(
		word, drawn, undrawn, enemy.tags, required_pos, context
	)
	preview_label.text = _preview_text(result)
	_set_output_counters(
		int(round(float(result["damage"]))),
		int(result["heal_amount"]), int(result["gold_bonus"])
	)
	_set_health_previews(
		int(round(float(result["damage"]))), int(result["heal_amount"])
	)


func _calculation_context(
	swift: bool, marks: Array[String] = []
) -> Dictionary:
	var wait_turns: Dictionary = {}
	for stats: LetterStats in deck_manager.hand():
		wait_turns[stats] = deck_manager.waited_turns(stats)
	var rules: Array[Dictionary] = []
	if rule_tracker != null:
		rules = rule_tracker.active_rules()
	return {
		"conditions": conditions,
		"speed_bonus": swift,
		"threaded": thread.threaded(),
		"wait_turns": wait_turns,
		"rules": rules,
		"marks": marks,
	}


# --- Inspiration and punctuation -----------------------------------

## Arms or disarms spending a full meter on the next accepted cast.
func set_inspire_armed(armed: bool) -> void:
	_inspire_armed = armed and _state == State.PLAYER_INPUT \
			and Inspiration.is_full(RunState.inspiration)
	_refresh_boost_buttons()
	_on_text_changed(word_input.text)
	call_deferred("_focus_word_input")


## Arms or disarms a carried ! for the next accepted cast.
func set_exclaim_armed(armed: bool) -> void:
	var carried: int = RunState.punctuation_count(
		PunctuationCatalog.EXCLAMATION
	)
	_exclaim_armed = armed and _state == State.PLAYER_INPUT \
			and carried > 0
	_refresh_boost_buttons()
	_on_text_changed(word_input.text)
	call_deferred("_focus_word_input")


func _refresh_boost_buttons() -> void:
	var input_open: bool = _state == State.PLAYER_INPUT
	var full: bool = Inspiration.is_full(RunState.inspiration)
	inspire_button.disabled = not input_open or not full
	inspire_button.set_pressed_no_signal(_inspire_armed)
	inspire_button.text = "Inspire (%d/%d)" % [
		RunState.inspiration, Inspiration.MAX_POINTS
	]
	if _inspire_armed:
		inspire_button.text = "Inspired!"
	var carried: int = RunState.punctuation_count(
		PunctuationCatalog.EXCLAMATION
	)
	exclaim_button.disabled = not input_open or carried <= 0
	exclaim_button.set_pressed_no_signal(_exclaim_armed)
	exclaim_button.text = "! ×%d%s" % [
		carried, " armed" if _exclaim_armed else ""
	]


# The meter and every rule binding this turn.
func _refresh_guidance() -> void:
	inspiration_label.text = "Inspiration %d / %d" % [
		RunState.inspiration, Inspiration.MAX_POINTS
	]
	inspiration_bar.value = float(RunState.inspiration)
	var lines: Array[String] = []
	if rule_tracker != null:
		for rule: Dictionary in rule_tracker.active_rules():
			lines.append("%s: %s" % [
				WordRules.display_name(rule), WordRules.describe(rule),
			])
	if lines.is_empty():
		lines.append("No word rules bind this fight.")
	rules_label.text = "\n".join(lines)


func _idle_preview_text() -> String:
	var threaded: LetterStats = thread.threaded()
	if threaded != null:
		return "Threaded: %s. Reuse it for +%d Inspiration." % [
			threaded.tag_text(), Inspiration.THREAD_POINTS
		]
	return ""


## Exact effects of the typed word: modifiers with the instances they
## affect, rules met or missed, Inspiration, and armed punctuation.
func _preview_text(result: Dictionary) -> String:
	var parts: Array[String] = []
	for effect: Dictionary in result["modifier_effects"]:
		parts.append(String(effect["text"]))
	for rule_result: Dictionary in result["rule_results"]:
		if rule_result["forbids"]:
			continue
		var status: String = "Rule met:" if rule_result["met"] \
				else "Rule missed (×0.5):"
		parts.append("%s %s" % [status, rule_result["name"]])
	if result["inspired"]:
		parts.append("Inspired ×2")
	for mark: String in result["marks"]:
		parts.append("%s ×%.0f damage" % [
			mark, PunctuationCatalog.damage_multiplier(mark)
		])
	var gain: int = int(result["inspiration_gain"])
	if gain > 0:
		parts.append("Inspiration +%d (%s)" % [
			gain, Inspiration.explain(result)
		])
	return " · ".join(parts)


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
		tile.set_threaded(thread.is_threaded(stats))
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
	_refresh_guidance()
	_refresh_boost_buttons()


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
	if result["inspired"]:
		lines.append("  Inspired! Drawn letters and modifiers doubled.")
	for mark: String in result["marks"]:
		lines.append("  %s ×%.0f final damage." % [
			mark, PunctuationCatalog.damage_multiplier(mark)
		])
	for rule_result: Dictionary in result["rule_results"]:
		if not rule_result["forbids"] and not rule_result["met"]:
			lines.append("  Missed %s: ×%.1f damage." % [
				rule_result["name"], WordRules.UNMET_DAMAGE_FACTOR
			])
	for effect: Dictionary in result["modifier_effects"]:
		lines.append("  " + String(effect["text"]))
	if int(result["inspiration_gain"]) > 0:
		lines.append("  Inspiration +%d (%s)." % [
			result["inspiration_gain"], Inspiration.explain(result)
		])
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


func _go(scene_path: String) -> void:
	if navigate.is_valid():
		navigate.call(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func _log(message: String) -> void:
	log_label.append_text(message + "\n")
