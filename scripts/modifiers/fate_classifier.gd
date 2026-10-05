extends RefCounted
## Representative concept anchors, not an exhaustive adjective lookup table.
## WordNet expands each concept through shared synonyms and inflected lemmas.
const CONCEPTS: Dictionary = {
	"titanbound": ["strong", "tough", "durable", "massive"],
	"doommarked": ["weak", "frail", "brittle", "sickly"],
	"war_blessed": ["angry", "violent", "ferocious", "hostile", "cruel"],
	"spirit_broken": ["timid", "fearful", "cowardly", "meek"],
	"fate_exposed": ["vulnerable", "exposed", "defenseless", "unprotected"],
	"spellwarden": ["protected", "guarded", "armored", "warded"],
}
const MIN_CONFIDENCE: float = 0.8
const MIN_MARGIN: float = 0.1
const MODIFIERS = preload("res://scripts/modifiers/encounter_modifier.gd")
static var _relations_cache: Dictionary = {}

static func classify(adjective: String) -> Dictionary:
	var word: String = adjective.strip_edges().to_lower()
	var scores: Dictionary = {}
	var best_id: String = ""
	var best: float = 0.0
	var runner_up: float = 0.0
	if not WordNet.is_ready or not WordNet.parts_of_speech(word).has("a"):
		return {"modifier_id": "", "score": 0.0, "margin": 0.0}
	var relations: Dictionary = _relations(word)
	for id: String in CONCEPTS:
		var score: float = 0.0
		for anchor: String in CONCEPTS[id]:
			if word == anchor:
				score = 1.0
				break
			var target: Dictionary = _relations(anchor)
			if _overlap(relations.synsets, target.synsets):
				score = maxf(score, 0.95)
			elif _overlap(relations.similar, target.synsets) or _overlap(relations.synsets, target.similar):
				score = maxf(score, 0.85)
		scores[id] = score
		if score > best:
			runner_up = best
			best = score
			best_id = id
		else:
			runner_up = maxf(runner_up, score)
	var margin: float = best - runner_up
	if best < MIN_CONFIDENCE or margin + 0.000001 < MIN_MARGIN:
		best_id = ""
	return {"modifier_id": best_id, "score": best, "margin": margin, "scores": scores}

static func select_modifier(adjective: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var classification: Dictionary = classify(adjective)
	if not String(classification.modifier_id).is_empty():
		return MODIFIERS.definition(classification.modifier_id)
	# Roll only here; the caller keeps the existing encounter outcome cache.
	if rng != null:
		return MODIFIERS.ENTRIES[rng.randi_range(0, MODIFIERS.ENTRIES.size() - 1)].duplicate(true)
	return MODIFIERS.ENTRIES.pick_random().duplicate(true)

static func _relations(word: String) -> Dictionary:
	if not _relations_cache.has(word):
		_relations_cache[word] = WordNet.adjective_relations(word)
	return _relations_cache[word]

static func _overlap(left: Array, right: Array) -> bool:
	for offset: int in left:
		if right.has(offset):
			return true
	return false
