class_name CopyistEvent
extends NoncombatEvent
## The Copyist: prove your penmanship with one word challenge, then
## choose one service: attach the previewed modifier to a letter,
## move an existing modifier to another letter, or replace one of a
## letter's modifiers with the previewed one.


func prepare(state: Dictionary, rng: RandomNumberGenerator) -> void:
	state["params"] = {
		"rule": solvable_rule(
			definition.get("rule_types", []), rng, [""]
		),
		"modifier": LetterUpgrade.random_modifier(rng),
		"step": "challenge",
		"source": "",
	}


func view(state: Dictionary) -> Dictionary:
	var params: Dictionary = state["params"]
	var modifier_id: String = String(params["modifier"])
	var body: String = "%s\n\nOn offer: %s — %s" % [
		description(), ModifierCatalog.display_name(modifier_id),
		ModifierCatalog.describe(modifier_id),
	]
	var prompt: String = ""
	var picker: Array[Dictionary] = []
	var actions: Array[Dictionary] = []
	match String(params["step"]):
		"challenge":
			prompt = "Prove your hand: " + WordRules.describe(
				params["rule"]
			)
		"service":
			body += "\n\nChoose a service."
			actions.append(action(
				"attach", "Attach %s" % ModifierCatalog.display_name(
					modifier_id
				), not _free_slots().is_empty()
			))
			actions.append(action(
				"move", "Move a modifier", _can_move(),
				"Take a modifier off one letter and put it on another."
			))
			actions.append(action(
				"replace", "Replace a modifier",
				not _modifier_slots().is_empty(),
				"Swap one attached modifier for %s." % \
						ModifierCatalog.display_name(modifier_id)
			))
		"attach":
			body += "\n\nChoose the letter to receive %s." % \
					ModifierCatalog.display_name(modifier_id)
			picker = _letter_picker(_free_slots(), modifier_id)
			actions.append(action("back", "Back"))
		"move_source":
			body += "\n\nChoose the modifier to move."
			picker = _slot_picker()
			actions.append(action("back", "Back"))
		"move_target":
			var moving: String = _slot_modifier(String(params["source"]))
			body += "\n\nChoose the letter to receive %s." % \
					ModifierCatalog.display_name(moving)
			picker = _letter_picker(
				_free_slots(_slot_letter(String(params["source"]))),
				moving
			)
			actions.append(action("back", "Back"))
		"replace":
			body += "\n\nChoose the modifier to replace with %s." % \
					ModifierCatalog.display_name(modifier_id)
			picker = _slot_picker()
			actions.append(action("back", "Back"))
	actions.append(action("decline", "Leave the Copyist"))
	return {
		"body": body, "prompt": prompt, "picker": picker,
		"actions": actions,
	}


func submit_word(state: Dictionary, word: String) -> Dictionary:
	var params: Dictionary = state["params"]
	if String(params["step"]) != "challenge":
		return {"valid": false, "reason": "Your hand is already proven."}
	var rules: Array[Dictionary] = [params["rule"]]
	var verdict: Dictionary = challenge_verdict(word, rules)
	if verdict["valid"]:
		params["step"] = "service"
	return verdict


func act(state: Dictionary, action_id: String, value: String) -> String:
	var params: Dictionary = state["params"]
	var step: String = String(params["step"])
	var modifier_id: String = String(params["modifier"])
	match action_id:
		"attach":
			if step == "service" and not _free_slots().is_empty():
				params["step"] = "attach"
			return ""
		"move":
			if step == "service" and _can_move():
				params["step"] = "move_source"
			return ""
		"replace":
			if step == "service" and not _modifier_slots().is_empty():
				params["step"] = "replace"
			return ""
		"back":
			if step != "challenge" and not is_resolved(state):
				params["step"] = "service"
			return ""
		"pick":
			return _pick(state, step, value, modifier_id)
	return super.act(state, action_id, value)


func _pick(
	state: Dictionary, step: String, value: String, modifier_id: String
) -> String:
	var params: Dictionary = state["params"]
	if is_resolved(state):
		return ""
	match step:
		"attach":
			var target: LetterStats = RunState.find_letter(int(value))
			if target == null or not target.add_modifier(modifier_id):
				return ""
			resolve(state, "attached")
			EventBus.emit_deck_changed()
			return "%s now carries %s." % [
				target.tag_text(), ModifierCatalog.display_name(modifier_id),
			]
		"move_source":
			if _slot_modifier(value).is_empty():
				return ""
			params["source"] = value
			params["step"] = "move_target"
			return ""
		"move_target":
			var source: LetterStats = _slot_letter(String(params["source"]))
			var target: LetterStats = RunState.find_letter(int(value))
			if source == null or target == null or target == source \
					or not target.can_add_modifier():
				return ""
			var moved: String = source.remove_modifier_at(
				_slot_index(String(params["source"]))
			)
			target.add_modifier(moved)
			resolve(state, "moved")
			EventBus.emit_deck_changed()
			return "%s moves from %s to %s." % [
				ModifierCatalog.display_name(moved), source.tag_text(),
				target.tag_text(),
			]
		"replace":
			var holder: LetterStats = _slot_letter(value)
			if holder == null or _slot_modifier(value).is_empty():
				return ""
			var replaced: String = holder.remove_modifier_at(
				_slot_index(value)
			)
			holder.modifiers.insert(_slot_index(value), modifier_id)
			resolve(state, "replaced")
			EventBus.emit_deck_changed()
			return "%s's %s becomes %s." % [
				holder.tag_text(), ModifierCatalog.display_name(replaced),
				ModifierCatalog.display_name(modifier_id),
			]
	return ""


# Owned letters with a free modifier slot, optionally excluding one.
func _free_slots(excluded: LetterStats = null) -> Array[LetterStats]:
	var letters: Array[LetterStats] = []
	for stats: LetterStats in RunState.deck:
		if stats != excluded and stats.can_add_modifier() \
				and stats.letter != RunState.forgotten_letter:
			letters.append(stats)
	return letters


# "instance_id:slot" for every attached modifier.
func _modifier_slots() -> Array[String]:
	var slots: Array[String] = []
	for stats: LetterStats in RunState.deck:
		var ids: Array[String] = stats.modifier_ids()
		for slot: int in ids.size():
			slots.append("%d:%d" % [stats.instance_id, slot])
	return slots


func _can_move() -> bool:
	for slot_key: String in _modifier_slots():
		if not _free_slots(_slot_letter(slot_key)).is_empty():
			return true
	return false


func _slot_letter(slot_key: String) -> LetterStats:
	return RunState.find_letter(int(slot_key.get_slice(":", 0)))


func _slot_index(slot_key: String) -> int:
	return int(slot_key.get_slice(":", 1))


func _slot_modifier(slot_key: String) -> String:
	var stats: LetterStats = _slot_letter(slot_key)
	if stats == null:
		return ""
	var ids: Array[String] = stats.modifier_ids()
	var slot: int = _slot_index(slot_key)
	if slot < 0 or slot >= ids.size():
		return ""
	return ids[slot]


func _letter_picker(
	letters: Array[LetterStats], modifier_id: String
) -> Array[Dictionary]:
	var picker: Array[Dictionary] = []
	var upgrade: Dictionary = {"levels": 0, "modifier": modifier_id}
	for stats: LetterStats in letters:
		picker.append({
			"id": str(stats.instance_id),
			"label": "%s Lv%d" % [stats.letter.to_upper(), stats.level],
			"tooltip": "%s (%s)\nBecomes: %s" % [
				stats.describe(), stats.tag_text(),
				LetterUpgrade.preview(stats, upgrade),
			],
		})
	return picker


func _slot_picker() -> Array[Dictionary]:
	var picker: Array[Dictionary] = []
	for slot_key: String in _modifier_slots():
		var stats: LetterStats = _slot_letter(slot_key)
		var modifier_id: String = _slot_modifier(slot_key)
		picker.append({
			"id": slot_key,
			"label": "%s: %s" % [
				stats.tag_text(), ModifierCatalog.display_name(modifier_id),
			],
			"tooltip": "%s\n%s" % [
				stats.describe(), ModifierCatalog.describe(modifier_id),
			],
		})
	return picker
