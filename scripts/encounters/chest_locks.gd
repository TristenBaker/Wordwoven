extends RefCounted
## Authored answers first, then adjective-only WordNet synonym/meaning links.
const LOCKS: Array[Dictionary] = [
	{"name": "Hearth", "clue": "This lock longs for comfort after a night in the snow.", "hint": "Consider how a traveler would feel beside a hearth after escaping a blizzard.", "anchors": ["warm", "hot"], "accepted": ["warm", "hot", "heated", "toasty", "cozy", "cosy"]},
	{"name": "Lion", "clue": "This lock admires a heart that stands firm when danger approaches.", "hint": "Think of a person who faces a dragon instead of fleeing.", "anchors": ["brave", "courageous"], "accepted": ["brave", "courageous", "fearless", "bold", "heroic", "daring"]},
	{"name": "Library", "clue": "This lock guards a place where even a whisper earns a librarian's glare.", "hint": "Imagine a reading room where footsteps and whispers are unwelcome.", "anchors": ["quiet", "silent"], "accepted": ["quiet", "silent", "hushed", "noiseless", "soundless", "peaceful"]},
	{"name": "Sun", "clue": "This lock celebrates the glow that chases shadows from a hall.", "hint": "Think of how a room looks when sunlight pours through its windows.", "anchors": ["bright", "luminous"], "accepted": ["bright", "luminous", "radiant", "shining", "brilliant", "glowing"]},
	{"name": "Giant", "clue": "This lock admires those whose strength could move mountains.", "hint": "Think of the ability to lift great weights, rather than size alone.", "anchors": ["strong", "powerful"], "accepted": ["strong", "powerful", "mighty", "muscular", "sturdy", "robust"]},
]

static func initial_state() -> Dictionary:
	var pool: Array = LOCKS.duplicate(true)
	pool.shuffle()
	return {"turn": 0, "value": 0, "lock_index": 0, "guesses": 0, "locks": pool.slice(0, 3), "statuses": ["sealed", "sealed", "sealed"], "words": [], "feedback": "Three opinionated locks. Two valid guesses per lock; each opened lock earns 4 gold.", "awaiting_next": false}

static func accepts(word: String, lock: Dictionary) -> bool:
	if lock.accepted.has(word): return true
	if not WordNet.is_ready: return false
	var relations: Dictionary = WordNet.adjective_relations(word)
	for anchor: String in lock.anchors:
		var target: Dictionary = WordNet.adjective_relations(anchor)
		for synset: int in relations.synsets:
			if target.synsets.has(synset) or target.similar.has(synset): return true
		for synset: int in relations.similar:
			if target.synsets.has(synset): return true
	return false

static func presentation(state: Dictionary, _word: String = "") -> Dictionary:
	var lock: Dictionary = state.locks[mini(int(state.lock_index), 2)]
	var hints: String = "Use an ADJECTIVE. Synonyms welcome. Each opened lock earns 4 gold; invalid words cost no guesses."
	if int(state.guesses) > 0: hints += " " + String(lock.hint)
	var remaining: int = 2 - int(state.guesses)
	return {"heading": "CRACK THE LOCKS • Lock %d / 3" % mini(int(state.lock_index) + 1, 3), "meter": "Opened: %d / 3 • Gold earned: %d" % [state.value, int(state.value) * 4], "maximum": 3, "instruction": "%s lock: %s" % [lock.name, lock.clue], "preview": "%d %s remaining. %s" % [remaining, "guess" if remaining == 1 else "guesses", hints], "choices": [], "submit": "Unlock"}

static func play(state: Dictionary, word: String, _choice: int) -> void:
	var index: int = int(state.lock_index)
	var lock: Dictionary = state.locks[index]
	state.turn += 1
	state.words.append(word)
	if accepts(word, lock):
		state.value += 1
		state.statuses[index] = "open"
		state.feedback = "'%s' fits! The %s lock clicks open. 'Finally, someone who reads the instructions.' +4 gold at the end." % [word, lock.name]
		state.lock_index += 1
		state.guesses = 0
	else:
		state.guesses += 1
		state.feedback = "'%s' doesn't fit the %s clue. 'Lovely adjective. Wrong department.' %s" % [word, lock.name, lock.hint]
		if int(state.guesses) >= 2:
			state.statuses[index] = "stuck"
			state.feedback += " This lock stays shut; try the next one."
			state.lock_index += 1
			state.guesses = 0
	state.awaiting_next = not is_finished(state)

static func is_finished(state: Dictionary) -> bool:
	return int(state.lock_index) >= 3

static func outcome(state: Dictionary) -> Dictionary:
	return {"type": "gold", "amount": int(state.value) * 4, "dialogue": "Opened %d of 3 locks. %s" % [state.value, "The chest tips you for the excellent vocabulary." if int(state.value) == 3 else "The chest releases the accessible coins. 'My other compartments are on lunch break.'"]}
