extends RefCounted
## Small, deterministic rules; no UI or run-state mutations.
const CATEGORIES: Array[Dictionary] = [
	{"name": "Fuel", "gain": 3, "words": ["fire", "torch", "lantern", "log", "wood", "coal", "charcoal", "campfire", "firewood"], "reaction": "The traveler warms their toes. 'Finally, a heated argument I can enjoy!'"},
	{"name": "Clothing", "gain": 2, "words": ["blanket", "coat", "sock", "socks", "scarf", "hat", "glove", "gloves", "mitten", "mittens", "jacket", "cloak", "boot", "boots", "sweater"], "reaction": "'Thermal fashion! Put me on the cover of Snow Vogue.'"},
	{"name": "Food", "gain": 2, "words": ["soup", "stew", "tea", "coffee", "bread", "porridge", "chocolate", "meal"], "reaction": "'My compliments to the conjurer. The snow's cooking was dreadful.'"},
]

static func initial_state() -> Dictionary:
	return {"turn": 0, "value": 0, "words": [], "feedback": "Three supplies, one very chilly traveler. Repeated supplies are welcome.", "awaiting_next": false}

static func supply(word: String) -> Dictionary:
	for category: Dictionary in CATEGORIES:
		if category.words.has(word):
			return category
	return {"name": "Improvised", "gain": 1, "reaction": "'An unusual heater, but the thought counts. My toes accept this donation.'"}

static func presentation(state: Dictionary, _word: String = "") -> Dictionary:
	var hint: String = "The traveler is freezing! Conjure NOUNS that could provide warmth, protection, or nourishment. Some supplies are more effective than others."
	return {"heading": "RESCUE THE TRAVELER • Turn %d / 3" % mini(int(state.turn) + 1, 3), "meter": "Warmth: %d / 9 • 6+ rescues • 3–5 helps" % state.value, "maximum": 9, "instruction": "Summon a NOUN each turn. You have 3 turns: reach 6 warmth for 6 HP; 3–5 warmth grants 3 HP.", "preview": hint, "choices": [], "submit": "Summon"}

static func play(state: Dictionary, word: String, _choice: int) -> void:
	var effect: Dictionary = supply(word)
	state.value = mini(9, int(state.value) + int(effect.gain))
	state.turn += 1
	state.words.append(word)
	state.feedback = "You summon %s. +%d warmth. %s" % [word, effect.gain, effect.reaction]
	state.awaiting_next = not is_finished(state)

static func is_finished(state: Dictionary) -> bool:
	return int(state.turn) >= 3

static func outcome(state: Dictionary) -> Dictionary:
	var rescued: bool = int(state.value) >= 6
	return {"type": "heal", "amount": 6 if rescued else (3 if int(state.value) >= 3 else 0), "dialogue": "Traveler rescued! Winter has filed a formal complaint." if rescued else "The traveler is warmer and heads for the inn. 'Next time, I pack actual luggage.'"}
