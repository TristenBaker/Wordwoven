extends Node
signal run_started
signal run_starting
const Balance: GDScript = preload("res://data/balance/tuning.gd")
## Holds the state of the current roguelike run: player health,
## gold, the letter deck, relics, progress, and the word history
## that the tavern storyteller retells. Survives scene changes;
## contains no combat or UI logic.

const STARTING_HEALTH: int = Balance.RUN_STATE_STARTING_HEALTH
const STARTING_GOLD: int = Balance.RUN_STATE_STARTING_GOLD
const ENCOUNTERS_PER_RUN: int = Balance.RUN_STATE_ENCOUNTERS_PER_RUN

# Set false to return to the original shared-deck and use-level system.
var use_itemized_letters: bool = true

var player_max_health: int = STARTING_HEALTH
var player_health: int = STARTING_HEALTH
var gold: int = STARTING_GOLD

# The letter characters the player owns.
var deck: Array[LetterStats] = []

# ARPG letter mode: acquired items are separate from the 26 matching letter
# slots. A slot holds at most one item whose character matches that slot.
var letter_inventory: Array[LetterStats] = []
var equipped_letters: Dictionary[String, LetterStats] = {}

# Relic identifiers, resolved by the relic system.
var relics: Array[String] = []

# The ice-fishing choice can be made only once during a run.
var fishing_hole_chosen: int = -1
var pending_route_activity: String = ""
var pending_route_key: String = ""
var route_depth: int = 1
# Shuffled once per run so the expedition map does not rearrange when the
# player returns from a detour or reopens the route screen.
var route_enemy_order: Array[String] = []
var route_combat_slots: Dictionary = {}
var route_activity_stages: Dictionary = {}
var route_required_activity: String = ""
var route_node_order: Dictionary = {}
var route_bypassed_activities: Dictionary = {}
var route_graph_columns: Array = []
var route_edges: Dictionary = {}
var route_chosen_nodes: Dictionary = {}
var _last_route_signature: String = ""

# Completed fights and their chosen relics prevent repeated rewards.
var completed_encounters: Array[int] = []
var defeated_enemy_ids: Array[String] = []
var relic_rewards: Dictionary[int, String] = {}

# Transient post-fight presentation data. These values carry a completed
# encounter through the bard, power, and loot screens before the run advances.
var pending_victory_enemy: String = ""
var pending_victory_gold: int = 0
var pending_relic_choices: Array[String] = []
var pending_victory_letter: LetterStats = null

# Shop stock survives leaving and reopening the tavern.
var recruitment_encounter: int = -1
var recruitment_stock: Array[Dictionary] = []

# 1-based index of the next encounter; the last one is the boss.
var encounter_index: int = 1

# Enemy chosen on the encounter-select screen; empty means the
# combat scene should roll one for the current stage.
var next_enemy_id: String = ""

# Cached preparation outcome, keyed to exactly one upcoming enemy/encounter.
var pending_encounter_modifier: Dictionary = {}

# Optional detours never consume a monster slot.
# Skipped visits also count as used.
var optional_encounters: Dictionary = {}
var optional_encounter_progress: Dictionary = {}
var pending_optional_encounter: String = ""

# Biome used by encounter selection and combat backgrounds.
var selected_biome: String = ""

# History entries for the storyteller:
# Word, enemy, tags, damage, requested part of speech, and encounter.
var word_history: Array[Dictionary] = []

var is_run_active: bool = false


## Starts either the legacy shared deck or ten randomly equipped ARPG letters.
func start_new_run() -> void:
	run_starting.emit()
	player_max_health = STARTING_HEALTH
	player_health = STARTING_HEALTH
	gold = STARTING_GOLD
	relics = []
	fishing_hole_chosen = -1
	pending_route_activity = ""
	pending_route_key = ""
	route_depth = 1
	route_enemy_order = []
	route_combat_slots.clear()
	route_activity_stages.clear()
	route_required_activity = ""
	route_node_order.clear()
	route_bypassed_activities.clear()
	route_graph_columns.clear()
	route_edges.clear()
	route_chosen_nodes.clear()
	completed_encounters = []
	defeated_enemy_ids = []
	relic_rewards = {}
	pending_victory_enemy = ""
	pending_victory_gold = 0
	pending_relic_choices = []
	pending_victory_letter = null
	recruitment_encounter = -1
	recruitment_stock = []
	encounter_index = 1
	next_enemy_id = ""
	pending_encounter_modifier.clear()
	optional_encounters.clear()
	optional_encounter_progress.clear()
	pending_optional_encounter = ""
	selected_biome = ""
	word_history = []
	deck = []
	letter_inventory = []
	equipped_letters = {}
	if use_itemized_letters:
		_setup_itemized_starters()
	else:
		var starters: String = (
			LetterStats.VOWELS + LetterStats.COMMON_CONSONANTS
		)
		for letter: String in starters:
			deck.append(LetterStats.create(letter))
	is_run_active = true
	run_started.emit()
	EventBus.emit_deck_changed()
	EventBus.emit_gold_changed(gold)


## True when the next encounter is the final boss.
func is_boss_next() -> bool:
	if selected_biome == "tundra" and not route_graph_columns.is_empty():
		return route_depth >= route_graph_columns.size()
	return encounter_index >= ENCOUNTERS_PER_RUN


func advance_encounter() -> void:
	encounter_index += 1
	if selected_biome == "tundra" and not route_graph_columns.is_empty():
		route_depth = mini(route_depth + 1, route_graph_columns.size())


## Records a victory once before its relic can be claimed.
func complete_encounter(enemy_id: String = "") -> void:
	if not enemy_id.is_empty() and not defeated_enemy_ids.has(enemy_id):
		defeated_enemy_ids.append(enemy_id)
	if not completed_encounters.has(encounter_index):
		completed_encounters.append(encounter_index)


## Treasure rooms occupy an encounter stage without recording a defeated foe.
func complete_treasure_room() -> void:
	if not completed_encounters.has(encounter_index):
		completed_encounters.append(encounter_index)


func begin_victory(enemy_name: String, gold_earned: int) -> void:
	pending_victory_enemy = enemy_name
	pending_victory_gold = gold_earned
	pending_relic_choices = []
	pending_victory_letter = null


func begin_victory_with_drop(
	enemy_name: String, gold_earned: int, dropped_letter: LetterStats
) -> void:
	begin_victory(enemy_name, gold_earned)
	pending_victory_letter = dropped_letter


func clear_pending_victory() -> void:
	pending_victory_enemy = ""
	pending_victory_gold = 0
	pending_relic_choices = []
	pending_victory_letter = null


func combat_letters() -> Array[LetterStats]:
	if not use_itemized_letters:
		return deck
	var letters: Array[LetterStats] = []
	for stats: LetterStats in equipped_letters.values():
		letters.append(stats)
	return letters


func add_letter_item(item: LetterStats) -> void:
	if item == null:
		return
	letter_inventory.append(item)
	EventBus.emit_deck_changed()


func equip_letter_item(item: LetterStats) -> bool:
	if item == null or not letter_inventory.has(item):
		return false
	var slot: String = item.letter.to_lower()
	var previous: LetterStats = equipped_letters.get(slot, null)
	letter_inventory.erase(item)
	if previous != null:
		letter_inventory.append(previous)
	equipped_letters[slot] = item
	EventBus.emit_deck_changed()
	return true


func unequip_letter(slot: String) -> bool:
	var normalized: String = slot.to_lower()
	var item: LetterStats = equipped_letters.get(normalized, null)
	if item == null:
		return false
	equipped_letters.erase(normalized)
	letter_inventory.append(item)
	EventBus.emit_deck_changed()
	return true


func rolled_letter_drop() -> LetterStats:
	var maximum_level: int = mini(
		Balance.DROP_MAX_LEVEL, Balance.DROP_LEVEL_OFFSET + encounter_index
	)
	return rolled_letter_drop_at_level(randi_range(1, maximum_level))


func rolled_letter_drop_at_level(item_level: int) -> LetterStats:
	var letters: Array[String] = []
	for letter: String in LetterStats.BASE_POWER:
		letters.append(letter)
	var letter: String = letters.pick_random()
	var elements: Array[int] = [
		LetterStats.Element.FIRE,
		LetterStats.Element.LIGHTNING,
		LetterStats.Element.WATER,
		LetterStats.Element.ICE,
		LetterStats.Element.NATURE,
		LetterStats.Element.EARTH,
	]
	var item_element: int = elements.pick_random()
	return LetterStats.create_item(
		letter, item_element, clampi(item_level, 1, Balance.DROP_MAX_LEVEL)
	)


func _setup_itemized_starters() -> void:
	var letters: Array[String] = []
	for letter: String in LetterStats.BASE_POWER:
		letters.append(letter)
	letters.shuffle()
	for index: int in range(Balance.STARTER_COUNT):
		var letter: String = letters[index]
		var elements: Array[int] = [
			LetterStats.Element.FIRE,
			LetterStats.Element.LIGHTNING,
			LetterStats.Element.WATER,
			LetterStats.Element.ICE,
			LetterStats.Element.NATURE,
			LetterStats.Element.EARTH,
		]
		var item_element: int = elements.pick_random()
		equipped_letters[letter] = LetterStats.create_item(
			letter, item_element, 1
		)


func choose_fishing_hole(hole_index: int) -> bool:
	if fishing_hole_chosen >= 0:
		return false
	fishing_hole_chosen = hole_index
	return true


func fishing_route_available() -> bool:
	return (
		is_run_active and selected_biome == "tundra"
		and route_depth > 1 and not is_boss_next()
		and fishing_hole_chosen < 0
		and pending_route_activity.is_empty()
	)


func begin_fishing_route(route_key: String = "") -> bool:
	if not fishing_route_available():
		return false
	pending_route_activity = "ice_fishing"
	pending_route_key = route_key
	return true


func finish_route_activity() -> void:
	if pending_route_activity.is_empty():
		return
	if not pending_route_key.is_empty():
		record_route_choice(route_depth, pending_route_key)
	pending_route_activity = ""
	pending_route_key = ""
	route_depth = mini(route_depth + 1, route_graph_columns.size())


func ensure_route_enemy_order() -> void:
	ensure_tundra_route_plan()


func ensure_tundra_route_plan() -> void:
	if not route_graph_columns.is_empty():
		return
	route_enemy_order = Balance.ENEMY_FACTORY_TUNDRA_REGULARS.duplicate()
	route_enemy_order.shuffle()
	var activity_ids: Array[String] = [
		"ice_fishing", "frozen_traveler", "icy_portal", "treasure_chest",
	]
	activity_ids.shuffle()
	# Route depth is separate from fight count. Combat-only layers 1, 3, 5,
	# and 7 guarantee four fights, while an activity consumes its own room and
	# advances the expedition instead of returning to a battle at the same depth.
	route_graph_columns = [
		["combat_1_0"],
		["activity_" + activity_ids[0], "activity_" + activity_ids[1]],
		["combat_3_0", "combat_3_1"],
		["combat_4_0", "activity_" + activity_ids[2]],
		["combat_5_0", "combat_5_1"],
		["activity_" + activity_ids[3]],
		["combat_7_0", "combat_7_1"],
		["boss"],
	]
	var hangman_column: int = [1, 3, 5].pick_random()
	route_graph_columns[hangman_column].append("activity_hangman")
	for column_index: int in route_graph_columns.size():
		for key: String in route_graph_columns[column_index]:
			if key.begins_with("activity_"):
				route_activity_stages[key.trim_prefix("activity_")] = column_index + 1
	_build_route_graph()
	var signature: String = "%s|%s" % [str(route_graph_columns), str(route_enemy_order)]
	if signature == _last_route_signature:
		route_enemy_order.reverse()
		signature = "%s|%s" % [str(route_graph_columns), str(route_enemy_order)]
	_last_route_signature = signature


func _build_route_graph() -> void:
	route_edges.clear()
	for column_index: int in range(route_graph_columns.size() - 1):
		var sources: Array = route_graph_columns[column_index]
		var destinations: Array = route_graph_columns[column_index + 1]
		for source_index: int in sources.size():
			var source: String = String(sources[source_index])
			if sources.size() == 1:
				route_edges[source] = destinations.duplicate()
			else:
				route_edges[source] = [String(
					destinations[source_index % destinations.size()]
				)]
				if destinations.size() > sources.size():
					route_edges[source].append(String(destinations[-1]))
	# The opening room always visibly fans into the complete first decision.
	route_edges["combat_1_0"] = route_graph_columns[1].duplicate()


func record_route_choice(depth: int, route_key: String) -> void:
	route_chosen_nodes[depth] = route_key


func route_predecessor_for_stage(stage: int) -> String:
	ensure_tundra_route_plan()
	if stage <= 1:
		return ""
	return String(route_chosen_nodes.get(stage - 1, ""))


func required_route_activity_at(stage: int) -> String:
	ensure_tundra_route_plan()
	var column: Array = route_graph_columns[stage - 1] if stage > 0 \
			and stage <= route_graph_columns.size() else []
	if column.size() == 1 and String(column[0]).begins_with("activity_"):
		return String(column[0]).trim_prefix("activity_")
	return ""


func route_activity_completed(id: String) -> bool:
	if id == "ice_fishing":
		return fishing_hole_chosen >= 0
	return optional_encounters.has(id)


func route_activity_resolved(id: String) -> bool:
	return route_activity_completed(id) or route_bypassed_activities.has(id)


func bypass_route_activity(id: String) -> bool:
	ensure_tundra_route_plan()
	if id == route_required_activity or route_activity_resolved(id):
		return false
	if int(route_activity_stages.get(id, -1)) != encounter_index:
		return false
	route_bypassed_activities[id] = true
	return true


func route_activity_for_stage(stage: int) -> String:
	ensure_tundra_route_plan()
	for id: String in route_activity_stages:
		if int(route_activity_stages[id]) == stage:
			return id
	return ""


func route_key_available(route_key: String) -> bool:
	ensure_tundra_route_plan()
	if route_depth <= 1:
		return route_key == "combat_1_0"
	var predecessor: String = route_predecessor_for_stage(route_depth)
	return route_edges.get(predecessor, []).has(route_key)


## Developer-only map jump. Preserve the run's inventory while making the
## selected room current and replayable, even after a previous completion.
func debug_jump_to_route_node(route_key: String, depth: int) -> bool:
	ensure_tundra_route_plan()
	if depth < 1 or depth > route_graph_columns.size() \
			or not route_graph_columns[depth - 1].has(route_key):
		return false
	route_depth = depth
	encounter_index = ENCOUNTERS_PER_RUN if route_key == "boss" else \
		mini(1 + int(floor(float(depth) / 2.0)), ENCOUNTERS_PER_RUN - 1)
	is_run_active = true
	completed_encounters.erase(ENCOUNTERS_PER_RUN)
	pending_route_activity = ""
	pending_route_key = ""
	pending_optional_encounter = ""
	next_enemy_id = ""
	pending_encounter_modifier.clear()
	clear_pending_victory()
	for previous_depth: int in route_chosen_nodes.keys():
		if previous_depth >= depth:
			route_chosen_nodes.erase(previous_depth)
	if depth > 1:
		for predecessor: String in route_graph_columns[depth - 2]:
			if route_edges.get(predecessor, []).has(route_key):
				route_chosen_nodes[depth - 1] = predecessor
				break
	if route_key.begins_with("activity_"):
		var activity_id: String = route_key.trim_prefix("activity_")
		optional_encounters.erase(activity_id)
		optional_encounter_progress.erase(activity_id)
		if activity_id == "ice_fishing":
			fishing_hole_chosen = -1
	return true


func available_route_enemies(limit: int = 2) -> Array[String]:
	ensure_route_enemy_order()
	var available: Array[String] = []
	for enemy_id: String in route_enemy_order:
		if defeated_enemy_ids.has(enemy_id):
			continue
		available.append(enemy_id)
		if available.size() >= limit:
			break
	return available


func add_gold(amount: int) -> void:
	gold += amount
	EventBus.emit_gold_changed(gold)


## Spends gold if affordable; returns whether it was.
func spend_gold(amount: int) -> bool:
	if amount < 0 or amount > gold:
		return false
	gold -= amount
	EventBus.emit_gold_changed(gold)
	return true


func damage_player(amount: int) -> void:
	player_health = maxi(player_health - amount, 0)
	EventBus.emit_player_damaged(float(amount))
	if player_health <= 0:
		is_run_active = false
		EventBus.emit_player_defeated()


func heal_player(amount: int) -> void:
	player_health = mini(
		player_health + amount, player_max_health
	)


## Records a played word for the storyteller and damage history.
func record_word(
	word: String,
	enemy_name: String,
	tags: Array[String],
	damage: float,
	pos: String = ""
) -> void:
	word_history.append({
		"word": word,
		"enemy": enemy_name,
		"tags": tags,
		"damage": damage,
		"pos": pos,
		"encounter": encounter_index,
	})


func cache_encounter_modifier(
	enemy_id: String, word: String, modifier_id: String
) -> Dictionary:
	if not pending_encounter_modifier.is_empty():
		return pending_encounter_modifier.duplicate(true)
	pending_encounter_modifier = {
		"encounter": encounter_index, "enemy_id": enemy_id,
		"word": word, "modifier_id": modifier_id,
	}
	return pending_encounter_modifier.duplicate(true)


func take_encounter_modifier(enemy_id: String) -> Dictionary:
	var pending: Dictionary = pending_encounter_modifier.duplicate(true)
	pending_encounter_modifier.clear()
	if (
		pending.get("encounter", -1) != encounter_index
		or pending.get("enemy_id", "") != enemy_id
	):
		return {}
	return pending


func optional_encounter_available(id: String) -> bool:
	# Load at runtime: the reward helper itself depends on this autoload.
	var event_script: GDScript = load("res://scripts/encounters/tundra_events.gd")
	return (
		is_run_active and selected_biome == "tundra"
		and route_depth > 1 and not is_boss_next()
		and not completed_encounters.has(ENCOUNTERS_PER_RUN)
		and (event_script.IDS.has(id) or id == "hangman")
		and not optional_encounters.has(id)
		and (pending_route_activity.is_empty() or pending_route_activity == id)
	)


func begin_optional_encounter(id: String, route_key: String = "") -> bool:
	if not optional_encounter_available(id):
		return false
	pending_optional_encounter = id
	pending_route_activity = id
	pending_route_key = route_key
	return true
