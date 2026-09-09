class_name CounterScorer
extends RefCounted
## Scores curated thematic counters and direct WordNet antonyms.

const DATA_PATH: String = "res://data/tag_counters.json"

var _reader: WordNetReader = null
var _counters: Dictionary = {}


func _init(reader: WordNetReader) -> void:
	_reader = reader
	_load_counters()


func score_detailed(
	word: String, tag: String, required_pos: String = ""
) -> Dictionary:
	var result: Dictionary = {
		"score": 0.0,
		"strategy": "none",
		"detail": "no counter",
		"target": "",
	}
	var positions: Array[String] = []
	if required_pos.is_empty():
		positions = _reader.parts_of_speech(word)
	else:
		positions.append(required_pos)
	for pos: String in positions:
		var targets: Array = _counters.get(tag, {}).get(pos, [])
		for target: String in targets:
			if _is_antonym(word, target, pos):
				result["score"] = 1.0
				result["strategy"] = "wordnet antonym"
				result["detail"] = "%s opposes %s" % [word, tag]
				result["target"] = target
				return result
			if _same_word(word, target, pos):
				result["score"] = 1.0
				result["strategy"] = "thematic counter"
				result["detail"] = "%s counters %s" % [word, tag]
				result["target"] = target
				return result
			if _shares_synset(word, target, pos):
				result["score"] = 0.9
				result["strategy"] = "counter synonym"
				result["detail"] = "%s echoes %s" % [word, target]
				result["target"] = target
				return result
	return result


func _is_antonym(word: String, target: String, pos: String) -> bool:
	var target_synsets: Array[WordNetReader.Synset] = \
			_reader.get_synsets(target, pos)
	for synset: WordNetReader.Synset in _reader.get_synsets(word, pos):
		for pointer: Dictionary in synset.pointers:
			if pointer.get("symbol", "") != "!":
				continue
			for target_synset: WordNetReader.Synset in target_synsets:
				if pointer.get("offset", -1) == target_synset.offset:
					return true
	return false

func _same_word(word: String, target: String, pos: String) -> bool:
	var word_lemmas: Array[String] = _reader.lemmas_of(word, pos)
	var target_lemmas: Array[String] = _reader.lemmas_of(target, pos)
	for left: String in word_lemmas:
		if target_lemmas.has(left):
			return true
	return false


func _shares_synset(word: String, target: String, pos: String) -> bool:
	var target_synsets: Array[WordNetReader.Synset] = \
			_reader.get_synsets(target, pos)
	var word_synsets: Array[WordNetReader.Synset] = \
			_reader.get_synsets(word, pos)
	for target_synset: WordNetReader.Synset in target_synsets:
		for word_synset: WordNetReader.Synset in word_synsets:
			if target_synset.offset == word_synset.offset:
				return true
	return false


func _load_counters() -> void:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_counters = parsed
