extends RefCounted
## Small encounter-only catalogue; never mutates definitions or deck resources.
const ENTRIES: Array[Dictionary] = [
	{"id": "titanbound", "name": "TITANBOUND", "effect": "Enemy Max HP +15%", "flavor": "Your word binds the creature with unnatural endurance.", "stat": "health", "factor": 1.15, "beneficial": false},
	{"id": "doommarked", "name": "DOOMMARKED", "effect": "Enemy Max HP -15%", "flavor": "The tale has already begun to write its ending.", "stat": "health", "factor": 0.85, "beneficial": true},
	{"id": "war_blessed", "name": "WAR-BLESSED", "effect": "Enemy Damage +15%", "flavor": "The creature enters battle touched by the fury of war.", "stat": "attack", "factor": 1.15, "beneficial": false},
	{"id": "spirit_broken", "name": "SPIRIT-BROKEN", "effect": "Enemy Damage -15%", "flavor": "Its courage falters before the battle has begun.", "stat": "attack", "factor": 0.85, "beneficial": true},
	{"id": "fate_exposed", "name": "FATE-EXPOSED", "effect": "Player Damage +10%", "flavor": "Your words have revealed a weakness written into its fate.", "stat": "player_damage", "factor": 1.10, "beneficial": true},
	{"id": "spellwarden", "name": "SPELLWARDEN", "effect": "Player Damage -10%", "flavor": "Ancient wards twist your words before they can strike true.", "stat": "player_damage", "factor": 0.90, "beneficial": false},
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
