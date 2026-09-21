class_name LetterThread
extends RefCounted
## The Threaded Letter for one encounter. After an accepted word the
## player may keep one used drawn instance in hand for the next turn.
## Reusing it earns Inspiration and allows threading again; an
## accepted word that skips it lets the thread expire, and no new
## letter can be threaded from that word.

var _threaded: LetterStats = null
# Whether the last accepted word may pass the thread on.
var _may_thread: bool = true


func threaded() -> LetterStats:
	return _threaded


func is_threaded(stats: LetterStats) -> bool:
	return stats != null and stats == _threaded


## Notes an accepted word's drawn instances before threading.
## Returns true when the word reused the Threaded Letter.
func note_accepted(drawn: Array[LetterStats]) -> bool:
	if _threaded == null:
		_may_thread = true
		return false
	var reused: bool = drawn.has(_threaded)
	_threaded = null
	_may_thread = reused
	return reused


## True when a letter from the last accepted word may be threaded.
func can_thread() -> bool:
	return _may_thread


## Keeps one used instance; false when threading is unavailable or
## the instance was not part of the word.
func choose(stats: LetterStats, drawn: Array[LetterStats]) -> bool:
	if not _may_thread or stats == null or not drawn.has(stats):
		return false
	_threaded = stats
	return true


## Ends the thread, such as when its tile is stolen or redrawn.
func expire() -> void:
	_threaded = null


## Drops the thread if its instance is no longer in the hand.
func validate(hand: Array[LetterStats]) -> void:
	if _threaded != null and not hand.has(_threaded):
		_threaded = null
