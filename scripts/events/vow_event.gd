class_name VowEvent
extends NoncombatEvent
## The Vow: demonstrate a word rule once, then optionally swear it
## for the next battle in exchange for a previewed reward. During
## that battle, words that break the vow deal half damage. The rule
## is proven solvable for every prompt alongside the standing rules.

const PROMPT_POSITIONS: Array[String] = ["n", "v", "a", "r"]


func prepare(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var rule: Dictionary = solvable_rule(
		definition.get("rule_types", []), rng, PROMPT_POSITIONS,
		RunState.fixed_combat_rules()
	)
	var entries: Array = definition.get("rewards", [])
	var entry: Dictionary = entries[rng.randi_range(0, entries.size() - 1)]
	state["params"] = {
		"rule": rule,
		"reward": concrete_reward(entry, rng),
		"step": "demonstrate",
	}


func view(state: Dictionary) -> Dictionary:
	var params: Dictionary = state["params"]
	var rule: Dictionary = params["rule"]
	var actions: Array[Dictionary] = []
	var prompt: String = ""
	var body: String = description()
	if rule.is_empty():
		body += "\n\nThe oathkeeper finds no fitting vow today."
		actions.append(action("decline", "Walk on"))
		return {
			"body": body, "prompt": "", "picker": [], "actions": actions,
		}
	body += "\n\nThe vow: %s\nThe boon: %s" % [
		WordRules.describe(rule), reward_text(params["reward"]),
	]
	if String(params["step"]) == "demonstrate":
		prompt = "Demonstrate the vow: " + WordRules.describe(rule)
	else:
		body += "\n\nYou have shown you can keep it."
		var confirm: String = "Bind your next battle with '%s'?" % \
				WordRules.describe(rule)
		confirm += " Words that break it deal half damage."
		confirm += " You receive %s." % reward_text(params["reward"])
		actions.append(action(
			"swear", "Swear the vow", true, "", confirm
		))
	actions.append(action("decline", "Refuse the vow"))
	return {
		"body": body, "prompt": prompt, "picker": [], "actions": actions,
	}


func submit_word(state: Dictionary, word: String) -> Dictionary:
	var params: Dictionary = state["params"]
	if String(params["step"]) != "demonstrate" \
			or Dictionary(params["rule"]).is_empty():
		return {"valid": false, "reason": "The vow is already shown."}
	var rules: Array[Dictionary] = [params["rule"]]
	var verdict: Dictionary = challenge_verdict(word, rules)
	if verdict["valid"]:
		params["step"] = "decide"
	return verdict


func act(state: Dictionary, action_id: String, value: String) -> String:
	var params: Dictionary = state["params"]
	if action_id == "swear":
		if String(params["step"]) != "decide" or is_resolved(state):
			return ""
		RunState.vows.append({
			"encounter": int(state["stage"]),
			"rule": Dictionary(params["rule"]).duplicate(true),
		})
		grant_once(state, "vow", params["reward"])
		resolve(state, "sworn")
		return "The vow is sworn. Your boon: %s." % \
				RewardSystem.new().title(params["reward"])
	return super.act(state, action_id, value)
