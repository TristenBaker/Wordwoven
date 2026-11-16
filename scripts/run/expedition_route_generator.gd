class_name ExpeditionRouteGenerator
extends RefCounted
## Seeded layered-DAG route generator with deliberately variable run shapes.
##
## Guarantees:
## - The same seed always creates the same route.
## - Every route starts with one combat encounter and ends with one boss.
## - Every generated map contains at least twenty nodes.
## - The complete map contains at least eight traditional fight nodes.
## - Intermediate columns contain one to three rooms.
## - Total route length varies from nine to eleven columns.
## - At least one lore room appears, but its position is randomized.
## - Forge rooms are never generated.

const Balance = preload("res://data/balance/tuning.gd")

const MIN_TOTAL_COLUMNS: int = 9
const MAX_TOTAL_COLUMNS: int = 11
const MIN_ROUTE_NODES: int = 20
const MIN_COMBAT_NODES: int = 8 # Includes the starting fight.
const MIN_COLUMN_WIDTH: int = 1
const MAX_COLUMN_WIDTH: int = 3
const LANE_BRIDGE_CHANCE: float = 0.4

const ACTIVITY_CONTENT: Dictionary[String, String] = {
	"treasure": "treasure_chest",
	"letter_reward": "ice_fishing",
	"relic_reward": "hangman",
	"recovery": "frozen_traveler",
	"random_event": "icy_portal",
	"lore": "lore_room",
}

# These are used when tuning.gd does not provide a weight for an activity.
# Forge is intentionally absent, even if ROUTE_ACTIVITY_WEIGHTS contains it.
const DEFAULT_ACTIVITY_WEIGHTS: Dictionary[String, int] = {
	"treasure": 3,
	"letter_reward": 3,
	"relic_reward": 3,
	"recovery": 3,
	"random_event": 3,
	"lore": 2,
}


static func generate(seed_value: int, biome: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var total_columns: int = rng.randi_range(
		MIN_TOTAL_COLUMNS, MAX_TOTAL_COLUMNS
	)
	var last_column: int = total_columns - 1
	var column_widths: Array[int] = _build_column_widths(
		total_columns, last_column, rng
	)
	var combat_slots: Dictionary = _choose_combat_slots(
		column_widths, last_column, rng
	)
	var enemies: Array[String] = \
		Balance.ENEMY_FACTORY_TUNDRA_REGULARS.duplicate()
	_shuffle_with_rng(enemies, rng)

	var columns: Array = []
	var nodes: Dictionary = {}
	var enemy_cursor: int = 0

	for column: int in range(total_columns):
		var width: int = column_widths[column]
		var keys: Array[String] = []
		var activities_used_here: Array[String] = []

		for lane: int in width:
			var key := "route_%d_%d" % [column, lane]
			var node_type := "normal_combat"
			var content_id := ""
			var reward_tier := 1
			var threat_tier := 1

			if column == last_column:
				node_type = "boss"
				content_id = Balance.TUNDRA_BOSS_ENEMY
				reward_tier = 4
				threat_tier = 4
			elif column == 0:
				content_id = Balance.TUNDRA_STARTER_ENEMY
				reward_tier = 2
				threat_tier = 2
			elif combat_slots.has("%d:%d" % [column, lane]):
				var elite: bool = lane == width - 1 and rng.randf() < 0.32
				node_type = "elite_combat" if elite else "normal_combat"
				content_id = enemies[enemy_cursor % enemies.size()]
				enemy_cursor += 1
				reward_tier = 3 if elite else 2
				threat_tier = 3 if elite else 2
			else:
				node_type = _weighted_activity(
					rng, activities_used_here
				)
				activities_used_here.append(node_type)
				content_id = ACTIVITY_CONTENT[node_type]
				reward_tier = _activity_reward_tier(node_type)
				threat_tier = _activity_threat_tier(node_type)

			nodes[key] = {
				"route_key": key,
				"column": column,
				"lane": lane,
				"lane_count": width,
				"node_type": node_type,
				"content_id": content_id,
				"next_keys": [],
				"reward_tier": reward_tier,
				"threat_tier": threat_tier,
				"reveal_state": "hidden",
				"visit_state": "locked",
				"biome": biome,
			}
			keys.append(key)

		columns.append(keys)

	# Lore can occupy any activity slot. If the weighted rolls did not create
	# one, replace a random activity so the story remains discoverable.
	_ensure_lore_room(nodes, rng)
	_connect_columns(columns, nodes)
	_connect_lane_bridges(columns, nodes, rng)

	return {
		"seed": seed_value,
		"biome": biome,
		"start_key": String(columns[0][0]),
		"boss_key": String(columns[-1][0]),
		"columns": columns,
		"nodes": nodes,
	}


static func _column_width(
	column: int, last_column: int, rng: RandomNumberGenerator
) -> int:
	if column == 0 or column == last_column:
		return 1
	if column == 1:
		# Preserve an immediate choice, but do not force exactly three options.
		return rng.randi_range(2, MAX_COLUMN_WIDTH)
	return rng.randi_range(MIN_COLUMN_WIDTH, MAX_COLUMN_WIDTH)


static func _build_column_widths(
	total_columns: int,
	last_column: int,
	rng: RandomNumberGenerator
) -> Array[int]:
	var widths: Array[int] = []
	for column: int in total_columns:
		widths.append(_column_width(column, last_column, rng))

	# Keep route length variable, but expand random intermediate columns until
	# the complete map has enough rooms to support meaningful route planning.
	while _total_width(widths) < MIN_ROUTE_NODES:
		var expandable: Array[int] = []
		for column: int in range(1, last_column):
			if widths[column] < MAX_COLUMN_WIDTH:
				expandable.append(column)
		if expandable.is_empty():
			break
		var chosen: int = expandable[
			rng.randi_range(0, expandable.size() - 1)
		]
		widths[chosen] += 1

	# Multi-node columns reserve at least one activity slot. Widen random
	# columns until the remaining slots can hold seven additional fights.
	while _combat_slot_capacity(widths, last_column) < MIN_COMBAT_NODES - 1:
		var expandable: Array[int] = []
		for column: int in range(1, last_column):
			if widths[column] < MAX_COLUMN_WIDTH:
				expandable.append(column)
		if expandable.is_empty():
			break
		var chosen: int = expandable[
			rng.randi_range(0, expandable.size() - 1)
		]
		widths[chosen] += 1
	return widths


static func _total_width(widths: Array[int]) -> int:
	var total := 0
	for width: int in widths:
		total += width
	return total


static func _combat_slot_capacity(
	widths: Array[int], last_column: int
) -> int:
	var capacity := 0
	for column: int in range(1, last_column):
		var width: int = widths[column]
		# Preserve one non-combat choice whenever a column has multiple nodes.
		capacity += width - 1 if width > 1 else 1
	return capacity


static func _choose_combat_slots(
	widths: Array[int],
	last_column: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	var candidates_by_column: Dictionary = {}
	var column_order: Array[int] = []

	for column: int in range(1, last_column):
		var lanes: Array[int] = []
		for lane: int in widths[column]:
			lanes.append(lane)
		_shuffle_with_rng(lanes, rng)
		if widths[column] > 1:
			# Reserve one lane for a minigame, event, recovery, or lore room.
			lanes.pop_back()
		candidates_by_column[column] = lanes
		column_order.append(column)

	_shuffle_with_rng(column_order, rng)
	var selected: Dictionary = {}
	var fights_needed: int = MIN_COMBAT_NODES - 1

	# Spread fights across columns before adding a second fight to any column.
	while fights_needed > 0:
		var added_this_pass := false
		for column: int in column_order:
			var lanes: Array = candidates_by_column[column]
			if lanes.is_empty():
				continue
			var lane: int = int(lanes.pop_back())
			selected["%d:%d" % [column, lane]] = true
			fights_needed -= 1
			added_this_pass = true
			if fights_needed <= 0:
				break
		if not added_this_pass:
			break

	return selected


static func _weighted_activity(
	rng: RandomNumberGenerator,
	avoid: Array[String] = []
) -> String:
	var candidates: Array[String] = []
	var total_weight := 0

	# Prefer different activities inside the same column. If every option was
	# excluded, retry without the avoidance list.
	for id: String in ACTIVITY_CONTENT:
		# Lore is placed separately after generation so it has one unbiased,
		# seed-dependent location instead of behaving like a repeated minigame.
		if id == "lore":
			continue
		if avoid.has(id):
			continue
		var weight := _activity_weight(id)
		if weight <= 0:
			continue
		candidates.append(id)
		total_weight += weight

	if candidates.is_empty():
		return _weighted_activity(rng, []) if not avoid.is_empty() \
			else "random_event"

	var roll := rng.randi_range(1, total_weight)
	for id: String in candidates:
		roll -= _activity_weight(id)
		if roll <= 0:
			return id
	return candidates[-1]


static func _activity_weight(id: String) -> int:
	return maxi(
		0,
		int(Balance.ROUTE_ACTIVITY_WEIGHTS.get(
			id, DEFAULT_ACTIVITY_WEIGHTS.get(id, 1)
		))
	)


static func _activity_reward_tier(node_type: String) -> int:
	return 2 if node_type in [
		"treasure", "letter_reward", "relic_reward"
	] else 1


static func _activity_threat_tier(node_type: String) -> int:
	return 1 if node_type in ["treasure", "random_event"] else 0


static func _ensure_lore_room(
	nodes: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	for key: String in nodes:
		if String(nodes[key].get("content_id", "")) == "lore_room":
			return

	var possible_keys: Array[String] = []
	for key: String in nodes:
		var type: String = String(nodes[key].get("node_type", ""))
		if type not in ["normal_combat", "elite_combat", "boss"]:
			possible_keys.append(key)
	if possible_keys.is_empty():
		return

	var chosen_key: String = possible_keys[
		rng.randi_range(0, possible_keys.size() - 1)
	]
	var node: Dictionary = nodes[chosen_key]
	node["node_type"] = "lore"
	node["content_id"] = "lore_room"
	node["reward_tier"] = 0
	node["threat_tier"] = 0
	nodes[chosen_key] = node


static func _connect_columns(columns: Array, nodes: Dictionary) -> void:
	for column: int in range(columns.size() - 1):
		var sources: Array = columns[column]
		var destinations: Array = columns[column + 1]
		var incoming: Dictionary = {}

		for destination: String in destinations:
			incoming[destination] = 0

		for source_index: int in sources.size():
			var source: String = sources[source_index]
			var exits: Array[String] = []

			if sources.size() == 1:
				# A single room may open into as many as three choices.
				for destination: String in destinations:
					exits.append(destination)
			elif destinations.size() == 1:
				exits.append(String(destinations[0]))
			else:
				# Map the source to the nearest lane in the differently sized
				# destination column, then add one local branch when possible.
				var normalized := (
					float(source_index) / float(maxi(sources.size() - 1, 1))
				)
				var center := clampi(
					roundi(normalized * float(destinations.size() - 1)),
					0,
					destinations.size() - 1
				)
				exits.append(String(destinations[center]))

				var neighbor := center + (-1 if column % 2 == 0 else 1)
				if neighbor < 0 or neighbor >= destinations.size():
					neighbor = center + (1 if column % 2 == 0 else -1)
				if neighbor >= 0 and neighbor < destinations.size():
					exits.append(String(destinations[neighbor]))

			nodes[source]["next_keys"] = exits
			for destination: String in exits:
				incoming[destination] = int(incoming[destination]) + 1

		# Guarantee that every generated room can actually be reached.
		for destination_index: int in destinations.size():
			var destination: String = destinations[destination_index]
			if int(incoming[destination]) > 0:
				continue
			var source_index := mini(
				int(floor(
					float(destination_index) * sources.size()
					/ destinations.size()
				)),
				sources.size() - 1
			)
			var source: String = sources[source_index]
			if not nodes[source]["next_keys"].has(destination):
				nodes[source]["next_keys"].append(destination)


## Occasionally bridge across one missing same-lane slot. For example, lane 1
## may connect from column 2 directly to column 4 when column 3 has no lane 1.
static func _connect_lane_bridges(
	columns: Array,
	nodes: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	for column: int in range(columns.size() - 2):
		var middle_lanes: Dictionary = {}
		var destination_by_lane: Dictionary = {}
		for middle_key: String in columns[column + 1]:
			middle_lanes[int(nodes[middle_key].lane)] = true
		for destination_key: String in columns[column + 2]:
			destination_by_lane[int(nodes[destination_key].lane)] = destination_key

		for source_key: String in columns[column]:
			var lane: int = int(nodes[source_key].lane)
			if middle_lanes.has(lane) or not destination_by_lane.has(lane):
				continue
			if rng.randf() > LANE_BRIDGE_CHANCE:
				continue
			var destination_key: String = String(destination_by_lane[lane])
			if not nodes[source_key]["next_keys"].has(destination_key):
				nodes[source_key]["next_keys"].append(destination_key)


static func _shuffle_with_rng(
	values: Array, rng: RandomNumberGenerator
) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[other]
		values[other] = temporary
