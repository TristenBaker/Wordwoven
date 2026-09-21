class_name WordRules
extends RefCounted
## Word constraints shared by enemies, vows, and event challenges.
## A rule is a dictionary {"type", ...parameters} whose type is
## defined in data/word_rules.json. Ordinary rules only weaken a word
## that misses them; forbidding rules (amnesia) refuse the word.
## Every combination offered to the player is first proven solvable.

const DATA_PATH: String = "res://data/word_rules.json"

# Counter synonyms score 0.9, so they satisfy a counter rule too.
const COUNTER_THRESHOLD: float = 0.9

# Damage multiplier for a word that misses an ordinary rule.
const UNMET_DAMAGE_FACTOR: float = 0.5

static var _definitions: Dictionary = {}
static var _loaded: bool = false


static func definitions() -> Dictionary:
	if not _loaded:
		_load()
	return _definitions


static func has_type(rule_type: String) -> bool:
	return definitions().has(rule_type)


static func definition(rule_type: String) -> Dictionary:
	return definitions().get(rule_type, {})


## True for rules that refuse a word instead of weakening it.
static func forbids(rule: Dictionary) -> bool:
	var info: Dictionary = definition(String(rule.get("type", "")))
	return bool(info.get("forbids", false))


## A run-long or temporary amnesia rule forbidding one letter.
static func amnesia(letter: String) -> Dictionary:
	return {"type": "amnesia", "letter": letter.to_lower()}


static func display_name(rule: Dictionary) -> String:
	var info: Dictionary = definition(String(rule.get("type", "")))
	return String(info.get("name", rule.get("type", "")))


## Player-facing text with the rule's parameters filled in.
static func describe(rule: Dictionary) -> String:
	var info: Dictionary = definition(String(rule.get("type", "")))
	var text: String = String(info.get("text", ""))
	var pos: String = String(rule.get("pos", ""))
	var tags: Array = rule.get("tags", [])
	var tag_text: String = " or ".join(PackedStringArray(tags))
	return text.format({
		"letter": String(rule.get("letter", "")).to_upper(),
		"length": str(int(rule.get("length", 0))),
		"pos_name": WordNet.pos_name(pos) if not pos.is_empty() else "",
		"tag": tag_text,
	})


## True when the word satisfies the rule. prompt_pos is the POS the
## word is being played as (used by counter rules).
static func check(
	rule: Dictionary, word: String, prompt_pos: String = ""
) -> bool:
	var normalized: String = word.strip_edges().to_lower()
	var letter: String = String(rule.get("letter", ""))
	match String(rule.get("type", "")):
		"min_length":
			return normalized.length() >= int(rule.get("length", 0))
		"max_length":
			return normalized.length() <= int(rule.get("length", 99))
		"required_letter":
			return normalized.contains(letter)
		"starts_with":
			return normalized.begins_with(letter)
		"ends_with":
			return normalized.ends_with(letter)
		"repeated_letter":
			return _has_repeated_letter(normalized)
		"also_pos":
			var pos: String = String(rule.get("pos", ""))
			return WordNet.parts_of_speech(normalized).has(pos)
		"counter":
			return _counters(normalized, rule.get("tags", []), prompt_pos)
		"amnesia":
			return not normalized.contains(letter)
	return true


## Cheap checks only, for scanning the lexicon; counter rules are
## handled by restricting candidates to counter targets instead.
static func check_letters(rule: Dictionary, word: String) -> bool:
	if String(rule.get("type", "")) == "counter":
		return true
	return check(rule, word)


## Per-rule results for a word: [{"rule", "text", "met", "forbids"}].
static func evaluate(
	rules: Array[Dictionary], word: String, prompt_pos: String = ""
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for rule: Dictionary in rules:
		results.append({
			"rule": rule,
			"name": display_name(rule),
			"text": describe(rule),
			"met": check(rule, word, prompt_pos),
			"forbids": forbids(rule),
		})
	return results


## The first forbidding rule the word breaks, or {} when none.
static func first_forbidden(
	rules: Array[Dictionary], word: String
) -> Dictionary:
	for rule: Dictionary in rules:
		if forbids(rule) and not check(rule, word):
			return rule
	return {}


## True when every rule is met by at least one playable word of the
## POS (base-form verbs for "v"). An empty POS accepts any POS.
static func has_solution(
	rules: Array[Dictionary], pos: String
) -> bool:
	return not find_solutions(rules, pos, 1).is_empty()


## Up to limit playable words meeting every rule, as proof and hints.
static func find_solutions(
	rules: Array[Dictionary], pos: String, limit: int = 1,
	start: int = 0
) -> Array[String]:
	var positions: Array[String] = [pos]
	if pos.is_empty():
		positions = ["n", "v", "a", "r"]
	var found: Array[String] = []
	for candidate_pos: String in positions:
		var accepts: Callable = _solution_predicate(
			rules, candidate_pos
		)
		var counter_rule: Dictionary = _counter_rule(rules)
		if counter_rule.is_empty():
			found.append_array(WordNet.find_words(
				candidate_pos, accepts, limit - found.size(), start
			))
		else:
			for target: String in _counter_targets(
				counter_rule, candidate_pos
			):
				if accepts.call(target) and not found.has(target):
					found.append(target)
					if found.size() >= limit:
						break
		if found.size() >= limit:
			break
	return found


## A random rule of the type with parameters drawn from its data.
## context may carry "tags" (counter rules) and "prompt_pos" (POS
## rules pick another POS). Returns {} for unknown types.
static func roll(
	rule_type: String, rng: RandomNumberGenerator,
	context: Dictionary = {}
) -> Dictionary:
	var info: Dictionary = definition(rule_type)
	if info.is_empty():
		return {}
	var rule: Dictionary = {"type": rule_type}
	if info.has("letters"):
		var letters: String = String(info["letters"])
		var index: int = rng.randi_range(0, letters.length() - 1)
		rule["letter"] = letters[index]
	if info.has("lengths"):
		var lengths: Array = info["lengths"]
		rule["length"] = int(lengths[rng.randi_range(0, lengths.size() - 1)])
	if info.has("positions"):
		var options: Array[String] = []
		for pos: Variant in info["positions"]:
			if String(pos) != String(context.get("prompt_pos", "")):
				options.append(String(pos))
		if options.is_empty():
			return {}
		rule["pos"] = options[rng.randi_range(0, options.size() - 1)]
	if rule_type == "counter":
		var tags: Array = context.get("tags", [])
		if tags.is_empty():
			return {}
		rule["tags"] = tags.duplicate()
	return rule


## True when a rule would be met by every word of the prompt POS,
## so it adds nothing and should rotate.
static func is_trivial(rule: Dictionary, prompt_pos: String) -> bool:
	return String(rule.get("type", "")) == "also_pos" \
			and String(rule.get("pos", "")) == prompt_pos


## Letters forbidden by any forbidding rule in the list.
static func forbidden_letters(rules: Array[Dictionary]) -> String:
	var letters: String = ""
	for rule: Dictionary in rules:
		if forbids(rule) and not letters.contains(
			String(rule.get("letter", ""))
		):
			letters += String(rule.get("letter", ""))
	return letters


static func _solution_predicate(
	rules: Array[Dictionary], pos: String
) -> Callable:
	return func(word: String) -> bool:
		for rule: Dictionary in rules:
			if not check_letters(rule, word):
				return false
		return WordValidator.check_word(word, pos)["valid"]


static func _counter_rule(rules: Array[Dictionary]) -> Dictionary:
	for rule: Dictionary in rules:
		if String(rule.get("type", "")) == "counter":
			return rule
	return {}


static func _counter_targets(
	rule: Dictionary, pos: String
) -> Array[String]:
	var targets: Array[String] = []
	for tag: Variant in rule.get("tags", []):
		for target: String in WordNet.counter_targets(String(tag), pos):
			if not targets.has(target):
				targets.append(target)
	return targets


static func _counters(word: String, tags: Array, pos: String) -> bool:
	for tag: Variant in tags:
		var result: Dictionary = WordNet.counter_detailed(
			word, String(tag), pos
		)
		if float(result.get("score", 0.0)) >= COUNTER_THRESHOLD:
			return true
	return false


static func _has_repeated_letter(word: String) -> bool:
	for index: int in word.length():
		if word.find(word[index], index + 1) >= 0:
			return true
	return false


static func _load() -> void:
	_loaded = true
	_definitions = {}
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("WordRules: cannot open rule data")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("WordRules: rule data is not valid JSON")
		return
	for rule_type: String in parsed:
		var entry: Variant = parsed[rule_type]
		if typeof(entry) == TYPE_DICTIONARY \
				and typeof(entry.get("text")) == TYPE_STRING:
			_definitions[rule_type] = entry
		else:
			push_error("WordRules: %s skipped: needs text" % rule_type)
