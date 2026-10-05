class_name LetterStats
extends Resource
## A letter in the party. Its element determines the damage it contributes,
## and each accepted use from the hand raises its level.

## Every letter has one fixed elemental attunement.
enum Element {
	FIRE,
	LIGHTNING,
	WATER,
	ICE,
	NATURE,
	EARTH,
}

## Existing modifier data remains compatible with the damage rules.
enum Modifier {
	NONE,
	## Doubles this letter's power contribution.
	KEEN,
	## Earns 1 gold when drawn into the hand.
	GILDED,
	## Adds flat bonus power on every use.
	HEAVY,
}

const VOWELS: String = "aeiou"
const COMMON_CONSONANTS: String = "bcdfghlmnprst"
const UNCOMMON_CONSONANTS: String = "jkqvwxyz"

# Scrabble-style base power for each letter.
const BASE_POWER: Dictionary[String, int] = {
	"a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2,
	"h": 4, "i": 1, "j": 8, "k": 5, "l": 1, "m": 3, "n": 1,
	"o": 1, "p": 3, "q": 10, "r": 1, "s": 1, "t": 1, "u": 1,
	"v": 4, "w": 4, "x": 8, "y": 4, "z": 10,
}

# Additional power multiplier gained per level past 1.
const LEVEL_POWER_STEP: float = 0.25

@export var letter: String = "a"
@export var level: int = 1
@export var element: Element = Element.FIRE
@export var modifier: Modifier = Modifier.NONE


static func create(new_letter: String) -> LetterStats:
	var stats: LetterStats = LetterStats.new()
	stats.letter = new_letter.to_lower()
	if VOWELS.contains(stats.letter):
		stats.element = Element.WATER
	elif COMMON_CONSONANTS.contains(stats.letter):
		stats.element = Element.FIRE
	else:
		stats.element = Element.LIGHTNING
	return stats


## Creates an itemized letter. Unlike legacy deck letters, both element and
## level are explicit item properties and do not need to follow its alphabet
## category.
static func create_item(
	new_letter: String, new_element: int, new_level: int = 1
) -> LetterStats:
	var stats: LetterStats = LetterStats.create(new_letter)
	stats.element = new_element as Element
	stats.level = maxi(1, new_level)
	return stats


## Called once after this letter resolves an accepted use.
func gain_use_level() -> void:
	level += 1


## Power this letter contributes when used in a word.
func power() -> float:
	var base: int = BASE_POWER.get(letter, 1)
	var level_bonus: float = 1.0 + LEVEL_POWER_STEP * float(level - 1)
	var amount: float = float(base) * level_bonus
	if modifier == Modifier.HEAVY:
		amount += 4.0
	if modifier == Modifier.KEEN:
		amount *= 2.0
	return amount


## Short label such as "R Lv2 Fire" for tooltips and shops.
func describe() -> String:
	var text: String = "%s Lv%d %s" % [
		letter.to_upper(), level, element_name_text()
	]
	if modifier != Modifier.NONE:
		text += " [" + modifier_name_text() + "]"
	return text


func element_name_text() -> String:
	return Element.keys()[element].capitalize()


func effect_text() -> String:
	return "%s damage" % element_name_text()


func throughput_text() -> String:
	return "Base contribution: %.1f %s damage per use." % [
		power(), element_name_text()
	]


func element_detail_text() -> String:
	match element:
		Element.FIRE:
			return "Fire damage can ignite enemies through Burn powers."
		Element.LIGHTNING:
			return "Lightning damage can chain into recursive echoes."
		Element.WATER:
			return "Water damage can restore health through Water powers."
		Element.ICE:
			return "Ice damage can weaken the next enemy retaliation."
		Element.NATURE:
			return "Nature damage can poison enemies through Nature powers."
		Element.EARTH:
			return "Earth damage can grant Guard against retaliation."
	return "Elemental damage shaped by your selected powers."


func information_tooltip() -> String:
	var lines: Array[String] = [
		letter.to_upper(),
		element_name_text().to_upper(),
		"Level: %d" % level,
		"",
		element_detail_text(),
		throughput_text(),
		"",
		"Affected by powers:",
	]
	var power_system: RelicSystem = RelicSystem.new()
	var power_ids: Array[String] = power_system.affecting_power_ids(element)
	if power_ids.is_empty():
		lines.append("• None selected yet")
	else:
		for power_id: String in power_ids:
			var info: Dictionary = power_system.relic_info(power_id)
			lines.append("• %s ×%d" % [
				info.get("name", power_id), RunState.relics.count(power_id)
			])
	return "\n".join(lines)


func modifier_name_text() -> String:
	return Modifier.keys()[modifier].capitalize()
