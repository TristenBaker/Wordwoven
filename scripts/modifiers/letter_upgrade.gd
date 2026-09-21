class_name LetterUpgrade
extends RefCounted
## A previewable improvement to one letter instance: extra levels
## and optionally a modifier, as {"levels": int, "modifier": String}.
## Rewards and events show describe() before the player commits.


## Text such as "+2 levels and Keen" for previews.
static func describe(upgrade: Dictionary) -> String:
	var parts: Array[String] = []
	var levels: int = int(upgrade.get("levels", 0))
	if levels > 0:
		parts.append("+%d level%s" % [levels, "" if levels == 1 else "s"])
	var modifier_id: String = String(upgrade.get("modifier", ""))
	if not modifier_id.is_empty():
		parts.append("%s (%s)" % [
			ModifierCatalog.display_name(modifier_id),
			ModifierCatalog.describe(modifier_id),
		])
	if parts.is_empty():
		return "no change"
	return " and ".join(parts)


## What the instance becomes, such as "E Lv3 Healer [Keen]".
static func preview(stats: LetterStats, upgrade: Dictionary) -> String:
	var copy: LetterStats = stats.duplicate() as LetterStats
	copy.modifiers = stats.modifier_ids()
	apply(copy, upgrade)
	return copy.describe()


## Applies the upgrade; a modifier is skipped when both slots are full.
static func apply(stats: LetterStats, upgrade: Dictionary) -> void:
	stats.level += maxi(int(upgrade.get("levels", 0)), 0)
	var modifier_id: String = String(upgrade.get("modifier", ""))
	if not modifier_id.is_empty():
		stats.add_modifier(modifier_id)


## True when applying would lose nothing (modifier slots allow it).
static func fits(stats: LetterStats, upgrade: Dictionary) -> bool:
	var modifier_id: String = String(upgrade.get("modifier", ""))
	return modifier_id.is_empty() or stats.can_add_modifier()


## A random offered modifier id, or "" when none are defined.
static func random_modifier(rng: RandomNumberGenerator) -> String:
	var ids: Array[String] = ModifierCatalog.offered_ids()
	if ids.is_empty():
		return ""
	return ids[rng.randi_range(0, ids.size() - 1)]
