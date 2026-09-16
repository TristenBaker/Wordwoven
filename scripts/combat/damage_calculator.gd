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
## the remaining characters. The optional context may carry
## "conditions" (EncounterConditions) and "speed_bonus" (bool).
## Returns the breakdown dictionary.
func calculate(
	word: String,
	drawn: Array[LetterStats],
	undrawn: Array[String],
	enemy_tags: Array[String],
	required_pos: String = "",
	context: Dictionary = {}
) -> Dictionary:
	var conditions: EncounterConditions = context.get("conditions")
	var letter_rows: Array[Dictionary] = []
	var level_eligible: Array[LetterStats] = []
	var base_power: float = 0.0
	var healing: float = 0.0
	var gold: float = 0.0
	var frozen_count: int = 0
	var poisoned_count: int = 0
	for stats: LetterStats in drawn:
		var frozen: bool = conditions != null \
				and conditions.is_frozen(stats)
		var poisoned: bool = conditions != null \
				and conditions.is_poisoned(stats)
		var factor: float = EncounterConditions.POISON_FACTOR \
				if poisoned else 1.0
		var contribution: float = 0.0
		if frozen:
			# Frozen tiles fall back to the default-letter contribution.
			contribution = _default_letter_power(stats.letter) * factor
			frozen_count += 1
		else:
			contribution = stats.power() * factor
			healing += _healer_health(stats) * factor
			gold += _rogue_gold(stats) * factor
			level_eligible.append(stats)
		if poisoned:
			poisoned_count += 1
		base_power += contribution
		letter_rows.append({
			"letter": stats.letter,
			"drawn": true,
			"power": contribution,
			"level": stats.level,
			"stats": stats,
			"frozen": frozen,
			"poisoned": poisoned,
		})
	for character: String in undrawn:
		var contribution: float = _default_letter_power(character)
		base_power += contribution
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
	var speed_bonus: bool = bool(context.get("speed_bonus", false))
	var speed_multiplier: float = SpeedTimer.DAMAGE_MULTIPLIER \
			if speed_bonus else 1.0
	var damage: float = base_power * length_multiplier \
			* pos_data["multiplier"] * semantic_multiplier \
			* speed_multiplier
	return {
		"word": word,
		"damage": damage,
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
		# Fractional poisoned contributions round down once per word.
		"gold_bonus": int(floor(gold)),
		"heal_amount": int(floor(healing)),
		"speed_bonus": speed_bonus,
		"speed_multiplier": speed_multiplier,
		"frozen_count": frozen_count,
		"poisoned_count": poisoned_count,
		# Only these instances gain a level once the word resolves.
		"level_eligible": level_eligible,
	}


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


func _default_letter_power(character: String) -> float:
	var base: int = LetterStats.BASE_POWER.get(character, 1)
	return float(base) * UNDRAWN_POWER_FACTOR


func _rogue_gold(stats: LetterStats) -> float:
	if stats.letter_class == LetterStats.LetterClass.ROGUE:
		return 2.0 * float(stats.level)
	return 0.0


func _healer_health(stats: LetterStats) -> float:
	if stats.letter_class == LetterStats.LetterClass.HEALER:
		return float(stats.level)
	return 0.0
