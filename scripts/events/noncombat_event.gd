class_name NoncombatEvent
extends RefCounted
## Base for one kind of word-driven noncombat event. The event's
## progress lives in a state dictionary owned by RunState, so a
## revisited screen shows the same event without rerolling it and
## rewards are guarded by flags in that state. Handlers override:
## - is_eligible(context) before the event is offered;
## - prepare(state, rng) once, rolling previewed parameters;
## - view(state) describing text, word prompt, picker, and actions;
## - submit_word(state, word) and act(state, action, value).
## Every event can be declined; declining resolves it.

const STATUS_NEW: String = "new"
const STATUS_OPEN: String = "open"
const STATUS_RESOLVED: String = "resolved"

## Set by EventCatalog: this event's entry in data/events.json.
var definition: Dictionary = {}
var event_id: String = ""


## context: {"stage": int, "final": bool (the boss fight is next),
## "forgotten": String, "circulating": int}.
func is_eligible(_context: Dictionary) -> bool:
	return true


## Rolls this event's parameters into state["params"] exactly once.
func prepare(_state: Dictionary, _rng: RandomNumberGenerator) -> void:
	pass


## Returns {"body": String, "prompt": String (empty hides the word
## input), "picker": Array of {"id", "label", "tooltip"},
## "actions": Array of {"id", "label", "enabled", "tooltip",
## "confirm" (optional text asked before acting)}}.
func view(_state: Dictionary) -> Dictionary:
	return {"body": "", "prompt": "", "picker": [], "actions": []}


## Handles a typed word; returns {"valid": bool, "reason": String}.
func submit_word(_state: Dictionary, _word: String) -> Dictionary:
	return {"valid": false, "reason": "Nothing to answer here."}


## Handles a button or picker choice; returns a message to show.
func act(state: Dictionary, action: String, _value: String) -> String:
	if action == "decline":
		resolve(state, "declined")
		return "You walk on."
	return ""


func display_name() -> String:
	return String(definition.get("name", event_id))


func description() -> String:
	return String(definition.get("description", ""))


func is_resolved(state: Dictionary) -> bool:
	return String(state.get("status", "")) == STATUS_RESOLVED


func resolve(state: Dictionary, outcome: String) -> void:
	state["status"] = STATUS_RESOLVED
	state["outcome"] = outcome


## Grants a reward once per key; later calls with the key do nothing.
func grant_once(
	state: Dictionary, key: String, reward: Dictionary,
	target: LetterStats = null
) -> bool:
	var granted: Array = state.get("granted", [])
	if granted.has(key):
		return false
	if not RewardSystem.new().grant(reward, target):
		return false
	granted.append(key)
	state["granted"] = granted
	return true


func reward_text(reward: Dictionary) -> String:
	var rewards: RewardSystem = RewardSystem.new()
	return "%s: %s" % [rewards.title(reward), rewards.describe(reward)]


## A concrete reward from a data entry: relics become a specific,
## previewable relic id.
func concrete_reward(
	entry: Dictionary, rng: RandomNumberGenerator
) -> Dictionary:
	var reward: Dictionary = entry.duplicate(true)
	if String(reward.get("kind", "")) == "relic":
		reward = RewardSystem.new(rng).build_reward("relic")
	return reward


## Rules every event word must also obey: the run-long amnesia.
static func standing_rules() -> Array[Dictionary]:
	var rules: Array[Dictionary] = []
	if not RunState.forgotten_letter.is_empty():
		rules.append(WordRules.amnesia(RunState.forgotten_letter))
	return rules


## Dictionary, POS, amnesia, and challenge-rule checks for an answer.
static func challenge_verdict(
	word: String, rules: Array[Dictionary], pos: String = "",
	used_words: Array[String] = []
) -> Dictionary:
	var verdict: Dictionary = WordValidator.check_word(
		word, pos, used_words
	)
	if not verdict["valid"]:
		return verdict
	var normalized: String = word.strip_edges().to_lower()
	var broken: Dictionary = WordRules.first_forbidden(
		standing_rules(), normalized
	)
	if not broken.is_empty():
		return {"valid": false, "reason": WordRules.describe(broken)}
	for rule: Dictionary in rules:
		if not WordRules.check(rule, normalized, pos):
			return {
				"valid": false,
				"reason": "Not quite: " + WordRules.describe(rule),
			}
	return {"valid": true, "reason": ""}


## A rule of one of the types that, with the standing rules, can be
## solved for every listed POS. Returns {} after too many attempts.
static func solvable_rule(
	rule_types: Array, rng: RandomNumberGenerator,
	positions: Array[String], extra: Array[Dictionary] = []
) -> Dictionary:
	for attempt: int in 16:
		var rule_type: String = String(
			rule_types[rng.randi_range(0, rule_types.size() - 1)]
		)
		var rule: Dictionary = WordRules.roll(rule_type, rng)
		if rule.is_empty() or not _fits_amnesia(rule):
			continue
		var combined: Array[Dictionary] = standing_rules()
		combined.append_array(extra)
		combined.append(rule)
		var solvable: bool = true
		for pos: String in positions:
			if not WordRules.has_solution(combined, pos):
				solvable = false
				break
		if solvable:
			return rule
	return {}


static func action(
	id: String, label: String, enabled: bool = true,
	tooltip: String = "", confirm: String = ""
) -> Dictionary:
	return {
		"id": id, "label": label, "enabled": enabled,
		"tooltip": tooltip, "confirm": confirm,
	}


static func _fits_amnesia(rule: Dictionary) -> bool:
	var letter: String = String(rule.get("letter", ""))
	return letter.is_empty() or letter != RunState.forgotten_letter
