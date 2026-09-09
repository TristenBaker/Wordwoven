class_name RelicSystem
extends RefCounted
## Owns the catalog and one-time victory reward guard for relics.

const RELICS_DATA_PATH: String = "res://data/relics.json"

var _relics: Dictionary = {}


func _init() -> void:
	var file: FileAccess = FileAccess.open(
		RELICS_DATA_PATH, FileAccess.READ
	)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_relics = parsed


func relic_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _relics:
		ids.append(id)
	return ids


func relic_info(relic_id: String) -> Dictionary:
	return _relics.get(relic_id, {})


func total_effect(effect: String) -> float:
	var total: float = 0.0
	for relic_id: String in RunState.relics:
		var info: Dictionary = relic_info(relic_id)
		if info.get("effect", "") == effect:
			total += float(info.get("amount", 0.0))
	return total


func grant_reward(relic_id: String, encounter: int) -> bool:
	if not _relics.has(relic_id):
		return false
	if not RunState.completed_encounters.has(encounter):
		return false
	if RunState.relic_rewards.has(encounter):
		return false
	RunState.relic_rewards[encounter] = relic_id
	RunState.relics.append(relic_id)
	var info: Dictionary = relic_info(relic_id)
	if info.get("effect", "") == "max_health":
		var amount: int = int(info.get("amount", 0))
		RunState.player_max_health += amount
		RunState.heal_player(amount)
	EventBus.emit_relic_gained(relic_id)
	return true
