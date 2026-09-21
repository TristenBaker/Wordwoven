class_name DeckManager
extends Node
## Runs the letter economy inside one encounter: shuffles the run's
## circulating letters into a draw pile, deals the hand, and recycles
## letters the player spends on words. Forgotten letters and letters
## on pilgrimage stay owned but never enter the piles. The run's deck
## itself is never modified.

const HAND_SIZE: int = 8

# Optional seeded generator; the global one shuffles when unset.
var rng: RandomNumberGenerator = null

var _draw_pile: Array[LetterStats] = []
var _discard_pile: Array[LetterStats] = []
var _hand: Array[LetterStats] = []
# Turn starts each hand instance has waited through without being used.
var _waited_turns: Dictionary = {}


## Copies the circulating run deck into a fresh shuffled draw pile
## and deals a full hand.
func start_encounter() -> void:
	RunState.ensure_letter_ids()
	_draw_pile = RunState.circulating_deck()
	_shuffle(_draw_pile)
	_discard_pile = []
	_hand = []
	_waited_turns = {}
	refill_hand()


## Called as each player turn opens: letters already in hand count
## one more turn of waiting, and newly dealt letters start at zero.
func begin_turn() -> void:
	var waited: Dictionary = {}
	for stats: LetterStats in _hand:
		if _waited_turns.has(stats):
			waited[stats] = int(_waited_turns[stats]) + 1
		else:
			waited[stats] = 0
	_waited_turns = waited


## Turns this hand instance has waited before the current one.
func waited_turns(stats: LetterStats) -> int:
	return int(_waited_turns.get(stats, 0))


func hand() -> Array[LetterStats]:
	return _hand


func draw_pile() -> Array[LetterStats]:
	return _draw_pile.duplicate()


func discard_pile() -> Array[LetterStats]:
	return _discard_pile.duplicate()


## Replaces every pile at once, for deterministic tests and tools.
func set_piles(
	new_hand: Array[LetterStats],
	new_draw_pile: Array[LetterStats],
	new_discard_pile: Array[LetterStats]
) -> void:
	_hand = new_hand.duplicate()
	_draw_pile = new_draw_pile.duplicate()
	_discard_pile = new_discard_pile.duplicate()
	_waited_turns = {}
	_sort_hand_alphabetically()


## Deals from the draw pile until the hand is full, reshuffling the
## discard pile in when the draw pile runs dry.
func refill_hand() -> void:
	var hand_size: int = HAND_SIZE
	var relic_system: RelicSystem = RelicSystem.new()
	hand_size += int(relic_system.total_effect("hand_size"))
	# The debug overlay can force the exact letters dealt.
	if not DebugTools.forced_letters.is_empty():
		_hand = []
		for character: String in DebugTools.forced_letters:
			_hand.append(LetterStats.create(character))
		_sort_hand_alphabetically()
		EventBus.emit_hand_drawn(_hand)
		return
	while _hand.size() < hand_size:
		var drawn: LetterStats = _draw_one()
		if drawn == null:
			break
		_hand.append(drawn)
	_sort_hand_alphabetically()
	EventBus.emit_hand_drawn(_hand)


## Splits a word into the hand letters that cover it (drawn) and
## the characters that had to come from outside the hand (undrawn).
## Among duplicate copies of a letter, the preferred (Threaded)
## instance is used first, then unaffected copies before poisoned or
## frozen ones, then more modifiers, higher level, and lower id.
## Returns {"drawn": Array[LetterStats], "undrawn": Array[String]}.
func split_word(
	word: String, conditions: EncounterConditions = null,
	preferred: LetterStats = null
) -> Dictionary:
	var drawn: Array[LetterStats] = []
	var undrawn: Array[String] = []
	var remaining: Array[LetterStats] = _hand.duplicate()
	for character: String in word.to_lower():
		var found: LetterStats = null
		for stats: LetterStats in remaining:
			if stats.letter != character:
				continue
			if found == null or _better_copy(
				stats, found, conditions, preferred
			):
				found = stats
		if found != null:
			remaining.erase(found)
			drawn.append(found)
		else:
			undrawn.append(character)
	return {"drawn": drawn, "undrawn": undrawn}


## Moves the word's drawn letters to the discard pile and deals
## replacements. A kept (Threaded) instance stays in hand instead.
func spend_letters(
	drawn: Array[LetterStats], keep: LetterStats = null
) -> void:
	for stats: LetterStats in drawn:
		# A threaded letter stays and starts waiting afresh.
		_waited_turns.erase(stats)
		if stats == keep:
			continue
		_hand.erase(stats)
		_discard_pile.append(stats)
	refill_hand()


## Takes an instance out of the hand without dealing a replacement.
func remove_from_hand(stats: LetterStats) -> bool:
	if not _hand.has(stats):
		return false
	_hand.erase(stats)
	_waited_turns.erase(stats)
	EventBus.emit_hand_drawn(_hand)
	return true


## Returns instances that left circulation to the discard pile.
func return_to_discard(letters: Array[LetterStats]) -> void:
	for stats: LetterStats in letters:
		if not _discard_pile.has(stats) and not _hand.has(stats):
			_discard_pile.append(stats)


## True when the piles can supply this many replacement tiles.
func can_redraw(count: int) -> bool:
	return count > 0 \
			and _draw_pile.size() + _discard_pile.size() >= count


## Swaps selected hand tiles for new ones. Replacements are drawn
## before the selections reach the discard pile, so the same
## instances cannot come straight back. Changes nothing on failure.
func redraw(selected: Array[LetterStats]) -> bool:
	if selected.is_empty() or not can_redraw(selected.size()):
		return false
	var unique: Array[LetterStats] = []
	for stats: LetterStats in selected:
		if not _hand.has(stats) or unique.has(stats):
			return false
		unique.append(stats)
	var replacements: Array[LetterStats] = []
	for index: int in unique.size():
		replacements.append(_draw_one())
	for stats: LetterStats in unique:
		_hand.erase(stats)
		_waited_turns.erase(stats)
		_discard_pile.append(stats)
	_hand.append_array(replacements)
	_sort_hand_alphabetically()
	EventBus.emit_hand_drawn(_hand)
	return true


func _draw_one() -> LetterStats:
	if _draw_pile.is_empty():
		if _discard_pile.is_empty():
			return null
		_draw_pile = _discard_pile
		_shuffle(_draw_pile)
		_discard_pile = []
	return _draw_pile.pop_back()


func _shuffle(letters: Array[LetterStats]) -> void:
	if rng == null:
		letters.shuffle()
		return
	for index: int in range(letters.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: LetterStats = letters[index]
		letters[index] = letters[swap_index]
		letters[swap_index] = held


func _sort_hand_alphabetically() -> void:
	_hand.sort_custom(func(left: LetterStats, right: LetterStats) -> bool:
		return left.letter < right.letter
	)


# True when candidate should spell the letter instead of current.
func _better_copy(
	candidate: LetterStats, current: LetterStats,
	conditions: EncounterConditions, preferred: LetterStats
) -> bool:
	var candidate_preferred: bool = candidate == preferred
	var current_preferred: bool = current == preferred
	if preferred != null and candidate_preferred != current_preferred:
		return candidate_preferred
	var candidate_penalty: int = _penalty(candidate, conditions)
	var current_penalty: int = _penalty(current, conditions)
	if candidate_penalty != current_penalty:
		return candidate_penalty < current_penalty
	var candidate_mods: int = candidate.modifier_ids().size()
	var current_mods: int = current.modifier_ids().size()
	if candidate_mods != current_mods:
		return candidate_mods > current_mods
	if candidate.level != current.level:
		return candidate.level > current.level
	return candidate.instance_id < current.instance_id


# Lower values are better choices for spelling a word.
func _penalty(
	stats: LetterStats, conditions: EncounterConditions
) -> int:
	if conditions == null:
		return 0
	var penalty: int = 0
	if conditions.is_poisoned(stats):
		penalty += 1
	if conditions.is_frozen(stats):
		penalty += 2
	return penalty
