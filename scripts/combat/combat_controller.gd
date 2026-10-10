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

# Pause before and after the enemy's retaliation, in seconds.
const ENEMY_TURN_DELAY: float = 0.7
# Shorter pause once the party has finished its actions.
const PARTY_SETTLE_DELAY: float = 0.25
# Fade to black between the enemy's death and the victory tale.
const VICTORY_FADE_TIME: float = 0.35

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
var _retaliation_reduction: int = 0
var _guard: int = 0
var cold := preload("res://scripts/combat/tundra_cold.gd").new()
var heat_meter: PanelContainer
var strike_fx: EnemyStrikeFx
var _last_allowed_text: String = ""
var _turn_elapsed_seconds: float = 0.0
var _preview_refresh_accumulator: float = 0.0
var _health_bar_shake := preload("res://scripts/ui/control_shake.gd").new()

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
		$Layout/WordInput
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
		$Layout/FeedbackBanner/Content/FeedbackLabel
@onready var prompt_label: Label = $Layout/FeedbackBanner/Content/PromptLabel
@onready var feedback_banner: PanelContainer = $Layout/FeedbackBanner
@onready var effectiveness_indicator: PanelContainer = $Layout/EffectivenessIndicator
@onready var log_label: RichTextLabel = \
		$Layout/SidePanel/LogLabel
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
@onready var timer_label: Label = $Layout/StatusArea/TimerLabel
@onready var gold_label: Label = $Layout/StatusArea/GoldLabel
@onready var stage_label: Label = $Layout/StatusArea/StageLabel


func _ready() -> void:
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
	party_stage.gold_stolen.connect(_on_gold_stolen)
	heat_meter = PanelContainer.new()
	heat_meter.set_script(preload("res://scripts/ui/heat_meter.gd"))
	$Layout/InputArea.add_child(heat_meter)
	$Layout/InputArea.move_child(heat_meter, 1)
	# Above the battlefield, below the fade and overlays.
	strike_fx = EnemyStrikeFx.new()
	add_child(strike_fx)
	move_child(strike_fx, $Layout.get_index() + 1)
	submit_button.item_rect_changed.connect(_queue_feedback_layout)
	$Layout/InputArea.item_rect_changed.connect(_queue_feedback_layout)
	feedback_banner.minimum_size_changed.connect(_queue_feedback_layout)
	effectiveness_indicator.minimum_size_changed.connect(_queue_feedback_layout)
	_start_encounter()
	_queue_feedback_layout()


func _exit_tree() -> void:
	_health_bar_shake.cancel()


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
	# Consume the matching preparation once; the applied fate lives with this scene.
	var preparation: Dictionary = RunState.take_encounter_modifier(spawn_data["id"])
	_encounter_modifier = ENCOUNTER_MODIFIERS.definition(preparation.get("modifier_id", ""))
	var base_spawn: Dictionary = spawn_data
	spawn_data = ENCOUNTER_MODIFIERS.apply_spawn(base_spawn, _encounter_modifier)
	enemy.setup(spawn_data)
	$Layout/ActiveModifierPanel.show_modifier(
		String(preparation.get("word", "")), _encounter_modifier,
		base_spawn, spawn_data, ENCOUNTER_MODIFIERS.player_factor(_encounter_modifier)
	)
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
	_state = State.PLAYER_INPUT
	if reset_timer:
		_turn_elapsed_seconds = 0.0
		_preview_refresh_accumulator = 0.0
	_update_timer_display()
	word_input.editable = true
	submit_button.disabled = false
	_refresh_cold()
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
	effectiveness_indicator.clear()
	var word: String = word_input.text.strip_edges().to_lower()
	var verdict: Dictionary = validator.validate(word, required_pos)
	var blocked: String = cold.blocked_letter(word, deck_manager.hand())
	if not blocked.is_empty():
		verdict = {"valid": false, "reason": "%s is frozen — thaw it for %d Heat" % [blocked, cold.THAW_COST]}
	if not verdict["valid"]:
		_set_player_feedback(verdict["reason"])
		EventBus.emit_word_rejected(word, verdict["reason"])
		# A rejected word never starts a turn. Reset the composer immediately,
		# then defer focus restoration so Enter/button submission cannot leave
		# the visually hidden LineEdit unfocused.
		word_input.clear()
		_enter_player_input(false)
		call_deferred("_focus_word_input")
		return
	cold.accept_word()
	_refresh_cold()
	_state = State.RESOLVING
	word_input.editable = false
	submit_button.disabled = true
	_set_player_feedback("")
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
		enemy.affinities, true, _turn_elapsed_seconds
	)
	# Restore the original encounter-only final damage factor.
	result["damage"] = float(result["damage"]) * ENCOUNTER_MODIFIERS.player_factor(_encounter_modifier)
	validator.mark_played(word)
	RunState.record_word(
		word, enemy.enemy_name, enemy.tags, result["damage"],
		required_pos
	)
	_apply_elemental_effects(result)
	EventBus.emit_word_resolved(result)
	_log(_describe_result(result))
	# The typed letters act before the hand changes under them.
	var performing: bool = party_stage.perform_word(enemy.strike_point())
	# Current-word numbers are frozen before the used letters grow.
	if not RunState.use_itemized_letters:
		for stats: LetterStats in drawn:
			stats.gain_use_level()
	if not drawn.is_empty() and not RunState.use_itemized_letters:
		EventBus.emit_deck_changed()
	_advance_prompt()
	deck_manager.spend_letters(drawn)
	_rebuild_hand_tiles()
	word_input.clear()
	_refresh_status()
	effectiveness_indicator.show_result(result)
	if performing:
		await party_stage.impact_landed
	_show_damage_popup(result["damage"])
	enemy.take_damage(result["damage"])
	if enemy.is_alive():
		_enemy_turn()


func _on_gold_stolen(amount: int) -> void:
	RunState.add_gold(amount)
	_refresh_status()


func _enemy_turn() -> void:
	_state = State.ENEMY_TURN
	var delay: float = ENEMY_TURN_DELAY
	if party_stage.is_performing():
		await party_stage.performance_finished
		delay = PARTY_SETTLE_DELAY
	await get_tree().create_timer(delay).timeout
	if _state != State.ENEMY_TURN:
		return
	var burn_damage: float = enemy.consume_burn()
	if burn_damage > 0.0:
		_log("Burn scorches the %s for %.0f damage." % [
			enemy.enemy_name, burn_damage
		])
	if not enemy.is_alive():
		return
	var poison_damage: float = enemy.consume_poison()
	if poison_damage > 0.0:
		_log("Poison withers the %s for %.0f damage." % [
			enemy.enemy_name, poison_damage
		])
	if not enemy.is_alive():
		return
	# The retaliation lands on the attack animation's contact frame.
	enemy.begin_retaliation_lunge(
		party_stage.get_global_transform() * Vector2(party_stage.line_start_x, party_stage.ground_y)
	)
	await enemy.play_attack()
	if _state != State.ENEMY_TURN:
		enemy.cancel_retaliation_lunge()
		return
	enemy.finish_retaliation_lunge()
	var retaliation: int = maxi(
		enemy.attack - _retaliation_reduction - _guard, 0
	)
	_log("The %s retaliates for %d damage!" % [
		enemy.enemy_name, retaliation
	])
	_retaliation_reduction = 0
	_guard = 0
	strike_fx.play(retaliation, $Layout)
	RunState.damage_player(retaliation)
	_refresh_status()
	if retaliation > 0:
		_health_bar_shake.play(player_health_bar)
	if RunState.player_health <= 0:
		_on_player_died()
		return
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	if _state == State.ENEMY_TURN:
		var newly_frozen: LetterStats = cold.freeze_after_turn(deck_manager.hand())
		_refresh_cold(newly_frozen)
		if newly_frozen != null:
			_log("The cold freezes %s. Thaw it for %d Heat." % [newly_frozen.letter.to_upper(), cold.THAW_COST])
		# Defer once so a just-finished animation or button event cannot claim
		# focus from the hidden LineEdit after the next player turn opens.
		call_deferred("_enter_player_input")


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
	if RunState.use_itemized_letters:
		var dropped_letter := RunState.rolled_letter_drop()
		RunState.add_letter_item(dropped_letter)
		RunState.begin_victory_with_drop(
			enemy.enemy_name, earned, dropped_letter
		)
	else:
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

func _on_log_toggled(shown: bool) -> void:
	side_panel.visible = shown
	log_toggle_button.text = "Hide Log" if shown else "Show Log"


func _advance_prompt() -> void:
	var current: int = PROMPT_ORDER.find(required_pos)
	required_pos = PROMPT_ORDER[(current + 1) % PROMPT_ORDER.size()]
	_refresh_prompt()


func _queue_feedback_layout() -> void:
	_layout_feedback_banner.call_deferred()


func _layout_feedback_banner() -> void:
	if not is_inside_tree():
		return
	var input_area: VBoxContainer = $Layout/InputArea
	var area: Rect2 = input_area.get_global_rect()
	var cast: Rect2 = submit_button.get_global_rect()
	var gap: float = input_area.get_theme_constant("separation") * input_area.scale.y
	var cast_gap: float = $Layout/InputArea/InputRow.get_theme_constant("separation") * input_area.scale.x
	# Match the heat column, reserving its right-hand lane for the existing Cast button.
	var width: float = cast.position.x - area.position.x - cast_gap
	var top: float = cast.position.y
	if heat_meter.visible:
		top = heat_meter.get_global_rect().end.y + gap
	for banner: PanelContainer in [feedback_banner, effectiveness_indicator]:
		banner.scale = input_area.scale
		var banner_width: float = cast.end.x - area.position.x if banner == effectiveness_indicator else width
		banner.size = Vector2(banner_width / banner.scale.x, banner.get_combined_minimum_size().y)
		banner.global_position = Vector2(area.position.x, top)
		top = banner.get_global_rect().end.y + gap


func _set_player_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_label.visible = not message.is_empty()
	prompt_label.visible = message.is_empty()


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
	var blocked: String = cold.blocked_letter(new_text, deck_manager.hand())
	if not blocked.is_empty():
		_set_player_feedback("%s is frozen — thaw it for %d Heat" % [blocked, cold.THAW_COST])
		var caret: int = word_input.caret_column
		word_input.text = _last_allowed_text
		word_input.caret_column = mini(caret, _last_allowed_text.length())
		return
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
		effectiveness_indicator.clear(_state != State.PLAYER_INPUT)
		return
	var result: Dictionary = calculator.calculate(
		word, drawn, undrawn, enemy.tags, required_pos,
		enemy.affinities, false, _turn_elapsed_seconds
	)
	result["damage"] = float(result["damage"]) * ENCOUNTER_MODIFIERS.player_factor(_encounter_modifier)
	if _state == State.PLAYER_INPUT:
		if validator.validate(word, required_pos).get("valid", false):
			effectiveness_indicator.show_preview(result)
		else:
			effectiveness_indicator.clear()
	_set_output_counters(
		int(round(float(result["damage"]))), int(result["water_heal"]), int(result["gold"])
	)
	_set_health_previews(
		int(round(float(result["damage"]))), int(result["water_heal"])
	)


func _update_timer_display() -> void:
	var remaining: float = maxf(DamageCalculator.SPEED_BONUS_DURATION - _turn_elapsed_seconds, 0.0)
	timer_label.text = "Quick-cast: %.1fs  •  Damage ×%.2f" % [
		remaining, calculator.speed_multiplier(_turn_elapsed_seconds),
	]


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
			_set_player_feedback("")
			_on_text_changed(word_input.text)
		else:
			tile.deny_thaw()
			heat_meter.pulse(true)
			_set_player_feedback("Thaw needs %d Heat. Each valid word gives +%d." % [cold.THAW_COST, cold.HEAT_PER_WORD])
	_focus_word_input()


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
	if not String(counter.get("tag", "")).is_empty():
		lines.append("  counter vs %s: %.2f (%s)" % [
			counter["tag"], counter["score"], counter["strategy"],
		])
	var elemental_damage: Dictionary = result["elemental_damage"]
	var elements: Array[String] = []
	for element_name: String in elemental_damage:
		var amount: float = elemental_damage[element_name]
		if amount > 0.0:
			elements.append("%s %.0f" % [element_name, amount])
	if not elements.is_empty():
		lines.append("  elements: " + ", ".join(elements))
	if result["lightning_procs"] > 0:
		lines.append("  lightning echoes %d time(s)." % result["lightning_procs"])
	if result["water_heal"] > 0:
		lines.append("  water restores %d health." % result["water_heal"])
	if result["ice_slow"] > 0:
		lines.append("  ice weakens retaliation by %d." % result["ice_slow"])
	if result["earth_guard"] > 0:
		lines.append("  earth grants %d Guard." % result["earth_guard"])
	return "\n".join(lines)


func _apply_elemental_effects(result: Dictionary) -> void:
	var relic_system: RelicSystem = RelicSystem.new()
	var fire_damage: float = result["elemental_damage"]["fire"]
	var burn_ratio: float = relic_system.total_effect("fire_burn_ratio")
	if fire_damage > 0.0 and burn_ratio > 0.0:
		enemy.add_burn(fire_damage * burn_ratio)
	var nature_poison: float = result["nature_poison"]
	if nature_poison > 0.0:
		enemy.add_poison(nature_poison)
	var water_heal: int = result["water_heal"]
	if water_heal > 0:
		RunState.heal_player(water_heal)
	_retaliation_reduction = result["ice_slow"]
	_guard = result["earth_guard"]


func _log(message: String) -> void:
	log_label.append_text(message + "\n")
