class_name WordNetReader
extends RefCounted
## Parses the Princeton WordNet 3.x database files directly.
## Builds lemma -> synset-offset indexes for each part of speech and
## reads individual synsets from the data files on demand by seeking
## to their byte offsets. A binary cache in user:// makes startups
## after the first one fast.

# Bump when the cache layout changes so stale caches are discarded.
const CACHE_FORMAT_VERSION: int = 1
const CACHE_FILE_PATH: String = "user://wordnet_index_cache.bin"

# Part-of-speech identifiers used throughout: "n", "v", "a", "r".
const POS_LIST: Array[String] = ["n", "v", "a", "r"]

const POS_NAMES: Dictionary[String, String] = {
	"n": "noun",
	"v": "verb",
	"a": "adjective",
	"r": "adverb",
}

# Maps each POS to its index/data/exception file name suffix.
const POS_FILE_SUFFIXES: Dictionary[String, String] = {
	"n": "noun",
	"v": "verb",
	"a": "adj",
	"r": "adv",
}


## One WordNet synset: a set of synonymous words plus its gloss and
## its semantic pointers to other synsets.
class Synset:
	var offset: int = 0
	var ss_type: String = ""
	var words: PackedStringArray = PackedStringArray()
	var gloss: String = ""
	# Lexical source/target indices are one-based; zero means the
	# relation applies to the entire synset.
	var pointers: Array[Dictionary] = []


var is_loaded: bool = false

var _dict_path: String = ""

# Per-POS lemma -> PackedInt32Array of synset byte offsets.
# Left untyped-value on purpose: round-trips through the binary cache.
var _indexes: Dictionary = {}

# Per-POS irregular form -> base form (from the *.exc files).
var _exceptions: Dictionary = {}

# Parsed synsets keyed by "pos:offset".
var _synset_cache: Dictionary = {}

# Open FileAccess handles for the data.* files, keyed by POS.
var _data_files: Dictionary = {}


## Loads the database from the given dict folder, preferring the
## binary cache when it is present and current.
func load_from_dict(dict_path: String) -> bool:
	_dict_path = dict_path
	if _load_cache():
		is_loaded = true
		return true
	if not _parse_all_indexes():
		return false
	_save_cache()
	is_loaded = true
	return true


## True when the word (or one of its lemmas) appears in any index.
func word_exists(word: String) -> bool:
	return not parts_of_speech(word).is_empty()


## Returns every POS identifier the word can be used as.
func parts_of_speech(word: String) -> Array[String]:
	var found: Array[String] = []
	var normalized: String = word.strip_edges().to_lower()
	if normalized.is_empty():
		return found
	for pos: String in POS_LIST:
		for lemma: String in lemmas_of(normalized, pos):
			var index: Dictionary = _indexes.get(pos, {})
			if index.has(lemma):
				found.append(pos)
				break
	return found


## True only for a dictionary headword, without inflection rules.
func is_base_form(word: String, pos: String) -> bool:
	var normalized: String = word.strip_edges().to_lower()
	var index: Dictionary = _indexes.get(pos, {})
	return index.has(normalized.replace(" ", "_"))


## Returns candidate base forms for a word under the given POS.
## Combines the irregular-form exception lists with the standard
## WordNet detachment rules for regular inflections.
func lemmas_of(word: String, pos: String) -> Array[String]:
	var lemmas: Array[String] = [word]
	var exceptions: Dictionary = _exceptions.get(pos, {})
	if exceptions.has(word):
		lemmas.append(exceptions[word])
	match pos:
		"v":
			_append_verb_lemmas(word, lemmas)
		"n":
			_append_noun_lemmas(word, lemmas)
		"a":
			_append_adjective_lemmas(word, lemmas)
	var unique: Array[String] = []
	for lemma: String in lemmas:
		if not unique.has(lemma):
			unique.append(lemma)
	return unique


## Returns every synset for a word under the given POS, trying each
## candidate lemma until one has entries in the index.
func get_synsets(word: String, pos: String) -> Array[Synset]:
	var results: Array[Synset] = []
	var normalized: String = word.strip_edges().to_lower()
	if normalized.is_empty():
		return results
	var index: Dictionary = _indexes.get(pos, {})
	for lemma: String in lemmas_of(normalized, pos):
		var underscored: String = lemma.replace(" ", "_")
		if not index.has(underscored):
			continue
		var offsets: PackedInt32Array = index[underscored]
		for offset: int in offsets:
			var synset: Synset = get_synset(pos, offset)
			if synset != null:
				results.append(synset)
		if not results.is_empty():
			return results
	return results


## Reads and parses one synset from its data file, with caching.
func get_synset(pos: String, offset: int) -> Synset:
	var cache_key: String = "%s:%d" % [pos, offset]
	if _synset_cache.has(cache_key):
		return _synset_cache[cache_key]
	var file: FileAccess = _data_file_for(pos)
	if file == null:
		return null
	file.seek(offset)
	var line: String = file.get_line()
	var synset: Synset = _parse_data_line(line)
	if synset == null:
		return null
	_synset_cache[cache_key] = synset
	return synset


# --- Index parsing -------------------------------------------------

func _parse_all_indexes() -> bool:
	for pos: String in POS_LIST:
		var suffix: String = POS_FILE_SUFFIXES[pos]
		var index_path: String = _dict_path.path_join(
			"index." + suffix
		)
		var index: Dictionary = _parse_index_file(index_path)
		if index.is_empty():
			push_error(
				"WordNetReader: failed to parse " + index_path
			)
			return false
		_indexes[pos] = index
		var exc_path: String = _dict_path.path_join(
			suffix + ".exc"
		)
		_exceptions[pos] = _parse_exception_file(exc_path)
	return true


# Index line format:
# lemma pos synset_cnt p_cnt [ptr_symbol...] sense_cnt tagsense_cnt
# synset_offset [synset_offset...]
func _parse_index_file(path: String) -> Dictionary:
	var index: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return index
	var text: String = file.get_as_text()
	file.close()
	for line: String in text.split("\n", false):
		if line.begins_with(" "):
			continue
		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() < 8:
			continue
		var lemma: String = parts[0]
		var synset_count: int = parts[2].to_int()
		var pointer_count: int = parts[3].to_int()
		var offsets_start: int = 4 + pointer_count + 2
		if synset_count <= 0:
			continue
		if offsets_start + synset_count > parts.size():
			continue
		var offsets: PackedInt32Array = PackedInt32Array()
		for i: int in synset_count:
			offsets.append(parts[offsets_start + i].to_int())
		index[lemma] = offsets
	return index


# Exception line format: "irregular_form base_form [base_form...]"
func _parse_exception_file(path: String) -> Dictionary:
	var exceptions: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return exceptions
	var text: String = file.get_as_text()
	file.close()
	for line: String in text.split("\n", false):
		var parts: PackedStringArray = line.split(" ", false)
		if parts.size() >= 2:
			exceptions[parts[0]] = parts[1]
	return exceptions


# --- Synset parsing ------------------------------------------------

func _data_file_for(pos: String) -> FileAccess:
	if _data_files.has(pos):
		return _data_files[pos]
	var suffix: String = POS_FILE_SUFFIXES[pos]
	var path: String = _dict_path.path_join("data." + suffix)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WordNetReader: cannot open " + path)
		return null
	_data_files[pos] = file
	return file


# Data line format:
# offset lex_filenum ss_type w_cnt word lex_id [word lex_id...]
# p_cnt [ptr...] [frames...] | gloss
# w_cnt is hexadecimal; each pointer is 4 tokens.
func _parse_data_line(line: String) -> Synset:
	var gloss: String = ""
	var left: String = line
	var bar_index: int = line.find("|")
	if bar_index >= 0:
		left = line.substr(0, bar_index).strip_edges(false, true)
		gloss = line.substr(bar_index + 1).strip_edges()
	var parts: PackedStringArray = left.split(" ", false)
	if parts.size() < 5:
		return null
	var synset: Synset = Synset.new()
	synset.offset = parts[0].to_int()
	synset.ss_type = parts[2]
	synset.gloss = gloss
	var word_count: int = parts[3].hex_to_int()
	if word_count <= 0:
		return null
	var cursor: int = 4
	for i: int in word_count:
		if cursor + 1 >= parts.size():
			return null
		synset.words.append(parts[cursor].replace("_", " "))
		cursor += 2
	if cursor >= parts.size():
		return null
	var pointer_count: int = parts[cursor].to_int()
	cursor += 1
	for i: int in pointer_count:
		if cursor + 3 >= parts.size():
			break
		synset.pointers.append({
			"symbol": parts[cursor],
			"offset": parts[cursor + 1].to_int(),
			"pos": parts[cursor + 2],
			"source": parts[cursor + 3].substr(0, 2).hex_to_int(),
			"target": parts[cursor + 3].substr(2, 2).hex_to_int(),
		})
		cursor += 4
	return synset


# --- Lemmatization rules -------------------------------------------

func _append_verb_lemmas(
	word: String, lemmas: Array[String]
) -> void:
	if word.ends_with("ing"):
		var stem: String = word.substr(0, word.length() - 3)
		lemmas.append(stem)
		lemmas.append(stem + "e")
		# Doubled final consonant, e.g. running -> run.
		if stem.length() >= 2 \
				and stem[stem.length() - 1] == stem[stem.length() - 2]:
			lemmas.append(stem.substr(0, stem.length() - 1))
	elif word.ends_with("ied"):
		lemmas.append(word.substr(0, word.length() - 3) + "y")
	elif word.ends_with("ed"):
		lemmas.append(word.substr(0, word.length() - 2))
		lemmas.append(word.substr(0, word.length() - 1))
	elif word.ends_with("es"):
		lemmas.append(word.substr(0, word.length() - 2))
		lemmas.append(word.substr(0, word.length() - 1))
	elif word.ends_with("s") and not word.ends_with("ss"):
		lemmas.append(word.substr(0, word.length() - 1))


func _append_noun_lemmas(
	word: String, lemmas: Array[String]
) -> void:
	if word.ends_with("ies"):
		lemmas.append(word.substr(0, word.length() - 3) + "y")
	elif word.ends_with("es"):
		lemmas.append(word.substr(0, word.length() - 2))
		lemmas.append(word.substr(0, word.length() - 1))
	elif word.ends_with("s") and not word.ends_with("ss"):
		lemmas.append(word.substr(0, word.length() - 1))


func _append_adjective_lemmas(
	word: String, lemmas: Array[String]
) -> void:
	if word.ends_with("est"):
		lemmas.append(word.substr(0, word.length() - 3))
		lemmas.append(word.substr(0, word.length() - 2))
	elif word.ends_with("er"):
		lemmas.append(word.substr(0, word.length() - 2))
		lemmas.append(word.substr(0, word.length() - 1))


# --- Binary cache --------------------------------------------------

func _load_cache() -> bool:
	if not FileAccess.file_exists(CACHE_FILE_PATH):
		return false
	var file: FileAccess = FileAccess.open(
		CACHE_FILE_PATH, FileAccess.READ
	)
	if file == null:
		return false
	var raw: PackedByteArray = file.get_buffer(
		file.get_length()
	)
	file.close()
	var data: Variant = bytes_to_var(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var cache: Dictionary = data
	if cache.get("version", -1) != CACHE_FORMAT_VERSION:
		return false
	_indexes = cache.get("indexes", {})
	_exceptions = cache.get("exceptions", {})
	return not _indexes.is_empty()


func _save_cache() -> void:
	var cache: Dictionary = {
		"version": CACHE_FORMAT_VERSION,
		"indexes": _indexes,
		"exceptions": _exceptions,
	}
	var file: FileAccess = FileAccess.open(
		CACHE_FILE_PATH, FileAccess.WRITE
	)
	if file == null:
		push_error("WordNetReader: cannot write index cache")
		return
	file.store_buffer(var_to_bytes(cache))
	file.close()
