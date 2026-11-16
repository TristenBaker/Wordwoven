class_name LetterStats
extends Resource
const Balance = preload("res://data/balance/tuning.gd")
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

const VOWELS: String = preload("res://data/balance/tuning.gd").LETTER_STATS_VOWELS
const COMMON_CONSONANTS: String = preload("res://data/balance/tuning.gd").LETTER_STATS_COMMON_CONSONANTS
const UNCOMMON_CONSONANTS: String = preload("res://data/balance/tuning.gd").LETTER_STATS_UNCOMMON_CONSONANTS

# Scrabble-style base power for each letter.
const BASE_POWER: Dictionary[String, int] = preload("res://data/balance/tuning.gd").LETTER_STATS_BASE_POWER

# Additional power multiplier gained per level past 1.
const LEVEL_POWER_STEP: float = preload("res://data/balance/tuning.gd").LETTER_STATS_LEVEL_POWER_STEP

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
	level += Balance.LETTER_LEVELS_PER_USE


## Power this letter contributes when used in a word.
func power() -> float:
	var base: int = BASE_POWER.get(letter, 1)
	var level_bonus: float = 1.0 + LEVEL_POWER_STEP * float(level - 1)
	var amount: float = float(base) * level_bonus
	if modifier == Modifier.HEAVY:
		amount += Balance.HEAVY_POWER
	if modifier == Modifier.KEEN:
		amount *= Balance.KEEN_MULTIPLIER
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
	var base: int = BASE_POWER.get(letter, 1)
	var level_multiplier: float = 1.0 + LEVEL_POWER_STEP * float(level - 1)
	var element_multiplier := DamageCalculator.elemental_potency_multiplier(
		element_name_text().to_lower()
	)
	var text := "Damage: %d base × %.2f level × %.2f active elemental potency = %.1f %s per use." % [
		base, level_multiplier, element_multiplier,
		power() * element_multiplier, element_name_text(),
	]
	text += " Before word bonuses and enemy affinity."
	if modifier == Modifier.HEAVY:
		text += " Heavy adds +4 before elemental effects."
	elif modifier == Modifier.KEEN:
		text += " Keen doubles the final tile contribution."
	return text


func element_detail_text() -> String:
	var powers := RelicSystem.new()
	var contribution := power() * DamageCalculator.elemental_potency_multiplier(
		element_name_text().to_lower(), powers
	)
	var effects := DamageCalculator.elemental_secondary_effects(
		{element_name_text().to_lower(): contribution}, powers
	)
	match element:
		Element.FIRE:
			return "Burn: %d damage on the next enemy turn (%.0f%% of Fire damage; minimum 1)." % [
				effects.fire_burn, powers.total_effect("fire_burn_ratio") * 100.0,
			]
		Element.LIGHTNING:
			var echo := DamageCalculator.lightning_echo_parameters(powers)
			return "Echo: %.0f%% chance for an extra hit at %.0f%% damage (%.1f here). Each echo can echo again, up to %d times." % [
				echo.chance * 100.0, echo.damage_ratio * 100.0,
				contribution * echo.damage_ratio, Balance.LIGHTNING_MAX_PROCS,
			]
		Element.WATER:
			return "Mend: restore %d health (%.0f%% of Water damage; minimum 1)." % [
				effects.water_heal, powers.total_effect("water_heal_ratio") * 100.0,
			]
		Element.ICE:
			return "Chill: reduce next retaliation by %d (%.0f%% of Ice damage + %d from upgrades; minimum 1)." % [
				effects.ice_slow, powers.total_effect("ice_retaliation_ratio") * 100.0,
				int(powers.total_effect("ice_retaliation_reduction")),
			]
		Element.NATURE:
			return "Poison: %d damage on the next enemy turn (%.0f%% of Nature damage; minimum 1)." % [
				effects.nature_poison, powers.total_effect("nature_poison_ratio") * 100.0,
			]
		Element.EARTH:
			return "Guard: absorb %d damage from next retaliation (%.0f%% of Earth damage + %d from upgrades; minimum 1)." % [
				effects.earth_guard, powers.total_effect("earth_guard_ratio") * 100.0,
				int(powers.total_effect("earth_guard")),
			]
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
