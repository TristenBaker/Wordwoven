class_name RiddleEvent
extends NoncombatEvent
## Riddle Gate: untimed riddles of one, two, then three word rules,
## each for a richer previewed reward that is banked on the spot.
## The player may leave at any time; too many wrong answers seal the
## gate. Every riddle is proven solvable before it is shown.

const POSITIONS: Array[String] = ["n", "v", "a"]


func prepare(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var riddles: Array[Dictionary] = []
	for tier: Variant in definition.get("tiers", []):
		var info: Dictionary = tier
		riddles.append(_build_riddle(
			int(info.get("rules", 1)), rng,
			concrete_reward(info.get("reward", {}), rng)
		))
	state["params"] = {
		"riddles": riddles,
		"solved": 0,
		"misses": 0,
		"used": [],
	}


func view(state: Dictionary) -> Dictionary:
	var params: Dictionary = state["params"]
	var riddles: Array = params["riddles"]
	var solved: int = int(params["solved"])
	var lines: Array[String] = [description(), ""]
	for index: int in riddles.size():
		var riddle: Dictionary = riddles[index]
		var marker: String = "Solved" if index < solved else "Reward"
		lines.append("Riddle %d. %s: %s" % [
			index + 1, marker, reward_text(riddle["reward"]),
		])
	lines.append("Wrong answers: %d of %d." % [
		int(params["misses"]), _miss_limit(),
	])
	var prompt: String = ""
	var actions: Array[Dictionary] = []
	if solved < riddles.size() and not is_resolved(state):
		var riddle: Dictionary = riddles[solved]
		if Array(riddle["rules"]).is_empty():
			lines.append("The gate falls silent; no riddle remains.")
		else:
			prompt = "Riddle %d: %s" % [solved + 1, riddle_text(riddle)]
	var leave_label: String = "Leave the gate" if solved > 0 \
			else "Walk past the gate"
	actions.append(action("leave", leave_label))
	return {
		"body": "\n".join(lines), "prompt": prompt, "picker": [],
		"actions": actions,
	}


## "Write a noun that begins with S and ends with E." style text.
func riddle_text(riddle: Dictionary) -> String:
	var clauses: Array[String] = []
	for rule: Variant in riddle["rules"]:
		clauses.append(WordRules.describe(rule).trim_suffix("."))
	return "Write a %s. %s." % [
		WordNet.pos_name(String(riddle["pos"])), ". ".join(clauses),
	]


func submit_word(state: Dictionary, word: String) -> Dictionary:
	var params: Dictionary = state["params"]
	var riddles: Array = params["riddles"]
	var solved: int = int(params["solved"])
	if is_resolved(state) or solved >= riddles.size():
		return {"valid": false, "reason": "The gate has no riddle left."}
	var riddle: Dictionary = riddles[solved]
	var rules: Array[Dictionary] = []
	for rule: Variant in riddle["rules"]:
		rules.append(rule)
	var used: Array[String] = []
	for used_word: Variant in params["used"]:
		used.append(String(used_word))
	var verdict: Dictionary = challenge_verdict(
		word, rules, String(riddle["pos"]), used
	)
	if not verdict["valid"]:
		params["misses"] = int(params["misses"]) + 1
		if int(params["misses"]) >= _miss_limit():
			resolve(state, "sealed")
			verdict["reason"] += " The gate seals shut."
		return verdict
	used.append(word.strip_edges().to_lower())
	params["used"] = used
	grant_once(state, "riddle_%d" % solved, riddle["reward"])
	params["solved"] = solved + 1
	if int(params["solved"]) >= riddles.size():
		resolve(state, "solved")
	return verdict


func act(state: Dictionary, action_id: String, value: String) -> String:
	if action_id == "leave":
		if not is_resolved(state):
			var solved: int = int(state["params"]["solved"])
			resolve(state, "left" if solved > 0 else "declined")
		return "You leave the gate behind."
	return super.act(state, action_id, value)


func _miss_limit() -> int:
	return int(definition.get("misses", 3))


# A riddle of rule_count distinct rule types with a verified answer.
func _build_riddle(
	rule_count: int, rng: RandomNumberGenerator, reward: Dictionary
) -> Dictionary:
	var types: Array = definition.get("rule_types", [])
	for attempt: int in 20:
		var pos: String = POSITIONS[rng.randi_range(0, POSITIONS.size() - 1)]
		var pool: Array = types.duplicate()
		var rules: Array[Dictionary] = []
		while rules.size() < rule_count and not pool.is_empty():
			var picked: Dictionary = solvable_rule(
				pool, rng, [pos], rules
			)
			if picked.is_empty():
				break
			pool.erase(String(picked["type"]))
			rules.append(picked)
		if rules.size() == rule_count:
			return {"pos": pos, "rules": rules, "reward": reward}
	return {"pos": "n", "rules": [], "reward": reward}
