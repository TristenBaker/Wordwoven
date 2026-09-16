class_name RelicCatalog
extends RefCounted
## Loads relic definitions once and validates them. Names,
## descriptions, and effect parameters stay authoritative in data.
## Entries list "effects"; a legacy single "effect" and "amount"
## pair is still accepted.

const DATA_PATH: String = "res://data/relics.json"

static var _relics: Dictionary = {}
static var _loaded: bool = false


static func relics() -> Dictionary:
	if not _loaded:
		reload()
	return _relics


## Rereads the data file, keeping only valid entries.
static func reload() -> void:
	_loaded = true
	_relics = {}
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("RelicCatalog: cannot open relic data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RelicCatalog: relic data is not valid JSON")
		return
	var data: Dictionary = parsed
	for relic_id: String in data:
		var problems: Array[String] = validate_entry(data[relic_id])
		if problems.is_empty():
			_relics[relic_id] = data[relic_id]
		else:
			push_error("RelicCatalog: %s skipped: %s" % [
				relic_id, "; ".join(problems),
			])


## Problems with one relic definition; empty when valid.
static func validate_entry(entry: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(entry) != TYPE_DICTIONARY:
		problems.append("entry must be an object")
		return problems
	var info: Dictionary = entry
	for field: String in ["name", "description"]:
		if typeof(info.get(field)) != TYPE_STRING:
			problems.append("%s must be text" % field)
	var effects: Array[Dictionary] = effects_of(info)
	if effects.is_empty():
		problems.append("no effects")
	for effect: Dictionary in effects:
		var effect_type: String = String(effect.get("type", ""))
		var handler: RelicEffect = RelicEffectRegistry.handler(
			effect_type
		)
		if handler == null:
			problems.append("unknown effect " + effect_type)
			continue
		problems.append_array(handler.validate(effect))
	return problems


## Normalized effect entries, each carrying its "type".
static func effects_of(info: Dictionary) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if info.has("effects") and typeof(info["effects"]) == TYPE_ARRAY:
		for raw: Variant in info["effects"]:
			if typeof(raw) == TYPE_DICTIONARY:
				effects.append(raw)
	elif info.has("effect"):
		effects.append({
			"type": info["effect"],
			"amount": info.get("amount", 0),
		})
	return effects
