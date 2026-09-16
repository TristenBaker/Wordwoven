class_name EncounterAbilityRegistry
extends RefCounted
## Maps ability ids used in enemy and environment data to their
## behavior handlers. New behavior registers one handler here; new
## enemies reusing existing abilities need only data.

static var _handlers: Dictionary[String, EncounterAbility] = {}


## The handler for an ability id, or null when none is registered.
static func handler(ability_id: String) -> EncounterAbility:
	_ensure_defaults()
	return _handlers.get(ability_id, null)


static func has_handler(ability_id: String) -> bool:
	return handler(ability_id) != null


static func register(
	ability_id: String, ability: EncounterAbility
) -> void:
	_ensure_defaults()
	_handlers[ability_id] = ability


static func _ensure_defaults() -> void:
	if not _handlers.is_empty():
		return
	_handlers["steal_tile"] = StealTileAbility.new()
	_handlers["poison_tile"] = PoisonTileAbility.new()
	_handlers["freeze_tiles"] = FreezeTilesAbility.new()
