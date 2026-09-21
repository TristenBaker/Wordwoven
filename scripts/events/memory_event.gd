class_name MemoryEvent
extends NoncombatEvent
## The Price of Memory: accept one run-long forbidden letter for a
## previewed reward. Words using the letter are refused for the rest
## of the run, and owned instances of it leave circulation while the
## party keeps them. Only one such bargain is permitted per run.

const PROMPT_POSITIONS: Array[String] = ["n", "v", "a", "r"]


func is_eligible(context: Dictionary) -> bool:
	return String(context.get("forgotten", "")).is_empty() \
			and RunState.forgotten_letter.is_empty()


func prepare(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var options: Array[String] = _letter_options()
	var letter: String = ""
	if not options.is_empty():
		letter = options[rng.randi_range(0, options.size() - 1)]
	var entries: Array = definition.get("rewards", [])
	var entry: Dictionary = entries[rng.randi_range(0, entries.size() - 1)]
	state["params"] = {
		"letter": letter,
		"reward": concrete_reward(entry, rng),
		"gold": int(definition.get("bonus_gold", 0)),
	}


func view(state: Dictionary) -> Dictionary:
	var params: Dictionary = state["params"]
	var letter: String = String(params["letter"])
	var actions: Array[Dictionary] = []
	var body: String = description()
	if letter.is_empty() or not RunState.forgotten_letter.is_empty():
		body += "\n\nThe archivist has nothing to buy from you today."
		actions.append(action("decline", "Walk on"))
		return {
			"body": body, "prompt": "", "picker": [], "actions": actions,
		}
	body += "\n\nThe archivist wants %s." % letter.to_upper()
	body += "\nYou would receive: %s, and %d gold." % [
		reward_text(params["reward"]), int(params["gold"]),
	]
	body += "\nLetters that would sit out every fight: %s." % \
			_affected_text(letter)
	var confirm: String = "Forget %s for the rest of the run?" % \
			letter.to_upper()
	confirm += " Words using it are refused, and %s sit out." % \
			_affected_text(letter)
	actions.append(action(
		"accept", "Sell the letter %s" % letter.to_upper(), true, "",
		confirm
	))
	actions.append(action("decline", "Keep your memory"))
	return {
		"body": body, "prompt": "", "picker": [], "actions": actions,
	}


func act(state: Dictionary, action_id: String, value: String) -> String:
	var params: Dictionary = state["params"]
	if action_id == "accept":
		var letter: String = String(params["letter"])
		if is_resolved(state) or letter.is_empty() \
				or not RunState.forgotten_letter.is_empty():
			return ""
		RunState.forgotten_letter = letter
		grant_once(state, "memory", params["reward"])
		grant_once(state, "memory_gold", {
			"kind": "gold", "amount": int(params["gold"]),
		})
		EventBus.emit_deck_changed()
		resolve(state, "forgotten")
		return "%s fades from memory." % letter.to_upper()
	return super.act(state, action_id, value)


# Letters whose loss still leaves every prompt, vow, and loan
# workable and keeps enough letters in circulation.
func _letter_options() -> Array[String]:
	var options: Array[String] = []
	var minimum: int = int(definition.get("minimum_circulating", 12))
	var loan_letters: String = _loaned_letters()
	for letter: String in String(definition.get("letters", "")):
		if loan_letters.contains(letter):
			continue
		var remaining: int = 0
		for stats: LetterStats in RunState.circulating_deck():
			if stats.letter != letter:
				remaining += 1
		if remaining < minimum:
			continue
		var rules: Array[Dictionary] = RunState.fixed_combat_rules()
		rules.append(WordRules.amnesia(letter))
		if _vows_require(letter):
			continue
		var solvable: bool = true
		for pos: String in PROMPT_POSITIONS:
			if not WordRules.has_solution(rules, pos):
				solvable = false
				break
		if solvable:
			options.append(letter)
	return options


func _vows_require(letter: String) -> bool:
	for vow: Dictionary in RunState.vows:
		var rule: Dictionary = vow["rule"]
		if String(rule.get("letter", "")) == letter \
				and int(vow["encounter"]) >= RunState.encounter_index:
			return true
	return false


func _loaned_letters() -> String:
	var letters: String = ""
	for loan: Dictionary in RunState.loans:
		if bool(loan["returned"]):
			continue
		var stats: LetterStats = RunState.find_letter(
			int(loan["instance_id"])
		)
		if stats != null:
			letters += stats.letter
	return letters


func _affected_text(letter: String) -> String:
	var tags: Array[String] = []
	for stats: LetterStats in RunState.deck:
		if stats.letter == letter:
			tags.append(stats.tag_text())
	if tags.is_empty():
		return "none"
	return ", ".join(tags)
