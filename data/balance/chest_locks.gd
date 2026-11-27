extends RefCounted
const Balance = preload("res://data/balance/tuning.gd")
## Authored answers first, then adjective-only WordNet synonym/meaning links.
const LOCKS: Array[Dictionary] = [
	{"name": "Hearth", "clue": "This lock longs for comfort after a night in the snow.", "hint": "Consider how a traveler would feel beside a hearth after escaping a blizzard.", "anchors": ["warm", "hot"], "accepted": ["warm", "hot", "heated", "snug", "cozy", "cosy"], "success": "The Hearth lock gives a grateful crackle."},
	{"name": "Lion", "clue": "This lock admires a heart that stands firm when danger approaches.", "hint": "Think of a person who faces a dragon instead of fleeing.", "anchors": ["brave", "courageous"], "accepted": ["brave", "courageous", "fearless", "bold", "heroic", "daring"], "success": "The Lion lock roars its approval."},
	{"name": "Library", "clue": "This lock guards a place where even a whisper earns a librarian's glare.", "hint": "Imagine a reading room where footsteps and whispers are unwelcome.", "anchors": ["quiet", "silent"], "accepted": ["quiet", "silent", "hushed", "noiseless", "soundless", "peaceful"], "success": "The Library lock opens with a very proper whisper."},
	{"name": "Sun", "clue": "This lock celebrates the glow that chases shadows from a hall.", "hint": "Think of how a room looks when sunlight pours through its windows.", "anchors": ["bright", "luminous"], "accepted": ["bright", "luminous", "radiant", "shining", "brilliant", "glowing"], "success": "The Sun lock flashes a golden grin."},
	{"name": "Giant", "clue": "This lock admires those whose strength could move mountains.", "hint": "Think of the ability to lift great weights, rather than size alone.", "anchors": ["strong", "powerful"], "accepted": ["strong", "powerful", "mighty", "muscular", "sturdy", "robust"], "success": "The Giant lock yields. Even mountains have their limits."},
	{"name": "Hourglass",
		"clue": "This lock has been waiting centuries for its tea to brew.",
		"hint": "Think of someone who can sit through an hour of delays without complaining.",
		"anchors": ["patient"], "accepted": ["patient", "forbearing"],
		"success": "The Hourglass lock opens. It knew you would get there."},
	{"name": "Lantern",
		"clue": "This lock wants to know why the wizard keeps a beetle in a jar.",
		"hint": "Think of someone who keeps asking questions because they want to learn.",
		"anchors": ["curious"], "accepted": ["curious", "inquisitive"],
		"success": "The Lantern lock opens, then asks how you did it."},
	{"name": "Breadbasket",
		"clue": "This lock admires an innkeeper who feeds an entire guild for the price of one pie.",
		"hint": "Think of someone who gives freely, even when there is nothing to gain.",
		"anchors": ["generous"], "accepted": ["generous", "charitable"],
		"success": "The Breadbasket lock opens and offers you seconds."},
	{"name": "Dragon Hoard",
		"clue": "This lock has a dragon embossed on it. The dragon counts its coins before and after every visit.",
		"hint": "Think of someone who wants more treasure than they need and refuses to share.",
		"anchors": ["greedy"], "accepted": ["greedy", "avaricious"],
		"success": "The Dragon Hoard lock opens and asks for a receipt."},
	{"name": "Iron Mule",
		"clue": "This lock won't budge, even after three wizards agree it should.",
		"hint": "Describe someone who refuses to change their mind despite good advice.",
		"anchors": ["stubborn"], "accepted": ["stubborn", "obstinate"],
		"success": "The Iron Mule lock opens, but insists it was its idea."},
	{"name": "Compass",
		"clue": "This lock salutes a squire who stands by their knight even after a spectacular defeat.",
		"hint": "Describe someone who stays devoted to a friend through trouble.",
		"anchors": ["loyal"], "accepted": ["loyal", "faithful"],
		"success": "The Compass lock opens. It knew you'd come back."},
	{"name": "Hedgehog",
		"clue": "This lock pictures a beast that curls up whenever a stranger walks past.",
		"hint": "Describe a person who hesitates to speak when meeting unfamiliar people.",
		"anchors": ["shy"], "accepted": ["shy", "timid"],
		"success": "The Hedgehog lock opens just enough to peek out."},
	{"name": "Bell Tower",
		"clue": "This lock rings whenever a messenger brings good news.",
		"hint": "Think of someone in good spirits who greets the whole village with a smile.",
		"anchors": ["cheerful"], "accepted": ["cheerful", "jovial"],
		"success": "The Bell Tower lock opens with a merry chime."},
	{"name": "Gravestone",
		"clue": "This lock was forged on a day when even the tavern fiddle went unplayed.",
		"hint": "Describe a place that seems sad and dispiriting, as though nobody wants to celebrate.",
		"anchors": ["gloomy"], "accepted": ["gloomy", "dismal"],
		"success": "The Gravestone lock sighs theatrically and opens."},
	{"name": "Thunderhead",
		"clue": "This lock depicts a wizard whose robes were set on fire by an apprentice.",
		"hint": "Describe how the wizard feels when the joke goes so far that they lose their temper.",
		"anchors": ["furious"], "accepted": ["furious", "enraged"],
		"success": "The Thunderhead lock opens before it says something regrettable."},
	{"name": "Green Crown",
		"clue": "This lock stares at the crown that was given to the knight in the next village.",
		"hint": "Describe someone who resents a neighbor for having something they wish they had.",
		"anchors": ["envious"], "accepted": ["envious", "jealous"],
		"success": "The Green Crown lock opens. It wanted a nicer key."},
	{"name": "Harbor",
		"clue": "This lock was forged at a harbor where not a single wave disturbed the boats.",
		"hint": "Describe water at rest, with no wind or waves to disturb it.",
		"anchors": ["calm"], "accepted": ["calm", "placid"],
		"success": "The Harbor lock opens without a ripple."},
	{"name": "Earthen Cup",
		"clue": "This lock guards a vessel that has survived only because nobody touches it.",
		"hint": "Describe an object that could break or crack from a very slight blow.",
		"anchors": ["fragile"], "accepted": ["fragile", "delicate"],
		"success": "The Earthen Cup lock opens in one piece."},
	{"name": "Anchor",
		"clue": "This lock asks why the giant had to help lift it onto the ship.",
		"hint": "Describe a thing that takes great effort to lift because of its weight.",
		"anchors": ["heavy"], "accepted": ["heavy", "weighty"],
		"success": "The Anchor lock opens. Lifting it is still your problem."},
	{"name": "Needle",
		"clue": "This lock has a point that can pierce a dragon's hide.",
		"hint": "Describe a blade whose edge cuts with very little pressure.",
		"anchors": ["sharp"], "accepted": ["sharp", "keen"],
		"success": "The Needle lock clicks open with surgical precision."},
	{"name": "Millstone",
		"clue": "This lock remembers a boulder that tore every sack dragged across it.",
		"hint": "Describe a surface full of bumps and ridges that scrape your skin.",
		"anchors": ["rough"], "accepted": ["rough", "coarse"],
		"success": "The Millstone lock grinds its way open."},
	{"name": "Moth Wing",
		"clue": "This lock belongs to a cloak that disappears when held up to the light.",
		"hint": "Describe glass you can see through clearly, with no haze blocking the view.",
		"anchors": ["transparent"], "accepted": ["transparent", "clear"],
		"success": "The Moth Wing lock opens. It has nothing to hide."},
	{"name": "Marsh",
		"clue": "This lock spent the spring buried beside a leaking boat.",
		"hint": "Describe cloth that feels wet to the touch but isn't dripping.",
		"anchors": ["damp"], "accepted": ["damp", "moist"],
		"success": "The Marsh lock opens with an embarrassed squelch."},
	{"name": "Skylark",
		"clue": "This lock remembers a day when the mountains vanished behind a white veil.",
		"hint": "Describe weather in which suspended droplets make distant things hard to see.",
		"anchors": ["foggy"], "accepted": ["foggy", "misty"],
		"success": "The Skylark lock opens. The view improves immediately."},
	{"name": "Turnip",
		"clue": "This lock belongs to a kingdom that bottles rain in tiny jars.",
		"hint": "Describe land that gets little rain and dries out for much of the year.",
		"anchors": ["arid"], "accepted": ["arid", "dry"],
		"success": "The Turnip lock opens and asks for a watering can."},
	{"name": "Cinder",
		"clue": "This lock has never forgiven the cook who forgot the stew on the fire.",
		"hint": "Describe food that has turned black from being left over a flame too long.",
		"anchors": ["burnt"], "accepted": ["burnt", "burned"],
		"success": "The Cinder lock opens. Dinner is beyond saving."},
	{"name": "Echo",
		"clue": "This lock clangs so hard that the innkeeper has banned it from the common room.",
		"hint": "Describe a sound that reaches every corner of a room and is hard to ignore.",
		"anchors": ["loud"], "accepted": ["loud", "noisy"],
		"success": "The Echo lock opens. The whole keep hears it."},
	{"name": "Cobweb",
		"clue": "This lock remembers a dynasty whose palace has long since crumbled into dust.",
		"hint": "Describe a relic from a very distant age, long before anyone alive was born.",
		"anchors": ["ancient"], "accepted": ["ancient", "old"],
		"success": "The Cobweb lock opens. It has been waiting for ages."},
	{"name": "Sandpiper",
		"clue": "This lock was a gift for a courier who could race the wind and win.",
		"hint": "Describe someone who can move from one place to another in very little time.",
		"anchors": ["swift"], "accepted": ["swift", "rapid"],
		"success": "The Sandpiper lock opens before you hear it click."},
	{"name": "Lemon Tart",
		"clue": "This lock wears the same face as a goblin tasting a lemon for the first time.",
		"hint": "Describe the taste that makes your mouth pucker when you bite into a lemon.",
		"anchors": ["sour"], "accepted": ["sour", "acidic"],
		"success": "The Lemon Tart lock opens with a puckered squeak."},
]

## The shuffled draw pile lives for this app session, across runs and scene changes.
static var _remaining_locks: Array[int] = []


static func initial_state() -> Dictionary:
	if _remaining_locks.is_empty():
		for index in LOCKS.size():
			_remaining_locks.append(index)
		_remaining_locks.shuffle()
	var locks: Array[Dictionary] = []
	for _slot in 3:
		locks.append(LOCKS[_remaining_locks.pop_back()].duplicate(true))
	return {"turn": 0, "value": 0, "lock_index": 0, "guesses": 0, "locks": locks, "statuses": ["sealed", "sealed", "sealed"], "words": [], "feedback": "Three opinionated locks. Two valid guesses per lock; each opened lock earns %d gold." % Balance.CHEST_GOLD_PER_LOCK, "awaiting_next": false}


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
	var hints: String = "Use an ADJECTIVE. Synonyms welcome. Each opened lock earns %d gold; invalid words cost no guesses." % Balance.CHEST_GOLD_PER_LOCK
	if int(state.guesses) > 0: hints += " " + String(lock.hint)
	var remaining: int = 2 - int(state.guesses)
	return {"heading": "CRACK THE LOCKS • Lock %d / 3" % mini(int(state.lock_index) + 1, 3), "meter": "Opened: %d / 3 • Gold earned: %d" % [state.value, int(state.value) * Balance.CHEST_GOLD_PER_LOCK], "maximum": 3, "instruction": "%s lock: %s" % [lock.name, lock.clue], "preview": "%d %s remaining. %s" % [remaining, "guess" if remaining == 1 else "guesses", hints], "choices": [], "submit": "Unlock"}

static func play(state: Dictionary, word: String, _choice: int) -> void:
	var index: int = int(state.lock_index)
	var lock: Dictionary = state.locks[index]
	state.turn += 1
	state.words.append(word)
	if accepts(word, lock):
		state.value += 1
		state.statuses[index] = "open"
		state.feedback = "'%s' fits! %s +%d gold at the end." % [word, lock.get("success", "The %s lock clicks open." % lock.name), Balance.CHEST_GOLD_PER_LOCK]
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
	return {"type": "gold", "amount": int(state.value) * Balance.CHEST_GOLD_PER_LOCK, "bonus_chance": Balance.CHEST_BONUS_CHANCE if int(state.value) == 3 else 0.0, "dialogue": "Opened %d of 3 locks. %s" % [state.value, "The chest tips you for the excellent vocabulary." if int(state.value) == 3 else "The chest releases the accessible coins. 'My other compartments are on lunch break.'"]}
