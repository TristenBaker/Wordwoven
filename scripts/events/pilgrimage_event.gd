class_name PilgrimageEvent
extends NoncombatEvent
## Letter on Pilgrimage: choose one of a few offered letters, write a
## word containing it, then loan that exact instance for the upcoming
## fight. After a victory it returns with the previewed upgrade.
## Never offered before the final fight, where the upgrade is moot.


func is_eligible(context: Dictionary) -> bool:
	if bool(context.get("final", false)):
		return false
	var minimum: int = int(definition.get("minimum_circulating", 12))
	return int(context.get("circulating", 0)) >= minimum


func prepare(state: Dictionary, rng: RandomNumberGenerator) -> void:
	var pool: Array[LetterStats] = RunState.circulating_deck()
	var ids: Array[int] = []
	var letters: String = ""
	var wanted: int = int(definition.get("candidates", 4))
	while ids.size() < wanted and not pool.is_empty():
		var stats: LetterStats = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(stats)
		# One candidate per letter keeps the choice meaningful.
		if letters.contains(stats.letter):
			continue
		letters += stats.letter
		ids.append(stats.instance_id)
	var modifier_id: String = ""
	if bool(definition.get("upgrade_modifier", true)):
		modifier_id = LetterUpgrade.random_modifier(rng)
	state["params"] = {
		"candidates": ids,
		"upgrade": {
			"levels": int(definition.get("upgrade_levels", 2)),
			"modifier": modifier_id,
		},
		"selected": 0,
		"step": "choose",
	}


func view(state: Dictionary) -> Dictionary:
	var params: Dictionary = state["params"]
	var upgrade: Dictionary = params["upgrade"]
	var body: String = "%s\n\nOn return after a victory: %s." % [
		description(), LetterUpgrade.describe(upgrade),
	]
	var picker: Array[Dictionary] = []
	var actions: Array[Dictionary] = []
	var prompt: String = ""
	var selected: LetterStats = RunState.find_letter(
		int(params["selected"])
	)
	match String(params["step"]):
		"choose":
			body += "\n\nChoose which letter walks with the pilgrim."
			for instance_id: Variant in params["candidates"]:
				var stats: LetterStats = RunState.find_letter(
					int(instance_id)
				)
				if stats == null:
					continue
				picker.append({
					"id": str(stats.instance_id),
					"label": "%s Lv%d" % [
						stats.letter.to_upper(), stats.level
					],
					"tooltip": "%s (%s)\nReturns as: %s" % [
						stats.describe(), stats.tag_text(),
						LetterUpgrade.preview(stats, upgrade),
					],
				})
		"word":
			prompt = "Write any word containing %s to send %s off." % [
				selected.letter.to_upper(), selected.tag_text(),
			]
			actions.append(action("back", "Choose another letter"))
		"confirm":
			body += "\n\n%s is ready. It will sit out the next fight" \
					% selected.tag_text()
			body += " and return as %s." % LetterUpgrade.preview(
				selected, upgrade
			)
			var confirm: String = "Loan %s for the next fight?" % \
					selected.describe()
			confirm += " It returns as %s after a victory." % \
					LetterUpgrade.preview(selected, upgrade)
			actions.append(action(
				"loan", "Send %s on pilgrimage" % selected.tag_text(),
				true, "", confirm
			))
	actions.append(action("decline", "Keep your letters"))
	return {
		"body": body, "prompt": prompt, "picker": picker,
		"actions": actions,
	}


func submit_word(state: Dictionary, word: String) -> Dictionary:
	var params: Dictionary = state["params"]
	if String(params["step"]) != "word":
		return {"valid": false, "reason": "Choose a letter first."}
	var selected: LetterStats = RunState.find_letter(
		int(params["selected"])
	)
	if selected == null:
		return {"valid": false, "reason": "That letter is gone."}
	var rules: Array[Dictionary] = [
		{"type": "required_letter", "letter": selected.letter},
	]
	var verdict: Dictionary = challenge_verdict(word, rules)
	if verdict["valid"]:
		params["step"] = "confirm"
	return verdict


func act(state: Dictionary, action_id: String, value: String) -> String:
	var params: Dictionary = state["params"]
	match action_id:
		"pick":
			if String(params["step"]) != "choose" \
					or not params["candidates"].has(int(value)):
				return ""
			params["selected"] = int(value)
			params["step"] = "word"
			return ""
		"back":
			params["step"] = "choose"
			return ""
		"loan":
			if String(params["step"]) != "confirm" or is_resolved(state):
				return ""
			RunState.loans.append({
				"instance_id": int(params["selected"]),
				"encounter": int(state["stage"]),
				"upgrade": Dictionary(params["upgrade"]).duplicate(),
				"returned": false,
			})
			resolve(state, "loaned")
			return "The pilgrim sets off with your letter."
	return super.act(state, action_id, value)
