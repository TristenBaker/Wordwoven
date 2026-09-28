class_name EnemyFactory
extends Node
## Loads enemy definitions from data and builds the spawn data for
## an encounter: stats plus randomly rolled word tags. Tiers gate
## which enemies appear at which stage of the run; the highest tier
## is reserved for the final boss.

const ENEMIES_DATA_PATH: String = "res://data/enemies.json"
const BOSS_TIER: int = 4
const TUNDRA_REGULARS: Array[String] = [
	"glacier_bear", "frozen_revenant", "winter_wraith", "tundra_behemoth",
]

# Enemy id -> definition dictionary, loaded once.
var _definitions: Dictionary = {}


func _ready() -> void:
	_load_definitions()


## Enemy ids whose tier suits the given encounter stage (1-based).
func ids_for_stage(stage: int) -> Array[String]:
	if RunState.selected_biome == "tundra":
		if stage == 1:
			return ["frostfang_wolf"]
		if stage >= RunState.ENCOUNTERS_PER_RUN:
			return ["frost_wyrm"]
		var remaining: Array[String] = []
		for id: String in TUNDRA_REGULARS:
			if not RunState.defeated_enemy_ids.has(id):
				remaining.append(id)
		return remaining
	var tier: int = _tier_for_stage(stage)
	var ids: Array[String] = []
	for id: String in _definitions:
		if _definitions[id].get("biome", "") == "" and _definitions[id]["tier"] == tier:
			ids.append(id)
	return ids


## The boss enemy id (first definition at the boss tier).
func boss_id() -> String:
	if RunState.selected_biome == "tundra":
		return "frost_wyrm"
	for id: String in _definitions:
		if _definitions[id].get("biome", "") == "" and _definitions[id]["tier"] == BOSS_TIER:
			return id
	return ""


## Builds spawn data for one encounter: the definition's stats with
## tags rolled randomly from its pool.
## Returns {"id", "name", "health", "attack", "gold", "texture",
## "frame_width", "tags"}.
func build_spawn_data(enemy_id: String) -> Dictionary:
	if not _definitions.has(enemy_id):
		push_error("EnemyFactory: unknown enemy " + enemy_id)
		return {}
	var definition: Dictionary = _definitions[enemy_id]
	var pool: Array = definition["tag_pool"].duplicate()
	pool.shuffle()
	var tags: Array[String] = []
	var tag_count: int = definition["tag_count"]
	for i: int in mini(tag_count, pool.size()):
		tags.append(pool[i])
	# The debug overlay can force specific tags for testing.
	if not DebugTools.forced_tags.is_empty():
		tags = DebugTools.forced_tags.duplicate()
	# Regular Tundra foes grow with their chosen slot, regardless of order.
	var growth: int = 0
	if definition.get("biome", "") == "tundra" and enemy_id in TUNDRA_REGULARS:
		growth = clampi(RunState.encounter_index - 2, 0, 3)
	return {
		"id": enemy_id,
		"name": definition["name"],
		"health": int(definition["health"]) + growth * 6,
		"attack": int(definition["attack"]) + growth,
		"gold": int(definition["gold"]) + growth * 6,
		"texture": definition["texture"],
		"frame_width": int(definition["frame_width"]),
		"tags": tags,
		"affinities": definition.get("affinities", {}),
		"black_matte": bool(definition.get("black_matte", false)),
		"idle_frames": int(definition.get("idle_frames", 1)),
		"idle_fps": float(definition.get("idle_fps", 5.0)),
		"idle_top": int(definition.get("idle_top", 0)),
		"idle_height": int(definition.get("idle_height", 0)),
		"display_size": float(definition.get("display_size", 0.0)),
	}


## Builds spawn data with forced tags, for the debug tools.
func build_spawn_data_with_tags(
	enemy_id: String, tags: Array[String]
) -> Dictionary:
	var data: Dictionary = build_spawn_data(enemy_id)
	if not data.is_empty():
		data["tags"] = tags
	return data


func _tier_for_stage(stage: int) -> int:
	if stage >= RunState.ENCOUNTERS_PER_RUN:
		return BOSS_TIER
	return clampi(floor((stage + 1) / 2.0), 1, 3)


func _load_definitions() -> void:
	var file: FileAccess = FileAccess.open(
		ENEMIES_DATA_PATH, FileAccess.READ
	)
	if file == null:
		push_error("EnemyFactory: cannot open enemy data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EnemyFactory: enemy data is not valid JSON")
		return
	_definitions = parsed
