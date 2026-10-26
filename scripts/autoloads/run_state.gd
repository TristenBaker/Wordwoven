extends Node
signal run_started
signal run_starting
const Balance: GDScript = preload("res://data/balance/tuning.gd")
const RouteGenerator: GDScript = preload("res://scripts/run/expedition_route_generator.gd")
## Holds the state of the current roguelike run: player health,
## gold, the letter deck, relics, progress, and the word history
## that the tavern storyteller retells. Survives scene changes;
## contains no combat or UI logic.

const STARTING_HEALTH: int = Balance.RUN_STATE_STARTING_HEALTH
const STARTING_GOLD: int = Balance.RUN_STATE_STARTING_GOLD
const ENCOUNTERS_PER_RUN: int = Balance.RUN_STATE_ENCOUNTERS_PER_RUN

enum RunMode { STORY, ENDLESS }

# Set false to return to the original shared-deck and use-level system.
var use_itemized_letters: bool = true

var player_max_health: int = STARTING_HEALTH
var player_health: int = STARTING_HEALTH
var gold: int = STARTING_GOLD
var gold_earned_this_run: int = 0
var run_score_recorded: bool = false
var run_mode: RunMode = RunMode.STORY
var has_unseen_inventory_items: bool = false
var auto_equip_enabled: bool = false
var auto_equip_same_element_only: bool = false

# The letter characters the player owns.
var deck: Array[LetterStats] = []

# ARPG letter mode: acquired items are separate from the 26 matching letter
# slots. A slot holds at most one item whose character matches that slot.
var letter_inventory: Array[LetterStats] = []
var equipped_letters: Dictionary[String, LetterStats] = {}

# Relic identifiers, resolved by the relic system.
var relics: Array[String] = []
var key_items: Array[Resource] = []
var tundra_intro_seen: bool = false
var lore_room_completed: bool = false
var fishing_tutorial_seen: bool = false

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
# Authoritative seeded route model. The legacy arrays above are projections
# retained while older non-map callers migrate to the graph API.
var route_seed: int = 0
var route_nodes: Dictionary = {}
var route_start_key: String = ""
var route_boss_key: String = ""
var route_current_key: String = ""
var route_pending_destination: String = ""
var route_completed_keys: Array[String] = []
var route_bypassed_keys: Array[String] = []

# Completed fights and their chosen relics prevent repeated rewards.
var completed_encounters: Array[int] = []
var defeated_enemy_ids: Array[String] = []
var defeated_enemy_history: Array[String] = []
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


func _ready() -> void:
	auto_equip_enabled = bool(AppSettings.preferences.get("auto_equip_enabled", false))
	auto_equip_same_element_only = bool(
		AppSettings.preferences.get("auto_equip_same_element_only", false)
	)


## Starts either the legacy shared deck or ten randomly equipped ARPG letters.
func start_new_run(mode: RunMode = RunMode.STORY) -> void:
	run_mode = mode
	run_starting.emit()
	player_max_health = STARTING_HEALTH
	player_health = STARTING_HEALTH
	gold = STARTING_GOLD
	gold_earned_this_run = 0
	run_score_recorded = false
	has_unseen_inventory_items = false
	relics = []
	key_items = []
	tundra_intro_seen = false
	lore_room_completed = false
	fishing_tutorial_seen = false
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
	route_seed = 0
	route_nodes.clear()
	route_start_key = ""
	route_boss_key = ""
	route_current_key = ""
	route_pending_destination = ""
	route_completed_keys.clear()
	route_bypassed_keys.clear()
	completed_encounters = []
	defeated_enemy_ids = []
	defeated_enemy_history = []
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
	if is_endless():
		return false
	if selected_biome == "tundra" and not route_nodes.is_empty() \
			and not route_current_key.is_empty():
		return route_current_key == route_boss_key
	return encounter_index >= ENCOUNTERS_PER_RUN


func is_endless() -> bool:
	return run_mode == RunMode.ENDLESS


func endless_shop_due() -> bool:
	return is_endless() and encounter_index > 0 and encounter_index % 5 == 0


func advance_encounter() -> void:
	encounter_index += 1
	if selected_biome == "tundra" and route_nodes.has(route_current_key):
		route_depth = mini(
			int(route_nodes[route_current_key].column) + 2,
			route_graph_columns.size()
		)
		_refresh_route_states()


## Records a victory once before its relic can be claimed.
func complete_encounter(enemy_id: String = "") -> void:
	if not enemy_id.is_empty():
		defeated_enemy_history.append(enemy_id)
	if not enemy_id.is_empty() and not defeated_enemy_ids.has(enemy_id):
		defeated_enemy_ids.append(enemy_id)
	if not completed_encounters.has(encounter_index):
		completed_encounters.append(encounter_index)
	complete_current_route_node()


## Treasure rooms occupy an encounter stage without recording a defeated foe.
func complete_treasure_room() -> void:
	if not completed_encounters.has(encounter_index):
		completed_encounters.append(encounter_index)
	complete_current_route_node()


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
	has_unseen_inventory_items = true
	if auto_equip_enabled:
		_try_auto_equip_item(item)
	EventBus.emit_deck_changed()


func set_auto_equip(enabled: bool, same_element_only: bool) -> void:
	auto_equip_enabled = enabled
	auto_equip_same_element_only = same_element_only
	AppSettings.set_auto_equip_preferences(enabled, same_element_only)


func _try_auto_equip_item(item: LetterStats) -> bool:
	if not use_itemized_letters or not letter_inventory.has(item):
		return false
	var slot: String = item.letter.to_lower()
	var current: LetterStats = equipped_letters.get(slot, null)
	if current == null:
		if auto_equip_same_element_only:
			return false
	elif item.level <= current.level or (
		auto_equip_same_element_only and item.element != current.element
	):
		return false
	letter_inventory.erase(item)
	if current != null:
		letter_inventory.append(current)
	equipped_letters[slot] = item
	return true


func mark_inventory_items_unseen() -> void:
	has_unseen_inventory_items = true


func mark_inventory_seen() -> void:
	has_unseen_inventory_items = false


## Adds a unique story item. Re-entering a reward screen cannot duplicate it.
func grant_key_item(item: Resource) -> bool:
	if item == null or has_key_item(item.id):
		return false
	key_items.append(item)
	return true


func has_key_item(id: String) -> bool:
	for item: Resource in key_items:
		if item.id == id:
			return true
	return false


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


## Equips only genuine upgrades. With an element lock, an occupied slot can
## only be replaced by a higher-level item of its current element.
func auto_equip_higher_levels(same_element_only: bool = false) -> int:
	if not use_itemized_letters:
		return 0
	var changed := 0
	for letter: String in "abcdefghijklmnopqrstuvwxyz":
		var current: LetterStats = equipped_letters.get(letter, null)
		var best: LetterStats = null
		for item: LetterStats in letter_inventory:
			if item.letter != letter:
				continue
			if current == null:
				if same_element_only:
					continue
			elif item.level <= current.level or (
				same_element_only and item.element != current.element
			):
				continue
			if best == null or item.level > best.level:
				best = item
		if best == null:
			continue
		letter_inventory.erase(best)
		if current != null:
			letter_inventory.append(current)
		equipped_letters[letter] = best
		changed += 1
	if changed > 0:
		EventBus.emit_deck_changed()
	return changed


func rolled_letter_drop() -> LetterStats:
	var maximum_level: int = mini(
		Balance.DROP_MAX_LEVEL, Balance.DROP_LEVEL_OFFSET + encounter_index
	)
	if String(current_route_node().get("node_type", "")) == "elite_combat":
		maximum_level = mini(Balance.DROP_MAX_LEVEL, maximum_level + 1)
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
	if not fishing_route_available() or not _route_key_is_active(route_key):
		return false
	pending_route_activity = "ice_fishing"
	pending_route_key = route_key
	return true


func finish_route_activity() -> void:
	if pending_route_activity.is_empty():
		return
	complete_current_route_node()
	pending_route_activity = ""
	pending_route_key = ""
	if route_nodes.has(route_current_key):
		route_depth = mini(
			int(route_nodes[route_current_key].column) + 2,
			route_graph_columns.size()
		)
	_refresh_route_states()


func ensure_route_enemy_order() -> void:
	ensure_tundra_route_plan()


func ensure_tundra_route_plan() -> void:
	if not route_nodes.is_empty():
		return
	initialize_tundra_route()


func initialize_tundra_route(seed_override: int = 0) -> void:
	if selected_biome != "tundra":
		return
	if not route_nodes.is_empty() and seed_override == 0:
		return
	route_seed = seed_override if seed_override != 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_msec()
	var generated: Dictionary = RouteGenerator.generate(route_seed, selected_biome)
	route_nodes = generated.nodes
	route_start_key = String(generated.start_key)
	route_boss_key = String(generated.boss_key)
	route_graph_columns = generated.columns
	route_current_key = ""
	route_pending_destination = ""
	route_completed_keys.clear()
	route_bypassed_keys.clear()
	route_chosen_nodes.clear()
	route_activity_stages.clear()
	route_enemy_order.clear()
	route_edges.clear()
	for route_key: String in route_nodes:
		var node: Dictionary = route_nodes[route_key]
		route_edges[route_key] = node.next_keys.duplicate()
		var content_id: String = String(node.content_id)
		if String(node.node_type) in ["normal_combat", "elite_combat"]:
			route_enemy_order.append(content_id)
		elif not content_id.is_empty() and String(node.node_type) != "boss":
			route_activity_stages[route_key] = int(node.column) + 1
	route_depth = 1
	_refresh_route_states()


func record_route_choice(depth: int, route_key: String) -> void:
	if select_route_node(route_key):
		activate_pending_route_node()


func route_predecessor_for_stage(stage: int) -> String:
	ensure_tundra_route_plan()
	return route_current_key


func required_route_activity_at(stage: int) -> String:
	ensure_tundra_route_plan()
	var column: Array = route_graph_columns[stage - 1] if stage > 0 \
			and stage <= route_graph_columns.size() else []
	if column.size() == 1:
		var key: String = String(column[0])
		if route_nodes.has(key) and not String(route_nodes[key].content_id).is_empty():
			return String(route_nodes[key].content_id)
	return ""


func route_activity_id(route_key_or_id: String) -> String:
	if route_nodes.has(route_key_or_id):
		return String(route_nodes[route_key_or_id].content_id)
	var id: String = route_key_or_id.trim_prefix("activity_")
	if id.begins_with("lore_room_"):
		return "lore_room"
	return id


func route_activity_completed(id: String) -> bool:
	if id == "ice_fishing":
		return fishing_hole_chosen >= 0
	if id == "lore_room":
		return lore_room_completed
	return optional_encounters.has(id)


func lore_room_available() -> bool:
	return (
		is_run_active and selected_biome == "tundra"
		and not lore_room_completed and not is_boss_next()
		and pending_route_activity.is_empty()
	)


func begin_lore_room(route_key: String) -> bool:
	if not lore_room_available() or not _route_key_is_active(route_key):
		return false
	pending_route_activity = "lore_room"
	pending_route_key = route_key
	return true


func finish_lore_room() -> bool:
	if pending_route_activity != "lore_room" or lore_room_completed:
		return false
	lore_room_completed = true
	finish_route_activity()
	return true


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
	if stage > 0 and stage <= route_graph_columns.size():
		for key: String in route_graph_columns[stage - 1]:
			if route_nodes.has(key):
				var type: String = String(route_nodes[key].node_type)
				if type not in ["normal_combat", "elite_combat", "boss"]:
					return String(route_nodes[key].content_id)
	return ""


func route_key_available(route_key: String) -> bool:
	ensure_tundra_route_plan()
	if not route_nodes.has(route_key) or route_pending_destination != "":
		return false
	return String(route_nodes[route_key].visit_state) == "available"


func select_route_node(route_key: String) -> bool:
	if not route_key_available(route_key):
		return false
	route_pending_destination = route_key
	var selected_column: int = int(route_nodes[route_key].column)
	var reachable: Dictionary = _reachable_from(route_key)
	for key: String in route_nodes:
		var node: Dictionary = route_nodes[key]
		if int(node.column) < selected_column or key == route_key \
				or route_completed_keys.has(key):
			continue
		if not reachable.has(key) and not route_bypassed_keys.has(key):
			route_bypassed_keys.append(key)
	_refresh_route_states()
	return true


func activate_pending_route_node() -> bool:
	if route_pending_destination.is_empty() or not route_nodes.has(route_pending_destination):
		return false
	route_current_key = route_pending_destination
	route_pending_destination = ""
	var node: Dictionary = route_nodes[route_current_key]
	route_depth = int(node.column) + 1
	route_chosen_nodes[route_depth] = route_current_key
	if String(node.node_type) in ["normal_combat", "elite_combat", "boss"]:
		next_enemy_id = String(node.content_id)
	_refresh_route_states()
	return true


func complete_current_route_node() -> bool:
	if route_current_key.is_empty() or route_completed_keys.has(route_current_key):
		return false
	route_completed_keys.append(route_current_key)
	_refresh_route_states()
	return true


func current_route_node() -> Dictionary:
	return route_nodes.get(route_current_key, {})


func _route_key_is_active(route_key: String) -> bool:
	return route_key.is_empty() or route_key == route_current_key


func _reachable_from(start_key: String) -> Dictionary:
	var result: Dictionary = {}
	var pending: Array[String] = [start_key]
	while not pending.is_empty():
		var key: String = pending.pop_back()
		if result.has(key):
			continue
		result[key] = true
		for next_key: String in route_edges.get(key, []):
			pending.append(next_key)
	return result


func _refresh_route_states() -> void:
	if route_nodes.is_empty():
		return
	var current_column: int = -1
	if route_nodes.has(route_current_key):
		current_column = int(route_nodes[route_current_key].column)
	var available: Array = [route_start_key] if route_current_key.is_empty() else \
			route_edges.get(route_current_key, []) if route_completed_keys.has(route_current_key) else []
	for key: String in route_nodes:
		var node: Dictionary = route_nodes[key]
		if route_bypassed_keys.has(key):
			node.visit_state = "bypassed"
		elif key == route_current_key:
			node.visit_state = "current"
		elif route_completed_keys.has(key):
			node.visit_state = "completed"
		elif available.has(key):
			node.visit_state = "available"
		else:
			node.visit_state = "locked"
		var distance: int = int(node.column) - current_column
		if node.visit_state in ["current", "completed", "available"] or distance <= 1:
			node.reveal_state = "revealed"
		else:
			# Future room categories remain visible from the beginning. Exact
			# occupants and stats are still held back until the route gets close.
			node.reveal_state = "silhouette"
		route_nodes[key] = node


## Developer-only map jump. Preserve the run's inventory while making the
## selected room current and replayable, even after a previous completion.
func debug_jump_to_route_node(route_key: String, depth: int) -> bool:
	PlayerStats.mark_debug_assisted()
	ensure_tundra_route_plan()
	if not route_nodes.has(route_key):
		return false
	route_current_key = route_key
	route_pending_destination = ""
	route_depth = int(route_nodes[route_key].column) + 1
	encounter_index = ENCOUNTERS_PER_RUN if route_key == route_boss_key else \
		mini(1 + int(floor(float(route_depth) / 2.0)), ENCOUNTERS_PER_RUN - 1)
	is_run_active = true
	completed_encounters.erase(ENCOUNTERS_PER_RUN)
	pending_route_activity = ""
	pending_route_key = ""
	pending_optional_encounter = ""
	next_enemy_id = ""
	pending_encounter_modifier.clear()
	clear_pending_victory()
	route_completed_keys.erase(route_key)
	route_bypassed_keys.erase(route_key)
	var type: String = String(route_nodes[route_key].node_type)
	if type not in ["normal_combat", "elite_combat", "boss"]:
		var activity_id: String = route_activity_id(route_key)
		optional_encounters.erase(activity_id)
		optional_encounter_progress.erase(activity_id)
		if activity_id == "ice_fishing":
			fishing_hole_chosen = -1
	else:
		next_enemy_id = String(route_nodes[route_key].content_id)
	_refresh_route_states()
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
	# The generated route can contain five regular fights, while the biome
	# currently has four regular enemy types. Once every type has appeared,
	# offer repeats so the expedition can never dead-end before the boss.
	if available.size() < limit:
		for enemy_id: String in route_enemy_order:
			if available.has(enemy_id):
				continue
			available.append(enemy_id)
			if available.size() >= limit:
				break
	return available


func add_gold(amount: int) -> void:
	gold += amount
	if amount > 0:
		gold_earned_this_run += amount
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
	pos: String = "",
	metadata: Dictionary = {}
) -> bool:
	var earned_star_coin := PlayerProfile.record_unique_word(word)
	word_history.append({
		"word": word,
		"enemy": enemy_name,
		"tags": tags.duplicate(),
		"damage": damage,
		"pos": pos,
		"encounter": encounter_index,
		"effectiveness_label": String(
			metadata.get("effectiveness_label", "Unavailable")
		),
		"effectiveness": float(metadata.get("effectiveness", 0.0)),
		"semantic_multiplier": float(
			metadata.get("semantic_multiplier", 0.0)
		),
	})
	return earned_star_coin


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
	if not optional_encounter_available(id) or not _route_key_is_active(route_key):
		return false
	pending_optional_encounter = id
	pending_route_activity = id
	pending_route_key = route_key
	return true


func begin_route_utility(id: String, route_key: String) -> bool:
	if id != "forge" or not _route_key_is_active(route_key):
		return false
	pending_route_activity = id
	pending_route_key = route_key
	return true
