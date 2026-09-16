class_name CounterScorer
extends RefCounted
## Scores counters to an enemy's adjective tag. Tags with curated
## thematic counters use them; any other adjective is countered by its
## WordNet antonyms. Direct WordNet antonyms always count.

const DATA_PATH: String = "res://data/tag_counters.json"

var _reader: WordNetReader = null
var _counters: Dictionary = {}

# Tag -> antonym words, built on first use for uncurated tags.
var _antonym_cache: Dictionary = {}


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
		for target: String in counter_targets(tag, pos):
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


## Words that directly counter a tag when played as the given POS.
## Curated tags list counters per POS; other adjectives use their
## WordNet antonyms for every POS.
func counter_targets(tag: String, pos: String) -> Array[String]:
	var targets: Array[String] = []
	var normalized: String = tag.strip_edges().to_lower()
	if _counters.has(normalized):
		for target: Variant in _counters[normalized].get(pos, []):
			targets.append(String(target))
		return targets
	return antonyms_of(normalized)


## WordNet antonyms of an adjective. Satellite adjectives, which have
## no antonyms of their own, borrow those of their head adjectives.
func antonyms_of(adjective: String) -> Array[String]:
	if _antonym_cache.has(adjective):
		return _antonym_cache[adjective]
	var found: Array[String] = []
	for synset: WordNetReader.Synset in _reader.get_synsets(adjective, "a"):
		var word_number: int = _word_number(synset, adjective)
		_collect_antonyms(synset, word_number, found)
		if synset.ss_type != "s":
			continue
		for pointer: Dictionary in synset.pointers:
			if pointer.get("symbol", "") != "&":
				continue
			var head: WordNetReader.Synset = _reader.get_synset(
				"a", pointer.get("offset", -1)
			)
			if head != null:
				_collect_antonyms(head, 0, found)
	_antonym_cache[adjective] = found
	return found


# Adds antonym words reached from a synset. A word number of zero
# follows every antonym pointer; otherwise only those of that word.
func _collect_antonyms(
	synset: WordNetReader.Synset, word_number: int, found: Array[String]
) -> void:
	for pointer: Dictionary in synset.pointers:
		if pointer.get("symbol", "") != "!":
			continue
		var source: int = pointer.get("source", 0)
		if word_number > 0 and source != 0 and source != word_number:
			continue
		var target: WordNetReader.Synset = _reader.get_synset(
			_synset_pos(pointer.get("pos", "a")), pointer.get("offset", -1)
		)
		if target == null:
			continue
		var index: int = pointer.get("target", 0)
		var words: PackedStringArray = target.words
		if index > 0 and index <= words.size():
			words = PackedStringArray([words[index - 1]])
		for raw: String in words:
			var clean: String = _plain_word(raw)
			if not clean.is_empty() and not found.has(clean):
				found.append(clean)


# One-based position of the word in the synset, or zero if absent.
func _word_number(synset: WordNetReader.Synset, word: String) -> int:
	for index: int in synset.words.size():
		if _plain_word(synset.words[index]) == word:
			return index + 1
	return 0


# Lowercase single word without adjective position markers such as
# "(a)"; multiword entries become empty.
func _plain_word(raw: String) -> String:
	var word: String = raw.to_lower()
	var marker: int = word.find("(")
	if marker >= 0:
		word = word.substr(0, marker)
	if word.contains(" "):
		return ""
	return word


func _synset_pos(pointer_pos: String) -> String:
	return "a" if pointer_pos == "s" else pointer_pos


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
