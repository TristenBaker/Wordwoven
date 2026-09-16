class_name EnvironmentCatalog
extends RefCounted
## Loads encounter environments from data once and rolls one for an
## encounter option. Environment abilities stay separate from the
## enemy's chosen tag.

const DATA_PATH: String = "res://data/environments.json"
const NORMAL: String = "normal"
const ICY: String = "icy"
const DEFAULT_ICY_CHANCE: float = 1.0 / 3.0

static var _environments: Dictionary = {}


static func has_environment(environment_id: String) -> bool:
	return _catalog().has(environment_id)


static func info(environment_id: String) -> Dictionary:
	return _catalog().get(environment_id, {})


static func display_name(environment_id: String) -> String:
	return String(info(environment_id).get("name", environment_id))


## The environment's ability entries, in encounter-ability format.
static func abilities(environment_id: String) -> Array:
	return info(environment_id).get("abilities", [])


## Name, description, and ability summaries as one preview text.
static func describe(environment_id: String) -> String:
	var lines: Array[String] = [
		"%s: %s" % [
			display_name(environment_id),
			info(environment_id).get("description", ""),
		]
	]
	lines.append_array(
		EncounterAbilities.describe_entries(abilities(environment_id))
	)
	return "\n".join(lines)


## A random background texture for the environment, or null.
static func pick_background(
	environment_id: String, rng: RandomNumberGenerator
) -> Texture2D:
	var backgrounds: Array = info(environment_id).get("backgrounds", [])
	if backgrounds.is_empty():
		return null
	var index: int = rng.randi_range(0, backgrounds.size() - 1)
	return load(String(backgrounds[index])) as Texture2D


static func roll(
	rng: RandomNumberGenerator, icy_chance: float = DEFAULT_ICY_CHANCE
) -> String:
	return ICY if rng.randf() < icy_chance else NORMAL


static func _catalog() -> Dictionary:
	if not _environments.is_empty():
		return _environments
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("EnvironmentCatalog: cannot open environment data")
		return _environments
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EnvironmentCatalog: environment data is invalid")
		return _environments
	_environments = parsed
	return _environments
