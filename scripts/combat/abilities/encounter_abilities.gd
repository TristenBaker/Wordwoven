class_name EncounterAbilities
extends RefCounted
## The active ability entries of one encounter, gathered from the
## enemy and its environment, dispatched through the registry.

# Entries of {"id": String, "params": Dictionary}.
var _entries: Array[Dictionary] = []


## Adds data entries such as {"id": "steal_tile", "count": 1}.
## Unknown ids are reported and skipped.
func add_entries(entries: Array) -> void:
	for raw: Variant in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			push_error("EncounterAbilities: entry is not a dictionary")
			continue
		var entry: Dictionary = raw
		var ability_id: String = String(entry.get("id", ""))
		if not EncounterAbilityRegistry.has_handler(ability_id):
			push_error("EncounterAbilities: unknown " + ability_id)
			continue
		_entries.append({"id": ability_id, "params": entry})


func ability_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in _entries:
		ids.append(entry["id"])
	return ids


func after_enemy_attack(context: AbilityContext) -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in _entries:
		lines.append_array(_handler_for(entry).after_enemy_attack(
			context, entry["params"]
		))
	return lines


func on_player_turn_start(context: AbilityContext) -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in _entries:
		lines.append_array(_handler_for(entry).on_player_turn_start(
			context, entry["params"]
		))
	return lines


func descriptions() -> Array[String]:
	return EncounterAbilities.describe_entries(_entries_as_data())


## Summaries for raw data entries, for previews before combat.
static func describe_entries(entries: Array) -> Array[String]:
	var lines: Array[String] = []
	for raw: Variant in entries:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw
		var ability: EncounterAbility = EncounterAbilityRegistry.handler(
			String(entry.get("id", ""))
		)
		if ability != null:
			lines.append(ability.describe(entry))
	return lines


func _handler_for(entry: Dictionary) -> EncounterAbility:
	return EncounterAbilityRegistry.handler(entry["id"])


func _entries_as_data() -> Array:
	var data: Array = []
	for entry: Dictionary in _entries:
		data.append(entry["params"])
	return data
