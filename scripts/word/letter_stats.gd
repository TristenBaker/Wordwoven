class_name LetterStats
extends Resource
## A letter in the party. Its alphabet category determines its role,
## each accepted use from the hand raises its level, and it carries up
## to two modifiers. Every owned instance has a stable id for the run.

## Every letter has one fixed combat role.
enum LetterClass {
	HEALER,
	WARRIOR,
	ROGUE,
}

## Legacy single-modifier values, migrated into the modifier list.
enum Modifier {
	NONE,
	KEEN,
	GILDED,
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

const MAX_MODIFIERS: int = 2

# Modifier ids that legacy enum values become.
const LEGACY_MODIFIER_IDS: Dictionary[int, String] = {
	Modifier.KEEN: "keen",
	Modifier.GILDED: "gilded",
	Modifier.HEAVY: "heavy",
}

@export var letter: String = "a"
@export var level: int = 1
@export var letter_class: LetterClass = LetterClass.HEALER
## Legacy field; read once and folded into modifiers.
@export var modifier: Modifier = Modifier.NONE
## Stable run-wide identity; 0 for letters outside the party.
@export var instance_id: int = 0
## Modifier ids in attachment order, at most MAX_MODIFIERS.
@export var modifiers: Array[String] = []


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


## Base power scaled by level, before class effects and modifiers.
func base_power() -> float:
	var base: int = BASE_POWER.get(letter, 1)
	var level_bonus: float = 1.0 + LEVEL_POWER_STEP * float(level - 1)
	return float(base) * level_bonus


## The Warrior class effect: twice the level as attack power.
func class_power() -> float:
	if letter_class == LetterClass.WARRIOR:
		return 2.0 * float(level)
	return 0.0


## The Healer class effect: health equal to the level.
func class_healing() -> float:
	if letter_class == LetterClass.HEALER:
		return float(level)
	return 0.0


## The Rogue class effect: twice the level in gold.
func class_gold() -> float:
	if letter_class == LetterClass.ROGUE:
		return 2.0 * float(level)
	return 0.0


## Power this letter contributes with its class effect; modifiers are
## resolved separately by the damage calculator.
func power() -> float:
	return base_power() + class_power()


## Current modifier ids, migrating any legacy value first.
func modifier_ids() -> Array[String]:
	migrate_legacy_modifier()
	return modifiers.duplicate()


## Folds the legacy enum into the modifier list exactly once.
func migrate_legacy_modifier() -> void:
	if modifier == Modifier.NONE:
		return
	var legacy_id: String = LEGACY_MODIFIER_IDS.get(modifier, "")
	modifier = Modifier.NONE
	if legacy_id.is_empty() or modifiers.size() >= MAX_MODIFIERS:
		return
	modifiers.append(legacy_id)


func can_add_modifier() -> bool:
	migrate_legacy_modifier()
	return modifiers.size() < MAX_MODIFIERS


## Attaches a modifier; false when both slots are taken.
func add_modifier(modifier_id: String) -> bool:
	if modifier_id.is_empty() or not can_add_modifier():
		return false
	modifiers.append(modifier_id)
	return true


## Detaches the modifier in one slot and returns its id, or "".
func remove_modifier_at(slot: int) -> String:
	migrate_legacy_modifier()
	if slot < 0 or slot >= modifiers.size():
		return ""
	var removed: String = modifiers[slot]
	modifiers.remove_at(slot)
	return removed


## Short label such as "R Lv2 Warrior [Keen]" for tooltips and shops.
func describe() -> String:
	var text: String = "%s Lv%d %s" % [
		letter.to_upper(), level, class_name_text()
	]
	var names: Array[String] = []
	for modifier_id: String in modifier_ids():
		names.append(ModifierCatalog.display_name(modifier_id))
	if not names.is_empty():
		text += " [" + ", ".join(names) + "]"
	return text


## Letter and id, such as "R#12", naming one exact instance.
func tag_text() -> String:
	if instance_id <= 0:
		return letter.to_upper()
	return "%s#%d" % [letter.to_upper(), instance_id]


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


## Class effect followed by each modifier's exact effect.
func full_effect_text() -> String:
	var lines: Array[String] = [effect_text()]
	for modifier_id: String in modifier_ids():
		lines.append("%s: %s" % [
			ModifierCatalog.display_name(modifier_id),
			ModifierCatalog.describe(modifier_id),
		])
	return "\n".join(lines)


func class_name_text() -> String:
	return LetterClass.keys()[letter_class].capitalize()
