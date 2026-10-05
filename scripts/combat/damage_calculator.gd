class_name DamageCalculator
extends Node
## Turns a validated word into damage. Combines every factor the
## design calls for -- letter power (classes, modifiers, levels),
## drawn-versus-undrawn letters, word length, part of speech, and
## WordNet counters to the enemy's tags -- and returns
## a full breakdown so the debug overlay can show its work.

# Undrawn letters contribute only a sliver of their base power.
const UNDRAWN_POWER_FACTOR: float = 0.2

# Bonus multiplier per letter beyond a three-letter word.
const LENGTH_BONUS_STEP: float = 0.1

# Damage multiplier for the word's best part of speech.
const POS_MULTIPLIERS: Dictionary[String, float] = {
	"v": 1.25,
	"a": 1.15,
	"r": 1.1,
	"n": 1.0,
}

# Semantic multiplier range from no counter to a direct counter.
const SEMANTIC_MULTIPLIER_MIN: float = 0.5
const SEMANTIC_MULTIPLIER_MAX: float = 2.0

# Every Tome adds its bonus after counter scoring, without a cap.
const TOME_MULTIPLIER_BONUS: float = 0.12
const LANTERN_MULTIPLIER_BONUS: float = 0.08


## Scores a word against the enemy's tags.
## drawn holds the hand letters covering the word; undrawn holds
## the remaining characters. Returns the breakdown dictionary.
func calculate(
	word: String,
	drawn: Array[LetterStats],
	undrawn: Array[String],
	enemy_tags: Array[String],
	required_pos: String = "",
	affinities: Dictionary = {},
	roll_lightning: bool = false
) -> Dictionary:
	var letter_rows: Array[Dictionary] = []
	var base_power: float = 0.0
	var gold: int = 0
	var elemental_base: Dictionary = _empty_elemental_damage()
	var neutral_power: float = 0.0
	for stats: LetterStats in drawn:
		if stats.element in [LetterStats.Element.LIGHTNING, LetterStats.Element.ICE]:
			gold += 1
		var contribution: float = stats.power()
		base_power += contribution
		var element_name: String = stats.element_name_text().to_lower()
		elemental_base[element_name] += contribution
		letter_rows.append({
			"letter": stats.letter,
			"drawn": true,
			"power": contribution,
			"level": stats.level,
			"stats": stats,
		})
	for character: String in undrawn:
		var fallback: int = LetterStats.BASE_POWER.get(
			character, 1
		)
		var contribution: float = \
				float(fallback) * UNDRAWN_POWER_FACTOR
		base_power += contribution
		neutral_power += contribution
		letter_rows.append({
			"letter": character,
			"drawn": false,
			"power": contribution,
			"stats": null,
		})
	var length_multiplier: float = 1.0 + LENGTH_BONUS_STEP \
			* float(maxi(word.length() - 3, 0))
	var pos_data: Dictionary = _part_of_speech(word, required_pos)
	var counter: Dictionary = _best_tag_counter(
		word, enemy_tags, required_pos
	)
	var relic_system: RelicSystem = RelicSystem.new()
	var effectiveness: float = clampf(
		counter.get("score", 0.0)
		+ relic_system.total_effect("counter_bonus"), 0.0, 1.0
	)
	var semantic_multiplier: float = lerpf(
		SEMANTIC_MULTIPLIER_MIN,
		SEMANTIC_MULTIPLIER_MAX,
		effectiveness
	)
	semantic_multiplier += relic_system.total_effect("damage_multiplier")
	var word_multiplier: float = length_multiplier \
		* pos_data["multiplier"] * semantic_multiplier
	var elemental_damage: Dictionary = _apply_affinities(
		elemental_base, word_multiplier, affinities
	)
	var neutral_damage: float = neutral_power * word_multiplier
	var lightning_procs: int = 0
	var lightning_bonus: float = 0.0
	if roll_lightning:
		var lightning_data: Dictionary = _lightning_echo_damage(
			elemental_damage["lightning"]
		)
		lightning_procs = lightning_data["procs"]
		lightning_bonus = lightning_data["damage"]
		elemental_damage["lightning"] += lightning_bonus
	var damage: float = neutral_damage
	for amount: float in elemental_damage.values():
		damage += amount
	var water_heal: int = int(round(
		elemental_damage["water"] * relic_system.total_effect(
			"water_heal_ratio"
		)
	))
	var ice_slow: int = int(relic_system.total_effect(
		"ice_retaliation_reduction"
	)) if elemental_damage["ice"] > 0.0 else 0
	var earth_guard: int = int(relic_system.total_effect("earth_guard")) \
		if elemental_damage["earth"] > 0.0 else 0
	var nature_poison: float = elemental_damage["nature"] \
		* relic_system.total_effect("nature_poison_ratio")
	return {
		"word": word,
		"damage": damage,
		"gold": gold,
		"base_power": base_power,
		"letters": letter_rows,
		"drawn_count": drawn.size(),
		"undrawn_count": undrawn.size(),
		"length_multiplier": length_multiplier,
		"pos": pos_data["pos"],
		"pos_multiplier": pos_data["multiplier"],
		"counter": counter,
		# Preserve the breakdown key consumed by existing listeners.
		"similarity": counter,
		"effectiveness": effectiveness,
		"semantic_multiplier": semantic_multiplier,
		"elemental_damage": elemental_damage,
		"neutral_damage": neutral_damage,
		"lightning_procs": lightning_procs,
		"lightning_bonus": lightning_bonus,
		"water_heal": water_heal,
		"ice_slow": ice_slow,
		"earth_guard": earth_guard,
		"nature_poison": nature_poison,
	}


func _empty_elemental_damage() -> Dictionary:
	return {
		"fire": 0.0,
		"lightning": 0.0,
		"water": 0.0,
		"ice": 0.0,
		"nature": 0.0,
		"earth": 0.0,
	}


func _apply_affinities(
	base_damage: Dictionary, word_multiplier: float, affinities: Dictionary
) -> Dictionary:
	var damage: Dictionary = _empty_elemental_damage()
	var relic_system: RelicSystem = RelicSystem.new()
	for element_name: String in damage:
		var affinity: float = float(affinities.get(element_name, 1.0))
		var power_multiplier: float = 1.0 \
			+ relic_system.total_effect("all_element_damage_multiplier") \
			+ relic_system.total_effect(element_name + "_damage_multiplier")
		damage[element_name] = float(base_damage[element_name]) \
			* word_multiplier * affinity * power_multiplier
	return damage


func _lightning_echo_damage(lightning_damage: float) -> Dictionary:
	var relic_system: RelicSystem = RelicSystem.new()
	var chance: float = relic_system.total_effect("lightning_echo_chance")
	var damage_ratio: float = relic_system.total_effect(
		"lightning_echo_damage"
	)
	var procs: int = 0
	var bonus: float = 0.0
	while lightning_damage > 0.0 and chance > 0.0 \
			and procs < 6 and randf() < chance:
		procs += 1
		bonus += lightning_damage * damage_ratio
	return {"procs": procs, "damage": bonus}


# The prompt determines the multiplier; old callers keep best POS.
func _part_of_speech(
	word: String, required_pos: String
) -> Dictionary:
	if POS_MULTIPLIERS.has(required_pos):
		return {
			"pos": required_pos,
			"multiplier": POS_MULTIPLIERS[required_pos],
		}
	var best_pos: String = "n"
	var best_multiplier: float = 1.0
	for pos: String in WordNet.parts_of_speech(word):
		var multiplier: float = POS_MULTIPLIERS.get(pos, 1.0)
		if multiplier > best_multiplier:
			best_multiplier = multiplier
			best_pos = pos
	return {"pos": best_pos, "multiplier": best_multiplier}


# Scores the word against every tag and keeps the best counter.
func _best_tag_counter(
	word: String, enemy_tags: Array[String], required_pos: String
) -> Dictionary:
	var best: Dictionary = {
		"score": 0.0,
		"strategy": "none",
		"detail": "no tags",
		"tag": "",
	}
	for tag: String in enemy_tags:
		var result: Dictionary = WordNet.counter_detailed(
			word, tag, required_pos
		).duplicate()
		if result.get("score", 0.0) >= best.get("score", 0.0):
			result["tag"] = tag
			best = result
	return best
