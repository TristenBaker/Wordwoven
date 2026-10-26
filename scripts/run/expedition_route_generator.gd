class_name ExpeditionRouteGenerator
extends RefCounted
## Deterministic layered-DAG generator. It owns no run state and never uses
## global randomness, so a seed can be replayed exactly in tests or debugging.

const Balance = preload("res://data/balance/tuning.gd")

const COMBAT_COLUMNS: Array[int] = [0, 2, 4, 6]
const ACTIVITY_CONTENT: Dictionary[String, String] = {
	"treasure": "treasure_chest",
	"letter_reward": "ice_fishing",
	"relic_reward": "hangman",
	"recovery": "frozen_traveler",
	"forge": "forge",
	"random_event": "icy_portal",
	"lore": "lore_room",
}


static func generate(seed_value: int, biome: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var last_column: int = Balance.ROUTE_INTERMEDIATE_COLUMNS + 1
	var columns: Array = []
	var nodes: Dictionary = {}
	var build_types: Array[String] = ["letter_reward", "relic_reward", "forge"]
	_shuffle_with_rng(build_types, rng)
	var opening_types: Array[String] = ["recovery", "treasure", "random_event"]
	_shuffle_with_rng(opening_types, rng)
	var enemies: Array[String] = Balance.ENEMY_FACTORY_TUNDRA_REGULARS.duplicate()
	_shuffle_with_rng(enemies, rng)
	var enemy_cursor: int = 0

	for column: int in range(last_column + 1):
		var width: int = 1
		if column > 0 and column < last_column:
			width = rng.randi_range(
				Balance.ROUTE_MIN_NODES_PER_COLUMN,
				Balance.ROUTE_MAX_NODES_PER_COLUMN
			)
		# The route opens into three persistent lanes immediately. Keeping full
		# layers gives almost every room two meaningful onward choices without
		# turning the connections into an unreadable all-to-all web.
		if column > 0 and column < last_column:
			width = 3
		var keys: Array[String] = []
		for lane: int in width:
			var key: String = "route_%d_%d" % [column, lane]
			var node_type: String = "normal_combat"
			var content_id: String = ""
			var reward_tier: int = 1
			var threat_tier: int = 1
			if column == last_column:
				node_type = "boss"
				content_id = Balance.TUNDRA_BOSS_ENEMY
				reward_tier = 4
				threat_tier = 4
			elif column == 0:
				content_id = Balance.TUNDRA_STARTER_ENEMY
			elif column == 1:
				# Every run opens with three clearly different routes. Their lane
				# order changes with the seed, and these activities may reappear on
				# later branches.
				node_type = opening_types[lane]
				content_id = ACTIVITY_CONTENT[node_type]
				reward_tier = 2 if node_type == "treasure" else 1
				threat_tier = 1 if node_type in ["treasure", "random_event"] else 0
			elif column == 3 and lane < 2:
				# Two routes can carry the same story beat. Choosing either still
				# advances the run and the third lane remains a gameplay alternative.
				node_type = "lore"
				content_id = "lore_room"
				reward_tier = 0
				threat_tier = 0
			elif column in COMBAT_COLUMNS:
				var elite: bool = column > 0 and lane == width - 1 \
						and rng.randf() < 0.38
				node_type = "elite_combat" if elite else "normal_combat"
				content_id = enemies[enemy_cursor % enemies.size()]
				enemy_cursor += 1
				reward_tier = 3 if elite else 2
				threat_tier = 3 if elite else 2
			elif column == 5:
				node_type = build_types[lane]
				content_id = ACTIVITY_CONTENT[node_type]
				reward_tier = 2
				threat_tier = 0
			else:
				node_type = _weighted_activity(rng)
				content_id = ACTIVITY_CONTENT[node_type]
				reward_tier = 2 if node_type in ["forge", "letter_reward", "relic_reward", "treasure"] else 1
				threat_tier = 1 if node_type in ["treasure", "random_event"] else 0
			var node: Dictionary = {
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
			nodes[key] = node
			keys.append(key)
		columns.append(keys)

	_connect_columns(columns, nodes)
	return {
		"seed": seed_value,
		"biome": biome,
		"start_key": String(columns[0][0]),
		"boss_key": String(columns[-1][0]),
		"columns": columns,
		"nodes": nodes,
	}


static func _weighted_activity(rng: RandomNumberGenerator) -> String:
	var candidates: Array[String] = []
	var total: int = 0
	for id: String in Balance.ROUTE_ACTIVITY_WEIGHTS:
		candidates.append(id)
		total += int(Balance.ROUTE_ACTIVITY_WEIGHTS[id])
	if candidates.is_empty():
		# Combat is a safe non-unique fallback and can never dead-end.
		return "random_event"
	var roll: int = rng.randi_range(1, total)
	for id: String in candidates:
		roll -= int(Balance.ROUTE_ACTIVITY_WEIGHTS[id])
		if roll <= 0:
			return id
	return candidates[-1]


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
				# The expedition always begins with an immediate, legible split.
				for destination: String in destinations:
					exits.append(destination)
			elif destinations.size() == 1:
				exits.append(String(destinations[0]))
			else:
				var center: int = mini(source_index, destinations.size() - 1)
				exits.append(String(destinations[center]))
				# Every lane branches locally. Outer lanes bend inward; the middle
				# alternates direction by column to keep the graph braided and clear.
				var neighbor: int
				if center == 0:
					neighbor = 1
				elif center == destinations.size() - 1:
					neighbor = center - 1
				else:
					neighbor = center - 1 if column % 2 == 0 else center + 1
				if neighbor >= 0 and neighbor < destinations.size():
					exits.append(String(destinations[neighbor]))
			nodes[source]["next_keys"] = exits
			for destination: String in exits:
				incoming[destination] = int(incoming[destination]) + 1
		for destination_index: int in destinations.size():
			var destination: String = destinations[destination_index]
			if int(incoming[destination]) > 0:
				continue
			var source_index: int = mini(
				int(floor(float(destination_index) * sources.size() / destinations.size())),
				sources.size() - 1
			)
			var source: String = sources[source_index]
			if not nodes[source]["next_keys"].has(destination):
				nodes[source]["next_keys"].append(destination)


static func _shuffle_with_rng(values: Array, rng: RandomNumberGenerator) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var temporary: Variant = values[index]
		values[index] = values[other]
		values[other] = temporary
