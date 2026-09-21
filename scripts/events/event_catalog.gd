class_name EventCatalog
extends RefCounted
## Loads noncombat event definitions from data/events.json and pairs
## each with its handler. Adding an event is a data entry plus one
## NoncombatEvent subclass registered in _handler_scripts().

const DATA_PATH: String = "res://data/events.json"

static var _handlers: Dictionary = {}
static var _order: Array[String] = []
static var _loaded: bool = false


## Event ids with both data and a handler, in data order.
static func ids() -> Array[String]:
	_ensure_loaded()
	return _order.duplicate()


static func handler(event_id: String) -> NoncombatEvent:
	_ensure_loaded()
	return _handlers.get(event_id)


static func display_name(event_id: String) -> String:
	var event: NoncombatEvent = handler(event_id)
	return event.display_name() if event != null else event_id


# One handler class per event id.
static func _handler_scripts() -> Dictionary:
	return {
		"pilgrimage": PilgrimageEvent,
		"vow": VowEvent,
		"memory": MemoryEvent,
		"riddle": RiddleEvent,
		"copyist": CopyistEvent,
	}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("EventCatalog: cannot open event data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("EventCatalog: event data is not valid JSON")
		return
	var scripts: Dictionary = _handler_scripts()
	for event_id: String in parsed:
		var entry: Variant = parsed[event_id]
		if typeof(entry) != TYPE_DICTIONARY \
				or typeof(entry.get("name")) != TYPE_STRING:
			push_error("EventCatalog: %s skipped: needs a name" % event_id)
			continue
		if not scripts.has(event_id):
			push_error("EventCatalog: %s has no handler" % event_id)
			continue
		var event: NoncombatEvent = scripts[event_id].new()
		event.definition = entry
		event.event_id = event_id
		_handlers[event_id] = event
		_order.append(event_id)
