extends RefCounted
## Per-fight state for the additional fates. Preview methods never advance it.
const TAG_PAIRS: String = "res://data/chameleon_tags.json"
var id: String = ""
var base_attack: int = 0
var casts: int = 0
var retaliations: int = 0
var previous_word: String = ""
var gold_gained: int = 0
var gold_stolen: int = 0
var tag_pairs: Array = []
var tag_index: int = 0

func configure(modifier: Dictionary, attack: int, enemy_id: String) -> void:
	id = String(modifier.get("id", ""))
	base_attack = attack
	if id == "chameleon":
		var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TAG_PAIRS))
		tag_pairs = catalogue.get(enemy_id, []).duplicate(true)

func modify_result(result: Dictionary, word: String) -> void:
	if id == "long_winded":
		if word.length() >= 7:
			result.damage = float(result.damage) * 1.2
		else:
			result["modifier_guard"] = 2
	elif id == "echo_bound" and not previous_word.is_empty() and word.begins_with(previous_word.right(1)):
		result.damage = float(result.damage) * 1.25
	elif id == "greedy" and gold_gained < 5:
		result.gold = int(result.gold) + 1

func accept_cast(word: String) -> int:
	casts += 1
	previous_word = word
	if id == "greedy" and gold_gained < 5:
		gold_gained += 1
		return 1
	return 0

func retaliation_plan(attack: int) -> Dictionary:
	if id == "drowsy":
		return {"kind": "sleep" if retaliations % 2 == 0 else "attack", "attack": int(round(attack * 1.25)), "self_damage": 0.0}
	if id == "clumsy" and (retaliations + 1) % 3 == 0:
		return {"kind": "self_hit", "attack": 0, "self_damage": base_attack * 0.5}
	return {"kind": "attack", "attack": attack, "self_damage": 0.0}

func complete_retaliation(available_gold: int) -> int:
	retaliations += 1
	if id == "greedy" and retaliations % 2 == 0:
		var stolen: int = mini(2, mini(4 - gold_stolen, available_gold))
		gold_stolen += stolen
		return stolen
	return 0

func next_tags(current: Array[String]) -> Array[String]:
	var selected: Array[String] = []
	if id != "chameleon" or retaliations == 0 or retaliations % 2 != 0 or tag_pairs.is_empty():
		return selected
	for offset: int in tag_pairs.size():
		var candidate: Array = tag_pairs[tag_index % tag_pairs.size()]
		tag_index += 1
		if candidate.size() == current.size() and candidate.all(func(tag): return current.has(tag)):
			continue
		selected.assign(candidate)
		return selected
	return selected

func victory_bonus() -> int:
	return 8 if id == "greedy" else 0

func status(word: String = "") -> String:
	match id:
		"drowsy": return "Next: SLEEPING" if retaliations % 2 == 0 else "Next: AWAKE (+25%)"
		"clumsy": return "Self-hit in %d retaliation(s)" % (3 - retaliations % 3)
		"long_winded": return "7+ letters: +20% damage" if word.length() >= 7 else "Short words: +2 Guard"
		"echo_bound": return "First word sets the challenge" if previous_word.is_empty() else "Optional: start with %s (+25%%)" % previous_word.right(1).to_upper()
		"chameleon": return "Tags shift in %d retaliation(s)" % (2 - retaliations % 2)
		"greedy": return "Cast gold +%d/5; stolen %d/4" % [gold_gained, gold_stolen]
		"frostbite_tax": return "Freeze every 2 casts; +2 Heat"
	return ""
