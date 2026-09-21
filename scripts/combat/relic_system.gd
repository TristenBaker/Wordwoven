class_name RelicSystem
extends RefCounted
## Totals owned relic effects and guards one-time victory rewards.
## Definitions come from the cached RelicCatalog.


func relic_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in RelicCatalog.relics():
		ids.append(id)
	return ids


func relic_info(relic_id: String) -> Dictionary:
	return RelicCatalog.relics().get(relic_id, {})


## Sum of a passive stat across every owned relic copy.
func total_effect(effect: String) -> float:
	var total: float = 0.0
	for relic_id: String in RunState.relics:
		for params: Dictionary in RelicCatalog.effects_of(
			relic_info(relic_id)
		):
			var handler: RelicEffect = RelicEffectRegistry.handler(
				String(params.get("type", ""))
			)
			if handler != null:
				total += handler.stat_bonus(effect, params)
	return total


func grant_reward(relic_id: String, encounter: int) -> bool:
	if not RelicCatalog.relics().has(relic_id):
		return false
	if not RunState.completed_encounters.has(encounter):
		return false
	if RunState.relic_rewards.has(encounter):
		return false
	RunState.relic_rewards[encounter] = relic_id
	return grant_relic(relic_id)


## Adds one relic copy and applies its one-time effects. Callers own
## the guard against granting the same reward twice.
func grant_relic(relic_id: String) -> bool:
	if not RelicCatalog.relics().has(relic_id):
		return false
	RunState.relics.append(relic_id)
	for params: Dictionary in RelicCatalog.effects_of(
		relic_info(relic_id)
	):
		var handler: RelicEffect = RelicEffectRegistry.handler(
			String(params.get("type", ""))
		)
		if handler != null:
			handler.on_granted(params)
	EventBus.emit_relic_gained(relic_id)
	return true
