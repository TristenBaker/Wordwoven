class_name SemanticScorer
extends RefCounted
## Scores the semantic similarity of two words on a 0..1 scale using
## WordNet. Tries several strategies and reports the best one:
## exact/lemma match, shared synset, Wu-Palmer similarity over the
## noun and verb hypernym graphs (crossing part of speech through
## derivation and pertainym pointers), and finally overlap between
## synonym-and-gloss word bags.

# How many senses of a word to consider per part of speech.
const SENSE_LIMIT: int = 3

# Scores for the non-graph strategies.
const SCORE_EXACT_MATCH: float = 1.0
const SCORE_SHARED_SYNSET: float = 0.95
const SCORE_BAG_CEILING: float = 0.6

# Pointer symbols that climb the hypernym graph.
const HYPERNYM_SYMBOLS: Array[String] = ["@", "@i"]

# Pointer symbols that cross part of speech toward nouns.
const CROSS_POS_SYMBOLS: Array[String] = ["+", "\\"]

# Pointer symbol linking similar adjective clusters.
const SIMILAR_SYMBOL: String = "&"

# Association scoring: each word also meets the other's gloss
# nouns in the graph (e.g. "hungry" glosses mention "food", and a
# "feast" IS food), at a discount, because taxonomic Wu-Palmer
# alone misses associative links players intuitively expect.
const EXPANSION_DISCOUNT: float = 0.75
const GLOSS_EXPANSION_LIMIT: int = 4

# An association only counts when the word sits taxonomically
# close to the gloss noun; anything looser is coincidence.
const ASSOCIATION_MIN_WUP: float = 0.75

# Common gloss words that carry no associative meaning.
const GLOSS_STOPWORDS: Array[String] = [
	"having", "with", "without", "that", "this", "than",
	"used", "usually", "especially", "being", "something",
	"someone", "person", "persons", "quality", "state",
	"manner", "characterized", "relating", "marked", "very",
	"great", "large", "small", "certain", "kind", "some",
	"from", "into", "which", "when", "where", "what", "more",
	"most", "other", "others", "their", "them", "they",
	"feeling", "need", "member", "genus", "times", "type",
	"form", "part", "parts", "piece", "group", "make",
	"makes", "making", "made", "cause", "causes", "causing",
]

# Safety cap on hypernym-chain walks.
const MAX_CHAIN_DEPTH: int = 30

var _reader: WordNetReader = null

# Memoized minimum depth to the hierarchy root, keyed "pos:offset".
var _depth_cache: Dictionary = {}


func _init(reader: WordNetReader) -> void:
	_reader = reader


## Returns the best similarity score between two words, 0..1.
func similarity(word_a: String, word_b: String) -> float:
	return score_detailed(word_a, word_b).get("score", 0.0)


## Returns {"score": float, "strategy": String, "detail": String}
## so the debug overlay can show how the score was reached.
func score_detailed(word_a: String, word_b: String) -> Dictionary:
	var a: String = word_a.strip_edges().to_lower()
	var b: String = word_b.strip_edges().to_lower()
	if a.is_empty() or b.is_empty():
		return _result(0.0, "empty", "missing word")
	if a == b or _share_lemma(a, b):
		return _result(
			SCORE_EXACT_MATCH, "exact", "same word or lemma"
		)
	var synsets_a: Dictionary = _collect_synsets(a)
	var synsets_b: Dictionary = _collect_synsets(b)
	if _share_synset(synsets_a, synsets_b):
		return _result(
			SCORE_SHARED_SYNSET, "synonym", "shared synset"
		)
	var best: Dictionary = _result(0.0, "none", "no relation found")
	var wup: Dictionary = _best_wu_palmer(synsets_a, synsets_b)
	if wup.get("score", 0.0) > best.get("score", 0.0):
		best = wup
	var association: Dictionary = _best_association(
		synsets_a, synsets_b
	)
	if association.get("score", 0.0) > best.get("score", 0.0):
		best = association
	var bag: Dictionary = _bag_overlap(a, b, synsets_a, synsets_b)
	if bag.get("score", 0.0) > best.get("score", 0.0):
		best = bag
	return best


# --- Synset collection ---------------------------------------------

# Gathers graph-scorable synsets for a word:
# "n" and "v" lists of Synset, including noun synsets reached by one
# derivation/pertainym hop from the word's adjective or verb senses.
func _collect_synsets(word: String) -> Dictionary:
	var nouns: Array[WordNetReader.Synset] = []
	var verbs: Array[WordNetReader.Synset] = []
	var direct: Dictionary = {}
	for pos: String in WordNetReader.POS_LIST:
		var senses: Array[WordNetReader.Synset] = \
				_reader.get_synsets(word, pos)
		if senses.size() > SENSE_LIMIT:
			senses = senses.slice(0, SENSE_LIMIT)
		direct[pos] = senses
	nouns.append_array(direct["n"])
	verbs.append_array(direct["v"])
	# Cross toward nouns from adjective and adverb senses so that
	# tags like "fiery" can meet nouns like "flame" in the graph.
	for pos: String in ["a", "r", "v"]:
		for synset: WordNetReader.Synset in direct[pos]:
			for pointer: Dictionary in synset.pointers:
				if not CROSS_POS_SYMBOLS.has(pointer["symbol"]):
					continue
				if pointer["pos"] != "n":
					continue
				var hopped: WordNetReader.Synset = \
						_reader.get_synset("n", pointer["offset"])
				if hopped != null:
					nouns.append(hopped)
	return {"n": nouns, "v": verbs, "direct": direct}


func _share_lemma(a: String, b: String) -> bool:
	for pos: String in WordNetReader.POS_LIST:
		var lemmas_a: Array[String] = _reader.lemmas_of(a, pos)
		var lemmas_b: Array[String] = _reader.lemmas_of(b, pos)
		for lemma: String in lemmas_a:
			if lemma != a and lemmas_b.has(lemma):
				return true
	return false


func _share_synset(
	synsets_a: Dictionary, synsets_b: Dictionary
) -> bool:
	var direct_a: Dictionary = synsets_a["direct"]
	var direct_b: Dictionary = synsets_b["direct"]
	for pos: String in WordNetReader.POS_LIST:
		var offsets: Dictionary = {}
		for synset: WordNetReader.Synset in direct_a[pos]:
			offsets[synset.offset] = true
		for synset: WordNetReader.Synset in direct_b[pos]:
			if offsets.has(synset.offset):
				return true
	return false


# --- Wu-Palmer over the hypernym graph -----------------------------

func _best_wu_palmer(
	synsets_a: Dictionary, synsets_b: Dictionary
) -> Dictionary:
	var best_score: float = 0.0
	var best_detail: String = ""
	for pos: String in ["n", "v"]:
		var list_a: Array[WordNetReader.Synset] = synsets_a[pos]
		var list_b: Array[WordNetReader.Synset] = synsets_b[pos]
		for sa: WordNetReader.Synset in list_a:
			for sb: WordNetReader.Synset in list_b:
				var score: float = _wu_palmer(pos, sa, sb)
				if score > best_score:
					best_score = score
					best_detail = "%s ~ %s" % [
						sa.words[0], sb.words[0]
					]
	return _result(best_score, "wu-palmer", best_detail)


# Wu-Palmer: 2 * depth(lcs) / (depth(a) + depth(b)), where depths
# are measured through the deepest common ancestor.
func _wu_palmer(
	pos: String,
	synset_a: WordNetReader.Synset,
	synset_b: WordNetReader.Synset
) -> float:
	if synset_a.offset == synset_b.offset:
		return 1.0
	var ancestors_a: Dictionary = _ancestors_of(pos, synset_a)
	var ancestors_b: Dictionary = _ancestors_of(pos, synset_b)
	var best: float = 0.0
	for offset: int in ancestors_a:
		if not ancestors_b.has(offset):
			continue
		var lcs_depth: int = _depth_of(pos, offset)
		var dist_a: int = ancestors_a[offset]
		var dist_b: int = ancestors_b[offset]
		var denominator: float = float(
			2 * lcs_depth + dist_a + dist_b
		)
		if denominator <= 0.0:
			continue
		var score: float = 2.0 * float(lcs_depth) / denominator
		if score > best:
			best = score
	return best


# Breadth-first walk up the hypernym pointers.
# Returns {ancestor_offset: distance}, including self at 0.
func _ancestors_of(
	pos: String, synset: WordNetReader.Synset
) -> Dictionary:
	var distances: Dictionary = {synset.offset: 0}
	var frontier: Array[int] = [synset.offset]
	var depth: int = 0
	while not frontier.is_empty() and depth < MAX_CHAIN_DEPTH:
		depth += 1
		var next_frontier: Array[int] = []
		for offset: int in frontier:
			var current: WordNetReader.Synset = \
					_reader.get_synset(pos, offset)
			if current == null:
				continue
			for pointer: Dictionary in current.pointers:
				if not HYPERNYM_SYMBOLS.has(pointer["symbol"]):
					continue
				var parent: int = pointer["offset"]
				if distances.has(parent):
					continue
				distances[parent] = depth
				next_frontier.append(parent)
		frontier = next_frontier
	return distances


# Minimum distance from the synset to a hierarchy root, memoized.
# A root (no hypernyms) has depth 1.
func _depth_of(pos: String, offset: int) -> int:
	var cache_key: String = "%s:%d" % [pos, offset]
	if _depth_cache.has(cache_key):
		return _depth_cache[cache_key]
	var synset: WordNetReader.Synset = _reader.get_synset(
		pos, offset
	)
	if synset == null:
		return 1
	var ancestors: Dictionary = _ancestors_of(pos, synset)
	var max_distance: int = 0
	for ancestor_offset: int in ancestors:
		var parent: WordNetReader.Synset = _reader.get_synset(
			pos, ancestor_offset
		)
		if parent == null:
			continue
		if _has_hypernym(parent):
			continue
		var distance: int = ancestors[ancestor_offset]
		if distance > max_distance:
			max_distance = distance
	# Depth counts nodes, so the root itself contributes 1.
	var depth: int = max_distance + 1
	_depth_cache[cache_key] = depth
	return depth


func _has_hypernym(synset: WordNetReader.Synset) -> bool:
	for pointer: Dictionary in synset.pointers:
		if HYPERNYM_SYMBOLS.has(pointer["symbol"]):
			return true
	return false


# --- Association through gloss nouns -------------------------------

# Meets each word's noun senses against the nouns mentioned in the
# other word's glosses, discounted. Catches associative pairs like
# feast~hungry (via "food") that share no taxonomy branch.
func _best_association(
	synsets_a: Dictionary, synsets_b: Dictionary
) -> Dictionary:
	var best_score: float = 0.0
	var best_detail: String = ""
	var expansion_a: Array[WordNetReader.Synset] = \
			_gloss_nouns(synsets_a)
	var expansion_b: Array[WordNetReader.Synset] = \
			_gloss_nouns(synsets_b)
	var pairs: Array[Array] = [
		[synsets_a["n"], expansion_b],
		[expansion_a, synsets_b["n"]],
	]
	for pair: Array in pairs:
		var list_a: Array[WordNetReader.Synset] = pair[0]
		var list_b: Array[WordNetReader.Synset] = pair[1]
		for sa: WordNetReader.Synset in list_a:
			for sb: WordNetReader.Synset in list_b:
				var score: float = _wu_palmer("n", sa, sb)
				if score < ASSOCIATION_MIN_WUP:
					continue
				if score > best_score:
					best_score = score
					best_detail = "%s ~ %s" % [
						sa.words[0], sb.words[0]
					]
	return _result(
		best_score * EXPANSION_DISCOUNT,
		"association",
		best_detail
	)


# First noun synsets of the meaningful words inside the glosses of
# a word's primary sense per part of speech. Later senses stay out
# because their glosses drown the signal in noise.
func _gloss_nouns(
	synsets: Dictionary
) -> Array[WordNetReader.Synset]:
	var found: Array[WordNetReader.Synset] = []
	var seen: Dictionary = {}
	var direct: Dictionary = synsets["direct"]
	for pos: String in WordNetReader.POS_LIST:
		var senses: Array[WordNetReader.Synset] = direct[pos]
		for synset: WordNetReader.Synset in senses.slice(0, 1):
			for token: String in synset.gloss.split(" ", false):
				if found.size() >= GLOSS_EXPANSION_LIMIT:
					return found
				var cleaned: String = _strip_token(token)
				if cleaned.length() <= 3:
					continue
				if GLOSS_STOPWORDS.has(cleaned):
					continue
				if seen.has(cleaned):
					continue
				seen[cleaned] = true
				var noun_senses: Array[WordNetReader.Synset] = \
						_reader.get_synsets(cleaned, "n")
				if not noun_senses.is_empty():
					found.append(noun_senses[0])
	return found


# --- Bag-of-words fallback -----------------------------------------

# Overlap between the two words' synonym-and-gloss token bags,
# scaled to at most SCORE_BAG_CEILING. Catches related adjectives
# and adverbs that never meet in a hypernym graph.
func _bag_overlap(
	a: String,
	b: String,
	synsets_a: Dictionary,
	synsets_b: Dictionary
) -> Dictionary:
	var bag_a: Dictionary = _semantic_bag(a, synsets_a)
	var bag_b: Dictionary = _semantic_bag(b, synsets_b)
	if bag_a.is_empty() or bag_b.is_empty():
		return _result(0.0, "bag", "no data")
	var smaller: Dictionary = bag_a
	var larger: Dictionary = bag_b
	if bag_b.size() < bag_a.size():
		smaller = bag_b
		larger = bag_a
	var shared: int = 0
	for token: String in smaller:
		if larger.has(token):
			shared += 1
	var ratio: float = float(shared) / float(smaller.size())
	var score: float = clampf(
		ratio * 2.0, 0.0, 1.0
	) * SCORE_BAG_CEILING
	return _result(
		score, "bag", "%d shared tokens" % shared
	)


# Tokens from every direct sense: synonyms, gloss words, and the
# words of similar-adjective clusters one "&" hop away.
func _semantic_bag(word: String, synsets: Dictionary) -> Dictionary:
	var bag: Dictionary = {}
	var direct: Dictionary = synsets["direct"]
	for pos: String in WordNetReader.POS_LIST:
		for synset: WordNetReader.Synset in direct[pos]:
			_add_synset_to_bag(synset, bag)
			if pos != "a":
				continue
			for pointer: Dictionary in synset.pointers:
				if pointer["symbol"] != SIMILAR_SYMBOL:
					continue
				var similar: WordNetReader.Synset = \
						_reader.get_synset("a", pointer["offset"])
				if similar != null:
					_add_synset_to_bag(similar, bag)
	bag.erase(word)
	return bag


func _add_synset_to_bag(
	synset: WordNetReader.Synset, bag: Dictionary
) -> void:
	for synonym: String in synset.words:
		bag[synonym.to_lower()] = true
	for token: String in synset.gloss.split(" ", false):
		var cleaned: String = _strip_token(token)
		if cleaned.length() > 2:
			bag[cleaned] = true


func _strip_token(token: String) -> String:
	var cleaned: String = token.to_lower()
	var strip_chars: String = "\"';:,.()!?"
	while cleaned.length() > 0 \
			and strip_chars.contains(cleaned[0]):
		cleaned = cleaned.substr(1)
	while cleaned.length() > 0 \
			and strip_chars.contains(cleaned[cleaned.length() - 1]):
		cleaned = cleaned.substr(0, cleaned.length() - 1)
	return cleaned


func _result(
	score: float, strategy: String, detail: String
) -> Dictionary:
	return {
		"score": clampf(score, 0.0, 1.0),
		"strategy": strategy,
		"detail": detail,
	}
