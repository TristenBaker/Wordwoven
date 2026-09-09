class_name EnemyFactory
extends Node
## Loads enemy definitions from data and builds the spawn data for
## an encounter: stats plus randomly rolled word tags. Tiers gate
## which enemies appear at which stage of the run; the highest tier
## is reserved for the final boss.

const ENEMIES_DATA_PATH: String = "res://data/enemies.json"
const BOSS_TIER: int = 4

# Enemy id -> definition dictionary, loaded once.
var _definitions: Dictionary = {}


func _ready() -> void:
	_load_definitions()


## Enemy ids whose tier suits the given encounter stage (1-based).
func ids_for_stage(stage: int) -> Array[String]:
	var tier: int = _tier_for_stage(stage)
	var ids: Array[String] = []
	for id: String in _definitions:
		if _definitions[id]["tier"] == tier:
			ids.append(id)
	return ids


## The boss enemy id (first definition at the boss tier).
func boss_id() -> String:
	for id: String in _definitions:
		if _definitions[id]["tier"] == BOSS_TIER:
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
	return {
		"id": enemy_id,
		"name": definition["name"],
		"health": int(definition["health"]),
		"attack": int(definition["attack"]),
		"gold": int(definition["gold"]),
		"texture": definition["texture"],
		"frame_width": int(definition["frame_width"]),
		"tags": tags,
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
