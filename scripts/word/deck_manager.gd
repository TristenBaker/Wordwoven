class_name DeckManager
extends Node
## Runs the letter economy inside one encounter: shuffles the run
## deck into a draw pile, deals the hand, and recycles letters the
## player spends on words. The run's deck itself is never modified.

const HAND_SIZE: int = 8

# Optional seeded generator; the global one shuffles when unset.
var rng: RandomNumberGenerator = null

var _draw_pile: Array[LetterStats] = []
var _discard_pile: Array[LetterStats] = []
var _hand: Array[LetterStats] = []


## Copies the run deck into a fresh shuffled draw pile and deals
## a full hand.
func start_encounter() -> void:
	_draw_pile = RunState.deck.duplicate()
	_shuffle(_draw_pile)
	_discard_pile = []
	_hand = []
	refill_hand()


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
## With conditions, unaffected copies are chosen before poisoned or
## frozen copies of the same letter.
## Returns {"drawn": Array[LetterStats], "undrawn": Array[String]}.
func split_word(
	word: String, conditions: EncounterConditions = null
) -> Dictionary:
	var drawn: Array[LetterStats] = []
	var undrawn: Array[String] = []
	var remaining: Array[LetterStats] = _hand.duplicate()
	for character: String in word.to_lower():
		var found: LetterStats = null
		for stats: LetterStats in remaining:
			if stats.letter != character:
				continue
			if found == null or _penalty(stats, conditions) \
					< _penalty(found, conditions):
				found = stats
		if found != null:
			remaining.erase(found)
			drawn.append(found)
		else:
			undrawn.append(character)
	return {"drawn": drawn, "undrawn": undrawn}


## Moves the word's drawn letters to the discard pile and deals
## replacements.
func spend_letters(drawn: Array[LetterStats]) -> void:
	for stats: LetterStats in drawn:
		_hand.erase(stats)
		_discard_pile.append(stats)
	refill_hand()


## Takes an instance out of the hand without dealing a replacement.
func remove_from_hand(stats: LetterStats) -> bool:
	if not _hand.has(stats):
		return false
	_hand.erase(stats)
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
