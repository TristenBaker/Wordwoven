class_name EnemyRuleTracker
extends RefCounted
## The enemy's visible, rotating word rule for one encounter. A rule
## rotates after a word meets it or after two accepted words, and is
## only chosen when it can be solved together with the fixed rules
## (a vow and any run-long amnesia) for the current prompt.

const WORDS_BEFORE_ROTATION: int = 2
const ROLL_ATTEMPTS: int = 12

var rng: RandomNumberGenerator = null
var pool: Array[String] = []
var tags: Array[String] = []
# Rules that last the whole encounter; each new rule must fit them.
var fixed_rules: Array[Dictionary] = []

var _current: Dictionary = {}
var _accepted_since_roll: int = 0


func _init(
	new_pool: Array[String], new_tags: Array[String],
	new_fixed: Array[Dictionary], new_rng: RandomNumberGenerator
) -> void:
	for rule_type: String in new_pool:
		if WordRules.has_type(rule_type):
			pool.append(rule_type)
	tags = new_tags.duplicate()
	fixed_rules = new_fixed.duplicate(true)
	rng = new_rng


func current() -> Dictionary:
	return _current


## Every rule a word is judged by this turn: fixed rules first.
func active_rules() -> Array[Dictionary]:
	var rules: Array[Dictionary] = fixed_rules.duplicate(true)
	if not _current.is_empty():
		rules.append(_current)
	return rules


## Chooses a solvable rule for the prompt, avoiding the current type.
## Returns true when a rule was chosen; an enemy without a solvable
## option simply has no rule this turn.
func roll(prompt_pos: String) -> bool:
	var previous_type: String = String(_current.get("type", ""))
	_current = {}
	_accepted_since_roll = 0
	if pool.is_empty():
		return false
	var context: Dictionary = {"tags": tags, "prompt_pos": prompt_pos}
	for attempt: int in ROLL_ATTEMPTS:
		var choices: Array[String] = pool.duplicate()
		if choices.size() > 1:
			choices.erase(previous_type)
		var rule_type: String = choices[
			rng.randi_range(0, choices.size() - 1)
		]
		var rule: Dictionary = WordRules.roll(rule_type, rng, context)
		if rule.is_empty() or WordRules.is_trivial(rule, prompt_pos):
			continue
		if _compatible(rule, prompt_pos):
			_current = rule
			return true
	return false


## Records an accepted word and rotates when due. Returns true when
## a new rule was rolled for the next prompt.
func after_accepted(met: bool, next_pos: String) -> bool:
	_accepted_since_roll += 1
	if met or _accepted_since_roll >= WORDS_BEFORE_ROTATION:
		roll(next_pos)
		return true
	if _current.is_empty() or WordRules.is_trivial(_current, next_pos) \
			or not WordRules.has_solution(active_rules(), next_pos):
		roll(next_pos)
		return true
	return false


func accepted_since_roll() -> int:
	return _accepted_since_roll


## Removes the rotating rule for the rest of the encounter.
func clear() -> void:
	pool = []
	_current = {}
	_accepted_since_roll = 0


# The rule must not repeat a fixed forbidden letter as a requirement,
# and all rules together must still admit a playable word.
func _compatible(rule: Dictionary, prompt_pos: String) -> bool:
	var forbidden: String = WordRules.forbidden_letters(fixed_rules)
	var letter: String = String(rule.get("letter", ""))
	if not letter.is_empty() and forbidden.contains(letter):
		return false
	var combined: Array[Dictionary] = fixed_rules.duplicate(true)
	combined.append(rule)
	return WordRules.has_solution(combined, prompt_pos)
