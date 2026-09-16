class_name RelicEffectRegistry
extends RefCounted
## Maps relic effect types used in data to their handlers. A new
## kind of relic effect registers one handler here.

static var _handlers: Dictionary[String, RelicEffect] = {}


## The handler for an effect type, or null when none is registered.
static func handler(effect_type: String) -> RelicEffect:
	_ensure_defaults()
	return _handlers.get(effect_type, null)


static func register(effect_type: String, effect: RelicEffect) -> void:
	_ensure_defaults()
	_handlers[effect_type] = effect


static func _ensure_defaults() -> void:
	if not _handlers.is_empty():
		return
	for stat: String in [
		"victory_gold", "damage_multiplier", "counter_bonus", "hand_size",
	]:
		_handlers[stat] = StatBonusRelicEffect.new(stat)
	_handlers["max_health"] = MaxHealthRelicEffect.new()
