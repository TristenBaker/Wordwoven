class_name EventProgress
extends RefCounted
## Explicit progress through the two noncombat events that precede
## every combat stage, stored in RunState.event_stages. A stage's pair
## is generated once and retained; each event's parameters are rolled
## once when first opened; resolving or declining advances the slot
## without rerolling. Tavern visits never count toward the pair.

const EVENTS_PER_STAGE: int = 2

## Seeded by tests; otherwise randomized on first use.
static var rng: RandomNumberGenerator = null


static func generator() -> RandomNumberGenerator:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return rng


## The stage's retained entry, generating its pair the first time.
static func ensure_stage(stage: int) -> Dictionary:
	if RunState.event_stages.has(stage):
		return RunState.event_stages[stage]
	var types: Array[String] = pick_pair(stage)
	var events: Array[Dictionary] = []
	for event_type: String in types:
		events.append({
			"type": event_type,
			"stage": stage,
			"status": NoncombatEvent.STATUS_NEW,
			"params": {},
			"granted": [],
			"outcome": "",
		})
	RunState.event_stages[stage] = {
		"types": types, "events": events, "slot": 0,
	}
	return RunState.event_stages[stage]


## Two distinct eligible event types, avoiding the previous stage's
## types whenever enough other eligible events exist.
static func pick_pair(stage: int) -> Array[String]:
	var context: Dictionary = eligibility_context(stage)
	var eligible: Array[String] = []
	for event_id: String in EventCatalog.ids():
		if EventCatalog.handler(event_id).is_eligible(context):
			eligible.append(event_id)
	var previous: Array = []
	if RunState.event_stages.has(stage - 1):
		previous = RunState.event_stages[stage - 1]["types"]
	var fresh: Array[String] = []
	for event_id: String in eligible:
		if not previous.has(event_id):
			fresh.append(event_id)
	var picked: Array[String] = _draw(fresh, EVENTS_PER_STAGE)
	for event_id: String in picked:
		eligible.erase(event_id)
	picked.append_array(_draw(eligible, EVENTS_PER_STAGE - picked.size()))
	return picked


static func eligibility_context(stage: int) -> Dictionary:
	return {
		"stage": stage,
		"final": stage >= RunState.ENCOUNTERS_PER_RUN,
		"forgotten": RunState.forgotten_letter,
		"circulating": RunState.circulating_deck().size(),
	}


## True while the current stage still has an unfinished event slot.
static func has_pending(stage: int = RunState.encounter_index) -> bool:
	var entry: Dictionary = ensure_stage(stage)
	return int(entry["slot"]) < Array(entry["events"]).size()


## The state of the event in the current slot, prepared on first use;
## {} when both events are finished.
static func current_event(
	stage: int = RunState.encounter_index
) -> Dictionary:
	var entry: Dictionary = ensure_stage(stage)
	var slot: int = int(entry["slot"])
	var events: Array = entry["events"]
	if slot >= events.size():
		return {}
	var state: Dictionary = events[slot]
	if String(state["status"]) == NoncombatEvent.STATUS_NEW:
		var event: NoncombatEvent = EventCatalog.handler(state["type"])
		event.prepare(state, generator())
		state["status"] = NoncombatEvent.STATUS_OPEN
	return state


## 1-based number of the current slot, for "Event 1 of 2".
static func current_slot_number(
	stage: int = RunState.encounter_index
) -> int:
	return int(ensure_stage(stage)["slot"]) + 1


## Moves past the current event once it is resolved. Returns whether
## the slot advanced.
static func advance(stage: int = RunState.encounter_index) -> bool:
	var entry: Dictionary = ensure_stage(stage)
	var state: Dictionary = current_event(stage)
	if state.is_empty() \
			or String(state["status"]) != NoncombatEvent.STATUS_RESOLVED:
		return false
	entry["slot"] = int(entry["slot"]) + 1
	return true


## Every finished event across the run, in order.
static func finished_events() -> Array[Dictionary]:
	var finished: Array[Dictionary] = []
	var stages: Array = RunState.event_stages.keys()
	stages.sort()
	for stage: Variant in stages:
		var entry: Dictionary = RunState.event_stages[stage]
		var events: Array = entry["events"]
		for index: int in mini(int(entry["slot"]), events.size()):
			finished.append(events[index])
	return finished


static func _draw(pool: Array[String], count: int) -> Array[String]:
	var remaining: Array[String] = pool.duplicate()
	var drawn: Array[String] = []
	var source: RandomNumberGenerator = generator()
	while drawn.size() < count and not remaining.is_empty():
		var index: int = source.randi_range(0, remaining.size() - 1)
		drawn.append(remaining[index])
		remaining.remove_at(index)
	return drawn
