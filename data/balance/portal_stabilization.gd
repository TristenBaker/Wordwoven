extends RefCounted
const CALM: Array[String] = ["carefully", "gently", "slowly", "calmly", "patiently", "quietly", "cautiously", "softly", "steadily", "deliberately"]
const ENERGETIC: Array[String] = ["quickly", "boldly", "bravely", "swiftly", "rapidly", "energetically", "vigorously", "confidently", "forcefully", "eagerly"]
const ROUNDS: Array[Dictionary] = [
	{"problem": "The rim wobbles like enchanted jelly.", "steady": "Brace the rim", "charge": "Feed the sparks"},
	{"problem": "A wizard's sandwich is stuck between realities.", "steady": "Seal the crack", "charge": "Charge the runes"},
	{"problem": "The portal demands a final signature. In triplicate.", "steady": "Anchor the gate", "charge": "Power the exit"},
]

static func initial_state() -> Dictionary:
	return {"turn": 0, "value": 0, "charges": 0, "words": [], "feedback": "Choose an action, then describe HOW you perform it with an adverb.", "awaiting_next": false}

static func behavior(word: String) -> String:
	if CALM.has(word): return "Calm"
	if ENERGETIC.has(word): return "Energetic"
	return "Unusual"

static func gain(word: String, choice: int) -> int:
	var kind: String = behavior(word)
	var amount: int = 2 if choice == 0 else 1
	if kind == "Calm": amount += 1
	elif kind == "Energetic": amount += -1 if choice == 0 else 2
	return amount

static func presentation(state: Dictionary, _word: String = "") -> Dictionary:
	var round_data: Dictionary = ROUNDS[mini(int(state.turn), 2)]
	var hint: String = "The portal responds to HOW you act. Choose an ADVERB to influence its unstable magic. Different approaches may affect its stability or treasure."
	return {"heading": "STABILIZE THE PORTAL • Round %d / 3" % mini(int(state.turn) + 1, 3), "meter": "Stability: %d / 9 • Goal 6 • Treasure charges: %d" % [state.value, state.charges], "maximum": 9, "instruction": "%s Reach 6 stability: 2+ charges pays 8 gold; otherwise heal 5 HP." % round_data.problem, "preview": hint, "choices": ["%s\nBase +2 stability" % round_data.steady, "%s\nBase +1 stability, +1 treasure charge" % round_data.charge], "submit": "Weave"}

static func play(state: Dictionary, word: String, choice: int) -> void:
	var amount: int = gain(word, choice)
	state.value = mini(9, int(state.value) + amount)
	if choice == 1: state.charges += 1
	state.turn += 1
	state.words.append(word)
	state.feedback = "You work %s. +%d stability%s. %s" % [word, amount, " and +1 treasure charge" if choice == 1 else "", "The portal exhales. 'Thank you for respecting my personal space.'" if behavior(word) == "Calm" else ("A wizard drops his sandwich. 'That was load-bearing!'" if behavior(word) == "Energetic" else "Reality stamps your application: UNUSUAL, BUT ACCEPTABLE.")]
	state.awaiting_next = not is_finished(state)

static func is_finished(state: Dictionary) -> bool:
	return int(state.turn) >= 3

static func outcome(state: Dictionary) -> Dictionary:
	if int(state.value) < 6:
		return {"type": "gold", "amount": 0, "dialogue": "The portal folds into a polite puddle. No reward, but all your limbs are accounted for."}
	if int(state.charges) >= 2:
		return {"type": "gold", "amount": 8, "dialogue": "Portal stabilized! The treasury approves your withdrawal. Please keep the receipt."}
	return {"type": "heal", "amount": 5, "dialogue": "Portal stabilized! A restorative breeze arrives with a strongly worded invoice."}
