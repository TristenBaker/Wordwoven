class_name ModifierResolver
extends RefCounted
## Resolves one drawn letter instance: its level-scaled base power,
## its class effect, and each attached modifier in catalog order.
## Inspiration doubles drawn-letter power, healing, gold, and the
## numerical modifier effects marked "doubles"; leveling and
## recursive triggers (Echoing, Inspired) are never doubled.

const INSPIRED_FACTOR: float = 2.0


## situation keys: "inspired" (bool), "threaded" (bool), "wait_turns"
## (int), "class_allies" (int, other drawn letters of its class).
## Returns {"power", "healing", "gold", "counter_bonus",
## "inspiration", "effects": Array[Dictionary]}; each effect records
## {"id", "name", "instance", "power", "healing", "gold",
## "counter_bonus", "inspiration", "text"}.
static func resolve(
	stats: LetterStats, situation: Dictionary = {}
) -> Dictionary:
	var inspired: bool = bool(situation.get("inspired", false))
	var factor: float = INSPIRED_FACTOR if inspired else 1.0
	var class_power: float = stats.class_power() * factor
	var class_healing: float = stats.class_healing() * factor
	var class_gold: float = stats.class_gold() * factor
	var totals: Dictionary = {
		"power": stats.base_power() * factor + class_power,
		"healing": class_healing,
		"gold": class_gold,
		"counter_bonus": 0.0,
		"inspiration": 0,
		"effects": [],
	}
	var effects: Array[Dictionary] = []
	var ordered: Array[String] = ModifierCatalog.sorted_by_order(
		stats.modifier_ids()
	)
	for modifier_id: String in ordered:
		var info: Dictionary = ModifierCatalog.definition(modifier_id)
		if info.is_empty():
			continue
		var scale: float = factor if bool(info.get("doubles", true)) \
				else 1.0
		var amount: float = float(info.get("amount", 0)) * scale
		var effect: Dictionary = _empty_effect(stats, modifier_id)
		match String(info.get("effect", "")):
			"flat_power":
				effect["power"] = amount
			"power_per_class_ally":
				var allies: int = int(situation.get("class_allies", 0))
				effect["power"] = amount * float(allies)
			"power_per_wait":
				var waited: int = mini(
					int(situation.get("wait_turns", 0)),
					int(info.get("cap", 0))
				)
				effect["power"] = amount * float(waited)
			"power_when_threaded":
				if bool(situation.get("threaded", false)):
					effect["power"] = amount
			"power_percent":
				effect["power"] = float(totals["power"]) * amount
			"echo_class":
				effect["power"] = class_power
				effect["healing"] = class_healing
				effect["gold"] = class_gold
			"gold":
				effect["gold"] = amount
			"counter_bonus":
				effect["counter_bonus"] = amount
			"inspiration":
				effect["inspiration"] = int(amount)
		totals["power"] = float(totals["power"]) + effect["power"]
		totals["healing"] = float(totals["healing"]) + effect["healing"]
		totals["gold"] = float(totals["gold"]) + effect["gold"]
		totals["counter_bonus"] = float(totals["counter_bonus"]) \
				+ effect["counter_bonus"]
		totals["inspiration"] = int(totals["inspiration"]) \
				+ int(effect["inspiration"])
		effect["text"] = _effect_text(effect)
		effects.append(effect)
	totals["effects"] = effects
	return totals


## Scales an instance's resolved numbers, as poison does.
static func scaled(resolved: Dictionary, factor: float) -> Dictionary:
	var copy: Dictionary = resolved.duplicate(true)
	for key: String in ["power", "healing", "gold", "counter_bonus"]:
		copy[key] = float(copy[key]) * factor
	for effect: Dictionary in copy["effects"]:
		for key: String in ["power", "healing", "gold", "counter_bonus"]:
			effect[key] = float(effect[key]) * factor
		effect["text"] = _effect_text(effect)
	return copy


static func _empty_effect(
	stats: LetterStats, modifier_id: String
) -> Dictionary:
	return {
		"id": modifier_id,
		"name": ModifierCatalog.display_name(modifier_id),
		"instance": stats.tag_text(),
		"power": 0.0,
		"healing": 0.0,
		"gold": 0.0,
		"counter_bonus": 0.0,
		"inspiration": 0,
	}


# "Keen on P#12: +5.0 power" style summary of what the effect did.
static func _effect_text(effect: Dictionary) -> String:
	var parts: Array[String] = []
	if float(effect["power"]) > 0.0:
		parts.append("+%.1f power" % float(effect["power"]))
	if float(effect["healing"]) > 0.0:
		parts.append("+%.1f healing" % float(effect["healing"]))
	if float(effect["gold"]) > 0.0:
		parts.append("+%.1f gold" % float(effect["gold"]))
	if float(effect["counter_bonus"]) > 0.0:
		parts.append("+%.2f counter" % float(effect["counter_bonus"]))
	if int(effect["inspiration"]) > 0:
		parts.append("+%d Inspiration" % int(effect["inspiration"]))
	if parts.is_empty():
		parts.append("no effect this cast")
	return "%s on %s: %s" % [
		effect["name"], effect["instance"], ", ".join(parts),
	]
