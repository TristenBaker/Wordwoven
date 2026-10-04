extends Control
## Runs one combat encounter as a turn state machine: the player
## drafts a word, the enemy takes the damage, then retaliates.
## Delegates the rules to DeckManager, WordValidator,
## DamageCalculator, and EnemyFactory child nodes and keeps only
## the flow and the screen updates here.

const ENCOUNTER_MODIFIERS = preload("res://scripts/modifiers/encounter_modifier.gd")
var _encounter_modifier: Dictionary = {}

enum State {
	PLAYER_INPUT,
	RESOLVING,
	ENEMY_TURN,
	WON,
	LOST,
}

const LETTER_TILE_SCENE: PackedScene = \
		preload("res://scenes/combat/letter_tile.tscn")

# Pause before the enemy's retaliation, in seconds.
const ENEMY_TURN_DELAY: float = 0.7
const POST_RETALIATION_DELAY: float = 0.4
# Shorter pause once the party has finished its actions.
const PARTY_SETTLE_DELAY: float = 0.25
# Fade to black between the enemy's death and the victory tale.
const VICTORY_FADE_TIME: float = 0.35

const COUNTER_FEEDBACK_DURATION: float = 1.8
const COUNTER_FEEDBACK_COLOR: Color = Color(1.0, 0.86, 0.48)

const PROMPT_ORDER: Array[String] = ["n", "v", "a", "r"]

# Adding background array
var backgrounds: Array[Texture2D] = [
	preload("res://art/backgrounds/desert.png"),
	preload("res://art/backgrounds/new_forest.png"),
	preload("res://art/backgrounds/rocky_mountains.png"),
	preload("res://art/backgrounds/sea.png"),
	preload("res://art/backgrounds/sky.png"),
	preload("res://art/backgrounds/tundra.png"),
	preload("res://art/backgrounds/volcano.png")
]
var required_pos: String = "n"
var _state: State = State.PLAYER_INPUT
var _relic_system: RelicSystem = RelicSystem.new()
var _previous_drawn: Array[LetterStats] = []
var _damage_popup_tween: Tween = null
var _player_health_impact_tween: Tween = null
var _retaliation_visual_generation: int = 0
var _player_health_impact_origin: Vector2
var _player_health_impact_color: Color
var cold := preload("res://scripts/combat/tundra_cold.gd").new()
var heat_meter: PanelContainer
var _last_allowed_text: String = ""
var _turn_elapsed_seconds: float = 0.0
var _preview_refresh_accumulator: float = 0.0
var _feedback_generation: int = 0
var _feedback_default_color: Color
var _feedback_backing: Panel
var _effectiveness_timer: Timer
var _feedback_kind: String = ""
var _preview_feedback_generation: int = 0

# Adding background variable
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
@onready var prompt_label: Label = $Layout/InputArea/InputRow/PromptLabel
@onready var timer_label: Label = $Layout/StatusArea/TimerLabel
@onready var log_label: RichTextLabel = \
		$Layout/SidePanel/ChronicleContent/LogLabel
@onready var side_panel: PanelContainer = $Layout/SidePanel
@onready var log_toggle_button: Button = $Layout/LogToggleButton
@onready var party_stage: PartyStage = $Layout/PartyStage
@onready var transition_fade: ColorRect = $TransitionFade
@onready var player_health_bar: ProgressBar = \
		$Layout/StatusArea/PlayerHealthBar
@onready var player_health_label: Label = \
		$Layout/StatusArea/PlayerHealthBar/PlayerHealthLabel
@onready var player_heal_preview: ColorRect = \
		$Layout/StatusArea/PlayerHealthBar/HealPreview
@onready var gold_label: Label = $Layout/StatusArea/GoldLabel
@onready var stage_label: Label = $Layout/StatusArea/StageLabel


func _ready() -> void:
	_feedback_default_color = feedback_label.get_theme_color("font_color")
	# Reserve two lines so brief counter messages do not move the word prompt.
	feedback_label.custom_minimum_size.y = 2.0 * feedback_label.get_theme_font("font").get_height(
		feedback_label.get_theme_font_size("font_size")
	) + feedback_label.get_theme_constant("line_spacing")
	_setup_feedback_banner()
	# Enter normally makes a LineEdit release editing focus. The field is the
	# invisible keyboard source for the tile board, so retain that focus and
	# let the combat state machine decide when input is unavailable instead.
	word_input.keep_editing_on_text_submit = true
	submit_button.pressed.connect(_on_submit)
	word_input.text_submitted.connect(_on_text_submitted)
	word_input.text_changed.connect(_on_text_changed)
	word_tile_board.focus_requested.connect(_focus_word_input)
	pause_menu.resumed.connect(_restore_composer_after_pause)
	dev_kill_button.pressed.connect(_on_dev_kill_pressed)
	log_toggle_button.toggled.connect(_on_log_toggled)
	enemy.died.connect(_on_enemy_died)
	EventBus.player_damaged.connect(_on_player_damage_applied)
	heat_meter = PanelContainer.new()
	heat_meter.set_script(preload("res://scripts/ui/heat_meter.gd"))
	$Layout/InputArea.add_child(heat_meter)
	$Layout/InputArea.move_child(heat_meter, 1)
	_start_encounter()


func _process(delta: float) -> void:
	if _state != State.PLAYER_INPUT:
		return
	_turn_elapsed_seconds += delta
	_preview_refresh_accumulator += delta
	_update_timer_display()
	if _preview_refresh_accumulator >= 0.1:
		_preview_refresh_accumulator = 0.0
		if not word_input.text.strip_edges().is_empty():
			_refresh_word_composer(word_input.text)


func _start_encounter() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()
		
	# Randomize the environment
	_randomize_background()
		
	required_pos = PROMPT_ORDER[
		(RunState.encounter_index - 1) % PROMPT_ORDER.size()
	]
	_refresh_prompt()
	validator.start_encounter()
	deck_manager.start_encounter()
	cold.reset(RunState.selected_biome == "tundra")
	heat_meter.visible = cold.enabled
	if cold.enabled:
		# Reserve vertical room for the meter without crowding prompt/feedback into the hand.
		$Layout/InputArea.offset_top -= 48.0
		$Layout/InputArea.offset_bottom -= 48.0
	_refresh_cold()
	var spawn_data: Dictionary = _pick_spawn_data()
	var preparation: Dictionary = RunState.take_encounter_modifier(spawn_data["id"])
	_encounter_modifier = ENCOUNTER_MODIFIERS.definition(preparation.get("modifier_id", ""))
	spawn_data = ENCOUNTER_MODIFIERS.apply_spawn(spawn_data, _encounter_modifier)
	_refresh_modifier_indicator()
	enemy.setup(spawn_data)
	EventBus.emit_encounter_started(spawn_data)
	_rebuild_hand_tiles()
	_refresh_status()
	_refresh_word_composer("")
	_log("A %s appears! Its nature: %s" % [
		spawn_data["name"], " • ".join(spawn_data["tags"])
	])
	_enter_player_input()
	_log("Opposites and thematic counters deal extra damage.")

# Adding function for randomizing backgrounds
func _randomize_background() -> void:
	# Keep the existing random draw so other randomized systems are unaffected.
	background.texture = backgrounds.pick_random()
	if RunState.selected_biome == "tundra":
		background.texture = load(
			"res://art/backgrounds/Tundra Biome/T%d.png"
			% RunState.encounter_index
		)

func _pick_spawn_data() -> Dictionary:
	var enemy_id: String = RunState.next_enemy_id
	RunState.next_enemy_id = ""
	if RunState.selected_biome == "tundra":
		var allowed: Array[String] = factory.ids_for_stage(RunState.encounter_index)
		if not allowed.has(enemy_id):
			enemy_id = allowed.pick_random()
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

func _enter_player_input(reset_timer: bool = true) -> void:
	if _state in [State.WON, State.LOST]:
		return
	_state = State.PLAYER_INPUT
	if reset_timer:
		_turn_elapsed_seconds = 0.0
		_preview_refresh_accumulator = 0.0
	_update_timer_display()
	word_input.editable = true
	submit_button.disabled = false
	_refresh_cold()
	_focus_word_input()
	call_deferred("_focus_word_input")


func _focus_word_input() -> void:
	if _state != State.PLAYER_INPUT or not word_input.editable or get_tree().paused:
		return
	word_input.grab_focus()
	word_input.edit()


func _restore_composer_after_pause() -> void:
	if _state == State.PLAYER_INPUT:
		call_deferred("_focus_word_input")


func _on_text_submitted(_text: String) -> void:
	_on_submit()


func _on_submit() -> void:
	if _state != State.PLAYER_INPUT or get_tree().paused:
		return
	var word: String = word_input.text.strip_edges().to_lower()
	var verdict: Dictionary = validator.validate(word, required_pos)
	var blocked: String = cold.blocked_letter(word, deck_manager.hand())
	if not blocked.is_empty():
		verdict = {"valid": false, "reason": "%s is frozen — thaw it for %d Heat" % [blocked, cold.THAW_COST]}
	if not verdict["valid"]:
		EventBus.emit_word_rejected(word, verdict["reason"])
		# A rejected word never starts a turn. Reset the composer immediately,
		# then defer focus restoration so Enter/button submission cannot leave
		# the visually hidden LineEdit unfocused.
		_reset_word_composer()
		_set_feedback(verdict["reason"])
		_enter_player_input(false)
		call_deferred("_focus_word_input")
		return
	cold.accept_word()
	_refresh_cold()
	_state = State.RESOLVING
	word_input.editable = false
	submit_button.disabled = true
	_set_feedback("")
	_resolve_word(word)


func _on_dev_kill_pressed() -> void:
	if _state in [State.WON, State.LOST] or enemy == null \
			or not enemy.is_alive():
		return
	word_input.editable = false
	submit_button.disabled = true
	enemy.take_damage(999999.0)


func _resolve_word(word: String) -> void:
	var split: Dictionary = deck_manager.split_word(word)
	var drawn: Array[LetterStats] = split["drawn"]
	var undrawn: Array[String] = split["undrawn"]
	var result: Dictionary = calculator.calculate(
		word, drawn, undrawn, enemy.tags, required_pos,
		_turn_elapsed_seconds
	)
	# Apply only the encounter-local fate factor; semantic/counter data stays intact.
	result["damage"] = float(result["damage"]) * ENCOUNTER_MODIFIERS.player_factor(_encounter_modifier)
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
	_show_counter_feedback(result)
	# The typed letters act before the hand changes under them.
	var performing: bool = party_stage.perform_word(enemy.strike_point())
	# Current-word numbers are frozen before the used letters grow.
	for stats: LetterStats in drawn:
		stats.gain_use_level()
	if not drawn.is_empty():
		EventBus.emit_deck_changed()
	_advance_prompt()
	deck_manager.spend_letters(drawn)
	_rebuild_hand_tiles()
	_reset_word_composer()
	_refresh_status()
	if performing:
		await party_stage.impact_landed
	_show_damage_popup(result["damage"])
	enemy.take_damage(result["damage"])
	if enemy.is_alive():
		_enemy_turn()


func _enemy_turn() -> void:
	_state = State.ENEMY_TURN
	var delay: float = ENEMY_TURN_DELAY
	if party_stage.is_performing():
		await party_stage.performance_finished
		delay = PARTY_SETTLE_DELAY
	_retaliation_visual_generation += 1
	_begin_retaliation_lunge(delay, _retaliation_visual_generation)
	await get_tree().create_timer(delay, false).timeout
	if _state != State.ENEMY_TURN:
		return
	_log("The %s retaliates for %d damage!" % [
		enemy.enemy_name, enemy.attack
	])
	var health_before: int = RunState.player_health
	enemy.finish_retaliation_lunge()
	RunState.damage_player(enemy.attack)
	_show_retaliation_message(health_before - RunState.player_health)
	_refresh_status()
	if RunState.player_health <= 0:
		_on_player_died()
		return
	await get_tree().create_timer(POST_RETALIATION_DELAY, false).timeout
	if _state == State.ENEMY_TURN:
		var newly_frozen: LetterStats = cold.freeze_after_turn(deck_manager.hand())
		_refresh_cold(newly_frozen)
		if newly_frozen != null:
			_log("The cold freezes %s. Thaw it for %d Heat." % [newly_frozen.letter.to_upper(), cold.THAW_COST])
		# Defer once so a just-finished animation or button event cannot claim
		# focus from the hidden LineEdit after the next player turn opens.
		call_deferred("_enter_player_input")


func _begin_retaliation_lunge(delay: float, generation: int) -> void:
	# Fit the visual windup inside the existing pause; damage timing is untouched.
	await get_tree().create_timer(maxf(delay - 0.15, 0.0), false).timeout
	if generation != _retaliation_visual_generation or _state != State.ENEMY_TURN or not enemy.is_alive():
		return
	var player_target: Vector2 = party_stage.get_global_transform() * Vector2(
		party_stage.line_start_x + party_stage.slot_spacing * 2.0, party_stage.ground_y - 28.0
	)
	enemy.begin_retaliation_lunge(player_target)


func _show_retaliation_message(damage_dealt: int) -> void:
	if damage_dealt <= 0:
		return
	var message := Label.new()
	message.name = "RetaliationMessage"
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.z_index = 11
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_override("font", preload("res://assets/Fonts/Junicode.ttf"))
	message.add_theme_font_size_override("font_size", 21)
	message.add_theme_color_override("font_color", Color(1.0, 0.83, 0.66))
	message.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.045, 0.95))
	message.add_theme_color_override("font_shadow_color", Color(0.005, 0.01, 0.02, 0.9))
	message.add_theme_constant_override("outline_size", 4)
	message.add_theme_constant_override("shadow_offset_y", 2)
	$Layout.add_child(message)
	message.size = Vector2(440.0, 80.0)
	message.text = "%s STRIKES!\n%d DAMAGE" % [enemy.enemy_name.to_upper(), damage_dealt]
	var area: Rect2 = enemy.sprite.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	message.global_position = Vector2(
		clampf(area.get_center().x - message.size.x * 0.5, 12.0, viewport_size.x - message.size.x - 12.0),
		clampf(maxf(area.position.y - 64.0, enemy.info_box.get_global_rect().end.y + 12.0), 12.0, viewport_size.y - message.size.y - 12.0)
	)
	var fade: Tween = message.create_tween().set_parallel(true)
	fade.tween_property(message, "position:y", message.position.y - 12.0, 1.0)
	fade.tween_property(message, "modulate:a", 0.0, 0.35).set_delay(0.65)
	fade.chain().tween_callback(message.queue_free)


func _on_enemy_died() -> void:
	if _state == State.WON:
		return
	_state = State.WON
	var earned: int = enemy.gold_reward
	# Newly selected Quills begin paying on the next victory.
	earned += int(_relic_system.total_effect("victory_gold"))
	RunState.add_gold(earned)
	RunState.complete_encounter(enemy.enemy_id)
	RunState.is_run_active = true
	RunState.begin_victory(enemy.enemy_name, earned)
	EventBus.emit_encounter_won(earned)
	word_input.editable = false
	submit_button.disabled = true
	await _play_victory_transition()
	get_tree().change_scene_to_file(ScenePaths.FIGHT_COMPLETION)


# Every party action finishes before the enemy dissolves, then the
# screen fades out into the victory tale.
func _play_victory_transition() -> void:
	if party_stage.is_performing():
		await party_stage.performance_finished
	await enemy.play_death()
	var fade: Tween = create_tween()
	fade.tween_property(
		transition_fade, "color:a", 1.0, VICTORY_FADE_TIME
	)
	await fade.finished


func _on_player_died() -> void:
	_state = State.LOST
	get_tree().change_scene_to_file(ScenePaths.RUN_LOST)


# --- Screen updates ------------------------------------------------

func _setup_feedback_banner() -> void:
	# A child backing leaves the reserved VBox slot and existing controls fixed.
	_feedback_backing = Panel.new()
	_feedback_backing.show_behind_parent = true
	_feedback_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_label.add_child(_feedback_backing)
	_feedback_backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback_backing.offset_left = -8.0
	_feedback_backing.offset_right = 8.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.085, 0.82)
	style.border_color = Color(0.48, 0.39, 0.24, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_feedback_backing.add_theme_stylebox_override("panel", style)
	_feedback_backing.hide()
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Understated prompt backing; as a child it cannot resize the Prompt/Cast row.
	var prompt_backing := Panel.new()
	prompt_backing.name = "PromptBacking"
	prompt_backing.show_behind_parent = true
	prompt_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.add_child(prompt_backing)
	prompt_backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_backing.offset_left = -8.0
	prompt_backing.offset_right = 8.0
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.025, 0.045, 0.085, 0.68)
	prompt_style.border_color = Color(0.48, 0.39, 0.24, 0.55)
	prompt_style.set_border_width_all(1)
	prompt_style.set_corner_radius_all(4)
	prompt_backing.add_theme_stylebox_override("panel", prompt_style)
	_effectiveness_timer = Timer.new()
	_effectiveness_timer.one_shot = true
	_effectiveness_timer.wait_time = 0.2
	add_child(_effectiveness_timer)
	_effectiveness_timer.timeout.connect(_update_effectiveness_preview)


func _set_feedback(message: String, successful_counter: bool = false, kind: String = "warning") -> void:
	# Every writer invalidates both old result expiry and pending typing previews.
	_feedback_generation += 1
	_feedback_kind = "" if message.is_empty() else ("result" if successful_counter else kind)
	feedback_label.text = message
	var color: Color = _feedback_default_color
	if successful_counter:
		color = COUNTER_FEEDBACK_COLOR
	elif kind == "preview":
		color = Color(0.86, 0.79, 0.63)
	feedback_label.add_theme_color_override("font_color", color)
	_feedback_backing.visible = not message.is_empty()


func _queue_effectiveness_preview() -> void:
	if _state != State.PLAYER_INPUT:
		return
	_set_feedback("")
	if word_input.text.strip_edges().is_empty():
		return
	_preview_feedback_generation = _feedback_generation
	_effectiveness_timer.start()


func _update_effectiveness_preview() -> void:
	if _state != State.PLAYER_INPUT or _preview_feedback_generation != _feedback_generation:
		return
	if enemy == null or not enemy.is_alive():
		return
	var word: String = word_input.text.strip_edges().to_lower()
	if not cold.blocked_letter(word, deck_manager.hand()).is_empty():
		return
	# validate() only reads the lexicon and played-word list; never mark_played().
	if not validator.validate(word, required_pos)["valid"]:
		return
	# These calculator helpers read CounterScorer/relic data without resolving a turn.
	# Reusing selection also preserves the real calculation's multi-tag tie rules.
	var counter: Dictionary = calculator._best_tag_counter(word, enemy.tags, required_pos)
	if float(counter.get("score", 0.0)) <= 0.0:
		var traits: Array[String] = []
		for tag: String in enemy.tags:
			traits.append(tag.to_upper())
		var message: String = "THE WORD FINDS NO WEAKNESS"
		if not traits.is_empty():
			message += "\nSeek a word that opposes %s" % " or ".join(traits)
		_set_feedback(message, false, "preview")
		return
	var effectiveness: float = clampf(float(counter["score"]) + _relic_system.total_effect("counter_bonus"), 0.0, 1.0)
	var multiplier: float = calculator._semantic_multiplier(counter, effectiveness, _relic_system.total_effect("damage_multiplier"))
	var emphasis: String = "SUPER EFFECTIVE" if multiplier >= 2.0 else "EFFECTIVE"
	_set_feedback("✦ %s ✦\nCounters %s" % [emphasis, String(counter["tag"]).to_upper()], false, "preview")


func _show_counter_feedback(result: Dictionary) -> void:
	var counter: Dictionary = result.get("counter", {})
	if counter.get("strategy", "none") not in [
		"wordnet antonym", "thematic counter", "counter synonym",
	] or float(counter.get("score", 0.0)) <= 0.0:
		return
	var tag: String = counter.get("tag", "")
	var multiplier: float = result.get("semantic_multiplier", 0.0)
	if tag.is_empty() or multiplier <= 1.0:
		return
	var emphasis: String = "SUPER EFFECTIVE!" if multiplier >= 2.0 else "EFFECTIVE!"
	# Keep fractional relic bonuses visible, retaining at least one decimal.
	var multiplier_text: String = ("%.2f" % multiplier).trim_suffix("0")
	_set_feedback("✦ %s  ×%s ✦\n%s counters %s" % [
		emphasis, multiplier_text, String(result["word"]).to_upper(), tag.to_upper(),
	], true)
	var generation: int = _feedback_generation
	await get_tree().create_timer(COUNTER_FEEDBACK_DURATION, false).timeout
	if generation == _feedback_generation:
		_set_feedback("")


func _on_log_toggled(shown: bool) -> void:
	side_panel.visible = shown
	log_toggle_button.text = "Hide Log" if shown else "Show Log"


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


func _on_text_changed(new_text: String) -> void:
	_effectiveness_timer.stop()
	var blocked: String = cold.blocked_letter(new_text, deck_manager.hand())
	if not blocked.is_empty():
		var caret: int = word_input.caret_column
		word_input.text = _last_allowed_text
		word_input.caret_column = mini(caret, _last_allowed_text.length())
		_effectiveness_timer.stop()
		_set_feedback("%s is frozen — thaw it for %d Heat" % [blocked, cold.THAW_COST])
		return
	_queue_effectiveness_preview()
	_last_allowed_text = new_text
	var typing: bool = not new_text.strip_edges().is_empty()
	var split: Dictionary = deck_manager.split_word(
		new_text.strip_edges().to_lower()
	)
	var drawn: Array[LetterStats] = split["drawn"]
	_refresh_word_composer(new_text, split)
	_animate_new_tile_selections(drawn)
	_previous_drawn = drawn.duplicate()
	party_stage.sync_letters(drawn)
	for tile: LetterTile in hand_box.get_children():
		tile.set_used(drawn.has(tile.stats), typing)


func _reset_word_composer() -> void:
	# Reset presentation explicitly; clearing must not replace confirmed feedback.
	_effectiveness_timer.stop()
	_preview_feedback_generation = -1
	var signals_blocked: bool = word_input.is_blocking_signals()
	word_input.set_block_signals(true)
	word_input.clear()
	word_input.set_block_signals(signals_blocked)
	_last_allowed_text = ""
	_previous_drawn.clear()
	_refresh_word_composer("")
	var empty_drawn: Array[LetterStats] = []
	# perform_word() has already detached the accepted word's active performers.
	party_stage.sync_letters(empty_drawn)
	for tile: LetterTile in hand_box.get_children():
		tile.set_used(false, false)


func _refresh_word_composer(raw_word: String, split: Dictionary = {}) -> void:
	var word: String = raw_word.strip_edges().to_lower()
	if split.is_empty():
		split = deck_manager.split_word(word)
	var drawn: Array[LetterStats] = split["drawn"]
	var undrawn: Array[String] = split["undrawn"]
	word_tile_board.set_word(word, drawn)
	if word.is_empty() or enemy == null or not enemy.is_alive():
		_set_output_counters(0, 0, 0)
		_set_health_previews(0, 0)
		return
	# Keep existing healing/gold hints, but never predict damage while typing.
	var healing: int = calculator._healer_health(drawn)
	_set_output_counters(0, healing, calculator._rogue_gold(drawn))
	damage_output.text = "—"
	_set_health_previews(0, healing)


func _set_output_counters(damage: int, healing: int, gold: int) -> void:
	damage_output.text = str(damage)
	heal_output.text = str(healing)
	gold_output.text = str(gold)


func _update_timer_display() -> void:
	var remaining: float = maxf(
		DamageCalculator.SPEED_BONUS_DURATION - _turn_elapsed_seconds,
		0.0
	)
	var multiplier: float = calculator.speed_multiplier(
		_turn_elapsed_seconds
	)
	timer_label.text = "Quick-cast: %.1fs  •  Damage ×%.2f" % [
		remaining, multiplier,
	]


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
		tile.activated.connect(_on_hand_tile_activated)
	_refresh_cold()


func _refresh_cold(newly_frozen: LetterStats = null) -> void:
	deck_manager.frozen_letters = cold.frozen
	if heat_meter == null:
		return
	heat_meter.refresh(cold.heat, cold.turns, not cold.frozen.is_empty())
	for tile: LetterTile in hand_box.get_children():
		tile.set_frozen(cold.frozen.has(tile.stats), cold.heat >= cold.THAW_COST,
			tile.stats == newly_frozen)


func _on_hand_tile_activated(tile: LetterTile) -> void:
	if _state != State.PLAYER_INPUT or get_tree().paused:
		return
	if cold.frozen.has(tile.stats):
		if cold.thaw(tile.stats):
			tile.set_frozen(false, false, true)
			_refresh_cold()
			_set_feedback("")
			_on_text_changed(word_input.text)
		else:
			tile.deny_thaw()
			heat_meter.pulse(true)
			_set_feedback("Thaw needs %d Heat. Each valid word gives +%d." % [cold.THAW_COST, cold.HEAT_PER_WORD])
	_focus_word_input()


func _on_player_damage_applied(amount: float) -> void:
	# RunState emits this only after applying damage; attack announcements do not trigger it.
	if amount <= 0.0:
		return
	if _player_health_impact_tween != null:
		_player_health_impact_tween.kill()
		_restore_player_health_impact()
	_player_health_impact_origin = player_health_bar.position
	_player_health_impact_color = player_health_bar.modulate
	player_health_bar.modulate = _player_health_impact_color * Color(1.15, 0.78, 0.72, 1.0)
	_player_health_impact_tween = create_tween()
	# Small, diminishing horizontal whacks; always use the saved origin, never accumulated offsets.
	_player_health_impact_tween.tween_method(_set_player_health_impact_offset, 0.0, 6.0, 0.04)
	_player_health_impact_tween.tween_method(_set_player_health_impact_offset, 6.0, -5.0, 0.05)
	_player_health_impact_tween.tween_method(_set_player_health_impact_offset, -5.0, 3.0, 0.05)
	_player_health_impact_tween.tween_method(_set_player_health_impact_offset, 3.0, -2.0, 0.06)
	_player_health_impact_tween.tween_method(_set_player_health_impact_offset, -2.0, 0.0, 0.10)
	_player_health_impact_tween.parallel().tween_property(
		player_health_bar, "modulate", _player_health_impact_color, 0.10
	)
	_player_health_impact_tween.finished.connect(_restore_player_health_impact)


func _set_player_health_impact_offset(offset: float) -> void:
	player_health_bar.position = _player_health_impact_origin + Vector2(offset, 0.0)


func _restore_player_health_impact() -> void:
	player_health_bar.position = _player_health_impact_origin
	player_health_bar.modulate = _player_health_impact_color
	_player_health_impact_tween = null


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
		"  power %.1f × length %.1f × %s %.2f × tag %.2f × speed %.2f" % [
			result["base_power"],
			result["length_multiplier"],
			WordNet.pos_name(result["pos"]),
			result["pos_multiplier"],
			result["semantic_multiplier"],
			result["speed_multiplier"],
		]
	)
	lines.append("  answered in %.1f seconds" % result["elapsed_seconds"])
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


func _refresh_modifier_indicator() -> void:
	var indicator: Label = $Layout/FateIndicator
	indicator.visible = not _encounter_modifier.is_empty()
	if indicator.visible:
		indicator.text = "FATE — %s\n%s" % [
			_encounter_modifier.name, _encounter_modifier.effect,
		]
		indicator.modulate = Color("ead69b") if _encounter_modifier.beneficial else Color("dda59a")
