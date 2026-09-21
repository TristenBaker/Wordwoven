class_name ModifierCatalog
extends RefCounted
## Loads letter modifier definitions once and validates them. Names,
## descriptions, amounts, resolution order, and prices stay
## authoritative in data; ModifierResolver applies the effect types.

const DATA_PATH: String = "res://data/modifiers.json"

## Effect types ModifierResolver knows how to apply.
const EFFECT_TYPES: Array[String] = [
	"flat_power", "power_per_class_ally", "power_per_wait",
	"power_when_threaded", "power_percent", "echo_class", "gold",
	"counter_bonus", "inspiration",
]

static var _definitions: Dictionary = {}
static var _loaded: bool = false


static func definitions() -> Dictionary:
	if not _loaded:
		reload()
	return _definitions


static func has_modifier(modifier_id: String) -> bool:
	return definitions().has(modifier_id)


static func definition(modifier_id: String) -> Dictionary:
	return definitions().get(modifier_id, {})


## Ids that rewards, stickers, events, and recruits may hand out.
static func offered_ids() -> Array[String]:
	var ids: Array[String] = []
	for modifier_id: String in definitions():
		if bool(definition(modifier_id).get("offered", true)):
			ids.append(modifier_id)
	return ids


static func display_name(modifier_id: String) -> String:
	return String(definition(modifier_id).get("name", modifier_id))


## Resolution order; lower values resolve first.
static func order_of(modifier_id: String) -> int:
	return int(definition(modifier_id).get("order", 100))


static func price_of(modifier_id: String) -> int:
	return int(definition(modifier_id).get("price", 0))


## Exact effect text with amounts filled in; an Inspired cast shows
## doubled amounts for effects that double.
static func describe(
	modifier_id: String, letter_class_text: String = "letter"
) -> String:
	var info: Dictionary = definition(modifier_id)
	var amount: float = float(info.get("amount", 0))
	var text: String = String(info.get("description", ""))
	return text.format({
		"amount": _number_text(amount),
		"percent": _number_text(amount * 100.0),
		"cap": str(int(info.get("cap", 0))),
		"class": letter_class_text.to_lower(),
	})


## Modifier ids sorted into resolution order; ties keep slot order.
static func sorted_by_order(ids: Array[String]) -> Array[String]:
	var indexed: Array[Array] = []
	for index: int in ids.size():
		indexed.append([order_of(ids[index]), index, ids[index]])
	indexed.sort_custom(func(left: Array, right: Array) -> bool:
		if left[0] != right[0]:
			return left[0] < right[0]
		return left[1] < right[1]
	)
	var sorted: Array[String] = []
	for entry: Array in indexed:
		sorted.append(String(entry[2]))
	return sorted


## Rereads the data file, keeping only valid entries.
static func reload() -> void:
	_loaded = true
	_definitions = {}
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("ModifierCatalog: cannot open modifier data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ModifierCatalog: modifier data is not valid JSON")
		return
	var data: Dictionary = parsed
	for modifier_id: String in data:
		var problems: Array[String] = validate_entry(data[modifier_id])
		if problems.is_empty():
			_definitions[modifier_id] = data[modifier_id]
		else:
			push_error("ModifierCatalog: %s skipped: %s" % [
				modifier_id, "; ".join(problems),
			])


## Problems with one modifier definition; empty when valid.
static func validate_entry(entry: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(entry) != TYPE_DICTIONARY:
		problems.append("entry must be an object")
		return problems
	var info: Dictionary = entry
	for field: String in ["name", "description", "effect"]:
		if typeof(info.get(field)) != TYPE_STRING:
			problems.append("%s must be text" % field)
	if not EFFECT_TYPES.has(String(info.get("effect", ""))):
		problems.append("unknown effect %s" % info.get("effect", ""))
	var amount_type: int = typeof(info.get("amount"))
	if amount_type != TYPE_FLOAT and amount_type != TYPE_INT:
		problems.append("amount must be a number")
	return problems


static func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value
