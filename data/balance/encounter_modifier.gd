extends RefCounted
## Small encounter-only catalogue; never mutates definitions or deck resources.
const ENTRIES: Array[Dictionary] = [
	{"id": "titanbound", "name": "TITANBOUND", "effect": "Enemy Max HP +15%", "flavor": "Your word binds the creature with unnatural endurance.", "stat": "health", "factor": 1.15, "beneficial": false},
	{"id": "doommarked", "name": "DOOMMARKED", "effect": "Enemy Max HP -15%", "flavor": "The tale has already begun to write its ending.", "stat": "health", "factor": 0.85, "beneficial": true},
	{"id": "war_blessed", "name": "WAR-BLESSED", "effect": "Enemy Damage +15%", "flavor": "The creature enters battle touched by the fury of war.", "stat": "attack", "factor": 1.15, "beneficial": false},
	{"id": "spirit_broken", "name": "SPIRIT-BROKEN", "effect": "Enemy Damage -15%", "flavor": "Its courage falters before the battle has begun.", "stat": "attack", "factor": 0.85, "beneficial": true},
	{"id": "fate_exposed", "name": "FATE-EXPOSED", "effect": "Player Damage +10%", "flavor": "Your words have revealed a weakness written into its fate.", "stat": "player_damage", "factor": 1.10, "beneficial": true},
	{"id": "spellwarden", "name": "SPELLWARDEN", "effect": "Player Damage -10%", "flavor": "Ancient wards twist your words before they can strike true.", "stat": "player_damage", "factor": 0.90, "beneficial": false},
	{"id": "drowsy", "name": "DROWSY", "effect": "Sleep / attack; awake +25%", "flavor": "The foe has scheduled this battle between naps.", "stat": "behavior", "factor": 1.0, "beneficial": false},
	{"id": "clumsy", "name": "CLUMSY", "effect": "Every 3rd attack hits itself", "flavor": "Your foe has two left feet and a very sharp weapon.", "stat": "behavior", "factor": 1.0, "beneficial": true},
	{"id": "long_winded", "name": "LONG-WINDED", "effect": "Long words +20%; short +2 Guard", "flavor": "The creature insists on a lengthy explanation.", "stat": "behavior", "factor": 1.0, "beneficial": true},
	{"id": "echo_bound", "name": "ECHO-BOUND", "effect": "Linked first letter: +25%", "flavor": "Your words echo through the creature’s unfortunate acoustics.", "stat": "behavior", "factor": 1.0, "beneficial": true},
	{"id": "chameleon", "name": "CHAMELEON", "effect": "Tags change every 2 attacks", "flavor": "The foe cannot decide what sort of menace to be.", "stat": "behavior", "factor": 1.0, "beneficial": false},
	{"id": "greedy", "name": "GREEDY", "effect": "Cast +1g; theft; victory +8g", "flavor": "The creature charges a handling fee for being handled.", "stat": "behavior", "factor": 1.0, "beneficial": true},
	{"id": "frostbite_tax", "name": "FROSTBITE TAX", "effect": "Freeze every 2; casts +2 Heat", "flavor": "Winter doubles its paperwork. At least the ink is warm.", "stat": "behavior", "factor": 1.0, "beneficial": false, "biome": "tundra"},
]

static func definition(id: String) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry.id == id:
			return entry.duplicate(true)
	return {}

static func apply_spawn(spawn: Dictionary, modifier: Dictionary) -> Dictionary:
	var adjusted: Dictionary = spawn.duplicate(true)
	var stat: String = modifier.get("stat", "")
	if stat in ["health", "attack"]:
		adjusted[stat] = maxi(1, int(round(float(adjusted[stat]) * float(modifier.factor))))
	return adjusted

static func player_factor(modifier: Dictionary) -> float:
	return float(modifier.factor) if modifier.get("stat", "") == "player_damage" else 1.0

static func eligible(modifier: Dictionary, biome: String) -> bool:
	return not modifier.has("biome") or modifier.biome == biome

static func eligible_entries(biome: String) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for entry: Dictionary in ENTRIES:
		if eligible(entry, biome): pool.append(entry)
	return pool
