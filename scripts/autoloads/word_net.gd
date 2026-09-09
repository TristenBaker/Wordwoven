extends Node
## Single game-facing interface to WordNet. Every other system asks
## this autoload for word validation, parts of speech, synonyms, and
## semantic similarity; nothing else touches the database files.
## The database loads on a background thread at startup.

signal loading_finished(success: bool)

const DICT_PATH: String = "res://assets/wordnet/dict"

var is_ready: bool = false

var _reader: WordNetReader = null
var _scorer: SemanticScorer = null
var _counter_scorer: CounterScorer = null
var _thread: Thread = null


func _ready() -> void:
	_thread = Thread.new()
	_thread.start(_load_database)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


## True when the word is a real dictionary word (any inflection).
func word_exists(word: String) -> bool:
	if not _check_ready():
		return false
	return _reader.word_exists(word)


## POS identifiers ("n", "v", "a", "r") the word can be used as.
func parts_of_speech(word: String) -> Array[String]:
	if not _check_ready():
		return []
	return _reader.parts_of_speech(word)


## True for an uninflected dictionary headword in the given POS.
func is_base_form(word: String, pos: String) -> bool:
	if not _check_ready():
		return false
	return _reader.is_base_form(word, pos)


## Human-readable name for a POS identifier.
func pos_name(pos: String) -> String:
	return WordNetReader.POS_NAMES.get(pos, "unknown")


## Semantic similarity between two words, 0..1.
func similarity(word_a: String, word_b: String) -> float:
	if not _check_ready():
		return 0.0
	return _scorer.similarity(word_a, word_b)


## Similarity plus strategy/detail strings for the debug overlay:
## {"score": float, "strategy": String, "detail": String}
func similarity_detailed(
	word_a: String, word_b: String
) -> Dictionary:
	if not _check_ready():
		return {"score": 0.0, "strategy": "none", "detail": ""}
	return _scorer.score_detailed(word_a, word_b)


## Rates a word as an opposite or thematic counter to an enemy tag.
func counter_detailed(
	word: String, tag: String, required_pos: String = ""
) -> Dictionary:
	if not _check_ready():
		return {"score": 0.0, "strategy": "none", "detail": ""}
	return _counter_scorer.score_detailed(word, tag, required_pos)


## Synonyms of the word across its senses, for the storyteller.
func synonyms_of(word: String, limit: int = 8) -> Array[String]:
	var synonyms: Array[String] = []
	if not _check_ready():
		return synonyms
	for pos: String in WordNetReader.POS_LIST:
		var senses: Array[WordNetReader.Synset] = \
				_reader.get_synsets(word, pos)
		for synset: WordNetReader.Synset in senses:
			for candidate: String in synset.words:
				var lowered: String = candidate.to_lower()
				if lowered == word.to_lower():
					continue
				if synonyms.has(lowered):
					continue
				synonyms.append(lowered)
				if synonyms.size() >= limit:
					return synonyms
	return synonyms


## Dictionary definition of the word's first matching sense.
func gloss_of(word: String) -> String:
	if not _check_ready():
		return ""
	for pos: String in WordNetReader.POS_LIST:
		var senses: Array[WordNetReader.Synset] = \
				_reader.get_synsets(word, pos)
		if not senses.is_empty():
			return senses[0].gloss
	return ""


func _load_database() -> void:
	var reader: WordNetReader = WordNetReader.new()
	var success: bool = reader.load_from_dict(DICT_PATH)
	_finish_loading.call_deferred(reader, success)


func _finish_loading(
	reader: WordNetReader, success: bool
) -> void:
	if success:
		_reader = reader
		_scorer = SemanticScorer.new(reader)
		_counter_scorer = CounterScorer.new(reader)
		is_ready = true
	else:
		push_error("WordNet: database failed to load")
	loading_finished.emit(success)


func _check_ready() -> bool:
	if not is_ready:
		push_warning("WordNet: queried before loading finished")
	return is_ready
