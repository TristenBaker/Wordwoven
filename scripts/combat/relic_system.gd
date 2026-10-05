class_name RelicSystem
extends RefCounted
## Owns the power catalog, weighted rarity rolls, and reward guard.

const RELICS_DATA_PATH: String = "res://data/relics.json"

var _relics: Dictionary = {}

const QUALITY_WEIGHTS: Dictionary[String, int] = {
	"common": 60,
	"uncommon": 20,
	"rare": 15,
	"legendary": 5,
}

const QUALITY_COLORS: Dictionary[String, Color] = {
	"common": Color("d8d1c1"),
	"uncommon": Color("72d78a"),
	"rare": Color("65b7ff"),
	"legendary": Color("d998ff"),
}


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


func roll_choices(count: int) -> Array[String]:
	var available: Array[String] = relic_ids()
	var choices: Array[String] = []
	if count <= 0:
		return choices
	var guaranteed_index: int = randi_range(0, count - 1)
	while choices.size() < count and not available.is_empty():
		var allows_common: bool = choices.size() != guaranteed_index
		var quality: String = _roll_quality(allows_common)
		var candidates: Array[String] = []
		for power_id: String in available:
			var info: Dictionary = relic_info(power_id)
			if info.get("quality", "common") == quality:
				candidates.append(power_id)
		if candidates.is_empty():
			candidates = available
		var choice: String = candidates.pick_random()
		choices.append(choice)
		available.erase(choice)
	return choices


func quality_name(power_id: String) -> String:
	return String(relic_info(power_id).get("quality", "common")).capitalize()


func quality_color(power_id: String) -> Color:
	var quality: String = String(
		relic_info(power_id).get("quality", "common")
	)
	return QUALITY_COLORS.get(quality, QUALITY_COLORS["common"])


func affecting_power_ids(element: int) -> Array[String]:
	var ids: Array[String] = []
	for power_id: String in RunState.relics:
		if ids.has(power_id):
			continue
		var effect: String = String(relic_info(power_id).get("effect", ""))
		if _effect_applies_to_element(effect, element):
			ids.append(power_id)
	return ids


func _effect_applies_to_element(effect: String, element: int) -> bool:
	var element_name: String = LetterStats.Element.keys()[element].to_lower()
	return effect == "all_element_damage_multiplier" \
		or effect == "hand_size" \
		or effect.begins_with(element_name + "_")


func _roll_quality(allows_common: bool = true) -> String:
	var total: int = 0
	for quality: String in QUALITY_WEIGHTS:
		if allows_common or quality != "common":
			total += QUALITY_WEIGHTS[quality]
	var roll: int = randi_range(1, total)
	var running_total: int = 0
	for quality: String in ["common", "uncommon", "rare", "legendary"]:
		if not allows_common and quality == "common":
			continue
		running_total += QUALITY_WEIGHTS[quality]
		if roll <= running_total:
			return quality
	return "common"


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
