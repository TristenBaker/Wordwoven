class_name PunctuationCatalog
extends RefCounted
## Carried punctuation consumables, defined in data. Marks are never
## part of the word: they are stripped before dictionary validation
## and consumed only when the cast is accepted.

const DATA_PATH: String = "res://data/punctuation.json"
const EXCLAMATION: String = "!"

static var _definitions: Dictionary = {}
static var _loaded: bool = false


static func definitions() -> Dictionary:
	if not _loaded:
		_load()
	return _definitions


static func has_mark(mark: String) -> bool:
	return definitions().has(mark)


static func display_name(mark: String) -> String:
	return String(definitions().get(mark, {}).get("name", mark))


static func describe(mark: String) -> String:
	return String(definitions().get(mark, {}).get("description", ""))


## Final damage multiplier while the mark is armed.
static func damage_multiplier(mark: String) -> float:
	return float(definitions().get(mark, {}).get(
		"damage_multiplier", 1.0
	))


## Splits typed text into the word and any trailing known marks.
## Returns {"word": String, "marks": Array[String]}.
static func split_marks(text: String) -> Dictionary:
	var word: String = text.strip_edges().to_lower()
	var marks: Array[String] = []
	while not word.is_empty() and has_mark(word.right(1)):
		var mark: String = word.right(1)
		if not marks.has(mark):
			marks.append(mark)
		word = word.left(word.length() - 1).strip_edges()
	return {"word": word, "marks": marks}


static func _load() -> void:
	_loaded = true
	_definitions = {}
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("PunctuationCatalog: cannot open punctuation data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("PunctuationCatalog: data is not valid JSON")
		return
	_definitions = parsed
