class_name TundraCold
extends RefCounted
## Encounter-local rules. All balance values live here; no run/deck resources mutate.
const FREEZE_EVERY: int = 3
const HEAT_PER_WORD: int = 1
const MAX_HEAT: int = 5
const THAW_COST: int = 2
const MIN_USABLE: int = 5

var enabled: bool = false
var heat: int = 0
var turns: int = 0
var _last_freeze_turn: int = -1
var frozen: Array[LetterStats] = []

func reset(active: bool) -> void:
	enabled = active
	heat = 0
	turns = 0
	_last_freeze_turn = -1
	frozen.clear()

func accept_word() -> void:
	if enabled:
		turns += 1
		heat = mini(MAX_HEAT, heat + HEAT_PER_WORD)

func freeze_after_turn(hand: Array[LetterStats]) -> LetterStats:
	# Also handles debug hands being replaced wholesale.
	frozen = frozen.filter(func(tile: LetterStats) -> bool: return hand.has(tile))
	if not enabled or turns == 0 or turns % FREEZE_EVERY != 0 or turns == _last_freeze_turn:
		return null
	_last_freeze_turn = turns
	var available: Array[LetterStats] = hand.filter(
		func(tile: LetterStats) -> bool: return not frozen.has(tile))
	if available.size() <= MIN_USABLE:
		return null
	var tile: LetterStats = available.pick_random()
	frozen.append(tile)
	return tile

func thaw(tile: LetterStats) -> bool:
	if not enabled or not frozen.has(tile) or heat < THAW_COST:
		return false
	heat -= THAW_COST
	frozen.erase(tile)
	return true

## Off-hand letters remain legal, but cannot stand in for a frozen tile.
## Unfrozen duplicates can still supply their own occurrences.
func blocked_letter(word: String, hand: Array[LetterStats]) -> String:
	if not enabled:
		return ""
	for tile: LetterStats in frozen:
		var usable: int = 0
		for other: LetterStats in hand:
			if other.letter == tile.letter and not frozen.has(other):
				usable += 1
		if word.to_lower().count(tile.letter) > usable:
			return tile.letter.to_upper()
	return ""
