class_name LetterStats
extends Resource
## A letter in the party. Its alphabet category determines its role,
## and each accepted use from the hand raises its level.

## Every letter has one fixed combat role.
enum LetterClass {
	HEALER,
	WARRIOR,
	ROGUE,
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
@export var letter_class: LetterClass = LetterClass.HEALER
@export var modifier: Modifier = Modifier.NONE


static func create(new_letter: String) -> LetterStats:
	var stats: LetterStats = LetterStats.new()
	stats.letter = new_letter.to_lower()
	if VOWELS.contains(stats.letter):
		stats.letter_class = LetterClass.HEALER
	elif COMMON_CONSONANTS.contains(stats.letter):
		stats.letter_class = LetterClass.WARRIOR
	else:
		stats.letter_class = LetterClass.ROGUE
	return stats


## Called once after this letter resolves an accepted use.
func gain_use_level() -> void:
	level += 1


## Power this letter contributes when used in a word.
func power() -> float:
	var base: int = BASE_POWER.get(letter, 1)
	var level_bonus: float = 1.0 + LEVEL_POWER_STEP * float(level - 1)
	var amount: float = float(base) * level_bonus
	if letter_class == LetterClass.WARRIOR:
		amount += 2.0 * float(level)
	if modifier == Modifier.HEAVY:
		amount += 4.0
	if modifier == Modifier.KEEN:
		amount *= 2.0
	return amount


## Short label such as "R Lv2 Warrior" for tooltips and shops.
func describe() -> String:
	var text: String = "%s Lv%d %s" % [
		letter.to_upper(), level, class_name_text()
	]
	if modifier != Modifier.NONE:
		text += " [" + modifier_name_text() + "]"
	return text


func category_name_text() -> String:
	match letter_class:
		LetterClass.HEALER:
			return "Vowel"
		LetterClass.WARRIOR:
			return "Common consonant"
	return "Uncommon consonant"


func effect_text() -> String:
	match letter_class:
		LetterClass.HEALER:
			return "Heals %d health on use" % level
		LetterClass.WARRIOR:
			return "Adds %d attack power on use" % (2 * level)
	return "Earns %d gold on use" % (2 * level)


func class_name_text() -> String:
	return LetterClass.keys()[letter_class].capitalize()


func modifier_name_text() -> String:
	return Modifier.keys()[modifier].capitalize()
