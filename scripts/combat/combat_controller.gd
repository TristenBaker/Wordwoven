extends Control
const Balance = preload("res://data/balance/tuning.gd")
## Runs one combat encounter as a turn state machine: the player
## drafts a word, the enemy takes the damage, then retaliates.
## Delegates the rules to DeckManager, WordValidator,
## DamageCalculator, and EnemyFactory child nodes and keeps only
## the flow and the screen updates here.

const ENCOUNTER_MODIFIERS = preload("res://data/balance/encounter_modifier.gd")
var _encounter_modifier: Dictionary = {}
var _modifier_runtime = preload("res://data/balance/encounter_modifier_runtime.gd").new()

enum State {
	PLAYER_INPUT,
	RESOLVING,
	ENEMY_TURN,
	WON,
	LOST,
}

const LETTER_TILE_SCENE: PackedScene = \
		preload("res://scenes/combat/letter_tile.tscn")
const STAR_COIN: Texture2D = preload("res://assets/Art/Items/starcoin.png")
const STAR_COIN_DING: AudioStream = preload("res://assets/Audio/party/coin.wav")

# Pause before and after the enemy's retaliation, in seconds.
const ENEMY_TURN_DELAY: float = 0.7
# Shorter pause once the party has finished its actions.
const PARTY_SETTLE_DELAY: float = 0.25
# Fade to black between the enemy's death and the victory tale.
const VICTORY_FADE_TIME: float = 0.35

const PROMPT_ORDER: Array[String] = preload("res://data/balance/tuning.gd").COMBAT_CONTROLLER_PROMPT_ORDER

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
var endless_biome_backgrounds: Array[Texture2D] = [
	preload("res://art/backgrounds/Tundra Biome/T1.png"),
	preload("res://art/backgrounds/Tundra Biome/T2.png"),
	preload("res://art/backgrounds/Tundra Biome/T3.png"),
	preload("res://art/backgrounds/Tundra Biome/T4.png"),
	preload("res://art/backgrounds/Tundra Biome/T5.png"),
	preload("res://art/backgrounds/Tundra Biome/T6.png"),
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
@onready var endless_route: HBoxContainer = $Layout/EndlessRoute


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
	DebugTools.auto_kill_requested.connect(_on_dev_kill_pressed)
	log_toggle_button.toggled.connect(_on_log_toggled)
	$Layout/WordHistoryButton.pressed.connect(_open_word_history)
	enemy.died.connect(_on_enemy_died)
	party_stage.gold_stolen.connect(_on_gold_stolen)
	_move_enemy_info_beneath_endless_route()
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


func _move_enemy_info_beneath_endless_route() -> void:
	if not RunState.is_endless():
		return
	var info: VBoxContainer = enemy.info_box
	info.reparent($Layout)
	info.set_anchors_preset(Control.PRESET_CENTER_TOP)
	info.offset_left = -170.0
	info.offset_top = 72.0
	info.offset_right = 170.0
	info.offset_bottom = 200.0
	info.z_index = 2


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
	if not ENCOUNTER_MODIFIERS.eligible(_encounter_modifier, RunState.selected_biome):
		_encounter_modifier = {}
	_modifier_runtime = preload("res://data/balance/encounter_modifier_runtime.gd").new()
	_modifier_runtime.configure(_encounter_modifier, int(spawn_data.attack), String(spawn_data.id))
	if _modifier_runtime.id == "frostbite_tax" and cold.enabled:
		cold.freeze_every = Balance.FROSTBITE_FREEZE_EVERY
		cold.heat_per_word = Balance.FROSTBITE_HEAT_PER_WORD
		_refresh_cold()
	var base_spawn: Dictionary = spawn_data
	spawn_data = ENCOUNTER_MODIFIERS.apply_spawn(base_spawn, _encounter_modifier)
	enemy.setup(spawn_data)
	$Layout/ActiveModifierPanel.show_modifier(
		String(preparation.get("word", "")), _encounter_modifier,
		base_spawn, spawn_data, ENCOUNTER_MODIFIERS.player_factor(_encounter_modifier)
	)
	_update_modifier_status()
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
	if RunState.is_endless():
		var endless_pool: Array[Texture2D] = []
		endless_pool.append_array(backgrounds)
		endless_pool.append_array(endless_biome_backgrounds)
		background.texture = endless_pool.pick_random()
	else:
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
		var debug_pick: bool = DebugTools.free_map_select and (
			enemy_id == factory.boss_id() or enemy_id == Balance.TUNDRA_STARTER_ENEMY
			or Balance.ENEMY_FACTORY_TUNDRA_REGULARS.has(enemy_id)
		)
		if not allowed.has(enemy_id) and not debug_pick:
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
	if _state != State.PLAYER_INPUT or get_tree().paused:
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
	PlayerStats.mark_debug_assisted()
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
	_modifier_runtime.modify_result(result, word)
	var bonus_gold: int = _modifier_runtime.accept_cast(word)
	if bonus_gold > 0:
		RunState.add_gold(bonus_gold)
		_log("GREEDY: +1 cast gold (%d/5). The monster charges a consultation fee." % _modifier_runtime.gold_gained)
	_update_modifier_status()
	validator.mark_played(word)
	var earned_star_coin := RunState.record_word(
		word, enemy.enemy_name, enemy.tags, result["damage"],
		required_pos, {
			"effectiveness_label": (
				WordEffectivenessFormat.classification(result)
			),
			"effectiveness": result.get("effectiveness", 0.0),
			"semantic_multiplier": result.get("semantic_multiplier", 0.0),
		}
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
	if _state != State.RESOLVING:
		return
	_show_damage_popup(result["damage"])
	if earned_star_coin:
		_show_star_coin_reward(word)
	enemy.take_damage(result["damage"])
	if enemy.is_alive():
		_enemy_turn()


func _on_gold_stolen(amount: int) -> void:
	RunState.add_gold(amount)
	_refresh_status()


func _enemy_turn() -> void:
	if _state != State.RESOLVING:
		return
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
	var plan: Dictionary = _modifier_runtime.retaliation_plan(enemy.attack)
	# Sleeping skips only the attack; burn, poison, turn completion and cold still run.
	if plan.kind != "sleep":
		enemy.begin_retaliation_lunge(
			party_stage.get_global_transform() * Vector2(party_stage.line_start_x, party_stage.ground_y)
		)
		await enemy.play_attack()
		if _state != State.ENEMY_TURN:
			enemy.cancel_retaliation_lunge()
			return
		enemy.finish_retaliation_lunge()
	var stolen: int = _modifier_runtime.complete_retaliation(RunState.gold)
	if stolen > 0:
		RunState.spend_gold(stolen)
		_log("GREEDY: the monster steals %d gold (%d/4 total). 'Administrative expenses!'" % [stolen, _modifier_runtime.gold_stolen])
	var retaliation: int = maxi(int(plan.attack) - _retaliation_reduction - _guard, 0) if plan.kind == "attack" else 0
	_retaliation_reduction = 0
	_guard = 0
	if plan.kind == "sleep":
		_log("DROWSY: the %s snores through its turn. 'Five more minutes of villainy...'" % enemy.enemy_name)
	elif plan.kind == "self_hit":
		_log("CLUMSY: the %s trips over its own threat and hits itself for %d damage!" % [enemy.enemy_name, int(round(float(plan.self_damage)))])
		enemy.take_damage(float(plan.self_damage))
	else:
		_log("The %s retaliates for %d damage!" % [enemy.enemy_name, retaliation])
		strike_fx.play(retaliation, $Layout)
		RunState.damage_player(retaliation)
	_update_modifier_status()
	if not enemy.is_alive():
		return
	_refresh_status()
	if retaliation > 0:
		_health_bar_shake.play(player_health_bar)
	if RunState.player_health <= 0:
		_on_player_died()
		return
	await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
	if _state == State.ENEMY_TURN:
		var new_tags: Array[String] = _modifier_runtime.next_tags(enemy.tags)
		if not new_tags.is_empty():
			enemy.set_semantic_tags(new_tags)
			_log("CHAMELEON: new counter targets: %s. 'I contain multitudes. Mostly problems.'" % " • ".join(new_tags))
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
	var earned: int = enemy.gold_reward + _modifier_runtime.victory_bonus()
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
	get_tree().change_scene_to_file(
		ScenePaths.POWER_SELECT if RunState.is_endless() else ScenePaths.FIGHT_COMPLETION
	)


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
	_update_modifier_status(word)
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
	_modifier_runtime.modify_result(result, word)
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


func _show_star_coin_reward(word: String) -> void:
	var effect := Control.new()
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect.z_index = 120
	add_child(effect)
	var start := get_viewport_rect().size * Vector2(0.5, 0.38)
	var coin := TextureRect.new()
	coin.texture = STAR_COIN
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size = Vector2(76, 76)
	coin.global_position = start - coin.size * 0.5
	coin.pivot_offset = coin.size * 0.5
	coin.scale = Vector2(0.35, 0.35)
	coin.modulate = Color(1, 1, 1, 0)
	effect.add_child(coin)
	var notice := Label.new()
	notice.text = "NEW WORD!  +1 STARCOIN\n%s" % word.to_upper()
	notice.position = start + Vector2(-180, 46)
	notice.size = Vector2(360, 62)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_override("font", preload("res://assets/Fonts/Junicode.ttf"))
	notice.add_theme_font_size_override("font_size", 21)
	notice.add_theme_color_override("font_color", Color("d5f8ff"))
	notice.add_theme_color_override("font_outline_color", Color("251144"))
	notice.add_theme_constant_override("outline_size", 5)
	notice.modulate.a = 0.0
	effect.add_child(notice)
	var ding := AudioStreamPlayer.new()
	ding.stream = STAR_COIN_DING
	ding.bus = &"SFX"
	effect.add_child(ding)
	ding.play()
	var target: Vector2 = $EquipmentOverlay/EquipButton.get_global_rect().get_center() \
		- coin.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(coin, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(coin, "modulate:a", 1.0, 0.14)
	tween.tween_property(notice, "modulate:a", 1.0, 0.14)
	tween.chain().tween_property(coin, "global_position", target, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(coin, "scale", Vector2(0.28, 0.28), 0.58)
	tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.58)
	tween.parallel().tween_property(notice, "modulate:a", 0.0, 0.34)
	tween.chain().tween_callback(effect.queue_free)


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
	heat_meter.refresh(cold.heat, cold.turns, not cold.frozen.is_empty(), cold.freeze_every)
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
			_set_player_feedback("Thaw needs %d Heat. Each valid word gives +%d." % [cold.THAW_COST, cold.heat_per_word])
	_focus_word_input()


func _refresh_status() -> void:
	player_health_bar.max_value = RunState.player_max_health
	player_health_bar.value = RunState.player_health
	player_health_label.text = "%d / %d" % [
		RunState.player_health, RunState.player_max_health
	]
	gold_label.text = "Gold: %d" % RunState.gold
	if RunState.is_endless():
		stage_label.text = "ENDLESS · WAVE %d" % RunState.encounter_index
		_refresh_endless_route()
		return
	endless_route.visible = false
	var stage_text: String = "Encounter %d of %d" % [
		RunState.encounter_index, RunState.ENCOUNTERS_PER_RUN
	]
	if RunState.is_boss_next():
		stage_text = "Final Encounter"
	stage_label.text = stage_text


func _refresh_endless_route() -> void:
	endless_route.visible = true
	for child: Node in endless_route.get_children():
		endless_route.remove_child(child)
		child.queue_free()
	for offset: int in range(5):
		var wave: int = RunState.encounter_index + offset
		var shop_after_wave: bool = wave % 5 == 0
		var node := PanelContainer.new()
		node.custom_minimum_size = Vector2(105, 48)
		node.add_theme_stylebox_override(
			"panel", _endless_route_style(offset == 0, shop_after_wave)
		)
		var label := Label.new()
		label.text = "NOW\nWAVE %d" % wave if offset == 0 else (
			"SHOP\nWAVE %d" % wave if shop_after_wave else "WAVE %d" % wave
		)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("fff4d6"))
		node.add_child(label)
		endless_route.add_child(node)
		if offset < 4:
			var arrow := Label.new()
			arrow.text = "›"
			arrow.add_theme_font_size_override("font_size", 25)
			arrow.add_theme_color_override("font_color", Color("ccb37d"))
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			endless_route.add_child(arrow)


func _endless_route_style(is_current: bool, is_shop: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("285138") if is_current else (
		Color("72551e") if is_shop else Color("20384f")
	)
	style.border_color = Color("a9ff9a") if is_current else (
		Color("ffd15d") if is_shop else Color("78b9ed")
	)
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style


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
	if int(result.get("modifier_guard", 0)) > 0:
		lines.append("  LONG-WINDED grants 2 Guard for this retaliation.")
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
	_guard = int(result["earth_guard"]) + int(result.get("modifier_guard", 0))


func _log(message: String) -> void:
	log_label.append_text(message + "\n")

func _update_modifier_status(word: String = "") -> void:
	$Layout/ActiveModifierPanel.show_status(_encounter_modifier, _modifier_runtime.status(word))


func _open_word_history() -> void:
	if _state == State.PLAYER_INPUT:
		pause_menu.open_history($PauseMenu/WordHistory)
