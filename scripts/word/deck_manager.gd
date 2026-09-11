class_name DeckManager
extends Node
## Runs the letter economy inside one encounter: shuffles the run
## deck into a draw pile, deals the hand, and recycles letters the
## player spends on words. The run's deck itself is never modified.

const HAND_SIZE: int = 8

var _draw_pile: Array[LetterStats] = []
var _discard_pile: Array[LetterStats] = []
var _hand: Array[LetterStats] = []


## Copies the run deck into a fresh shuffled draw pile and deals
## a full hand.
func start_encounter() -> void:
	_draw_pile = RunState.deck.duplicate()
	_draw_pile.shuffle()
	_discard_pile = []
	_hand = []
	refill_hand()


func hand() -> Array[LetterStats]:
	return _hand


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
		if _draw_pile.is_empty():
			if _discard_pile.is_empty():
				break
			_draw_pile = _discard_pile
			_draw_pile.shuffle()
			_discard_pile = []
		_hand.append(_draw_pile.pop_back())
	_sort_hand_alphabetically()
	EventBus.emit_hand_drawn(_hand)


func _sort_hand_alphabetically() -> void:
	_hand.sort_custom(func(left: LetterStats, right: LetterStats) -> bool:
		return left.letter < right.letter
	)


## Splits a word into the hand letters that cover it (drawn) and
## the characters that had to come from outside the hand (undrawn).
## Returns {"drawn": Array[LetterStats], "undrawn": Array[String]}.
func split_word(word: String) -> Dictionary:
	var drawn: Array[LetterStats] = []
	var undrawn: Array[String] = []
	var remaining: Array[LetterStats] = _hand.duplicate()
	for character: String in word.to_lower():
		var found: LetterStats = null
		for stats: LetterStats in remaining:
			if stats.letter == character:
				found = stats
				break
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
