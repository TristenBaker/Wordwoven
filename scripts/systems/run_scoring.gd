class_name RunScoring
extends RefCounted
## Transparent end-of-run score calculation used by local rankings.

const ENEMY_POINTS := 100
const GOLD_POINTS := 4
const TILE_LEVEL_POINTS := 25
const POWER_POINTS := 50
const HEALTH_POINTS := 2
const VICTORY_BONUS := 300


static func snapshot(victory: bool) -> Dictionary:
	var defeated: int = RunState.defeated_enemy_ids.size()
	var gold_earned: int = RunState.gold_earned_this_run
	var total_levels: int = _owned_tile_levels()
	var power_stacks: int = RunState.relics.size()
	var health: int = RunState.player_health
	var breakdown := {
		"enemies": defeated * ENEMY_POINTS,
		"gold": gold_earned * GOLD_POINTS,
		"tiles": total_levels * TILE_LEVEL_POINTS,
		"powers": power_stacks * POWER_POINTS,
		"health": health * HEALTH_POINTS,
		"victory": VICTORY_BONUS if victory else 0,
	}
	var score := 0
	for value: Variant in breakdown.values():
		score += int(value)
	return {
		"score": score,
		"victory": victory,
		"mode": "Endless" if RunState.is_endless() else "Story",
		"biome": "Endless Wilds" if RunState.is_endless() else (
			RunState.selected_biome.capitalize() if not RunState.selected_biome.is_empty() else "Unknown"
		),
		"enemies": defeated,
		"gold_earned": gold_earned,
		"tile_levels": total_levels,
		"power_stacks": power_stacks,
		"health": health,
		"breakdown": breakdown,
		"recorded_at": Time.get_unix_time_from_system(),
	}


static func breakdown_text(run: Dictionary) -> String:
	var points: Dictionary = run.get("breakdown", {})
	var victory_line := "\nVictory bonus = %d" % VICTORY_BONUS if bool(run.get("victory", false)) else ""
	return "Score %d\nEnemies %d × %d = %d\nGold earned %d × %d = %d\nTile levels %d × %d = %d\nPowers %d × %d = %d\nHealth %d × %d = %d%s" % [
		int(run.get("score", 0)),
		int(run.get("enemies", 0)), ENEMY_POINTS, int(points.get("enemies", 0)),
		int(run.get("gold_earned", 0)), GOLD_POINTS, int(points.get("gold", 0)),
		int(run.get("tile_levels", 0)), TILE_LEVEL_POINTS, int(points.get("tiles", 0)),
		int(run.get("power_stacks", 0)), POWER_POINTS, int(points.get("powers", 0)),
		int(run.get("health", 0)), HEALTH_POINTS, int(points.get("health", 0)),
		victory_line,
	]


static func _owned_tile_levels() -> int:
	var total := 0
	var items: Array[LetterStats] = []
	if RunState.use_itemized_letters:
		items.append_array(RunState.letter_inventory)
		for item: LetterStats in RunState.equipped_letters.values():
			items.append(item)
	else:
		items.append_array(RunState.deck)
	for item: LetterStats in items:
		total += item.level
	return total
