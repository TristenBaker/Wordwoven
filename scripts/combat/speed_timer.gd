class_name SpeedTimer
extends RefCounted
## Tracks the swift-cast deadline of one player turn. A word accepted
## within the deadline earns a final damage multiplier; missing the
## deadline removes only that bonus.

const DEADLINE_MSEC: int = 12000
const DAMAGE_MULTIPLIER: float = 1.5

var clock: GameClock = null

var _started_msec: int = -1


func _init(new_clock: GameClock = null) -> void:
	clock = new_clock if new_clock != null else GameClock.new()


## Opens a fresh deadline for a new player turn.
func start() -> void:
	_started_msec = clock.now_msec()


## Stops timing while the turn resolves or combat has ended.
func stop() -> void:
	_started_msec = -1


func is_running() -> bool:
	return _started_msec >= 0


func now_msec() -> int:
	return clock.now_msec()


## True when a submission captured at this time beats the deadline.
func qualifies(submitted_msec: int) -> bool:
	if not is_running():
		return false
	var elapsed: int = submitted_msec - _started_msec
	return elapsed >= 0 and elapsed <= DEADLINE_MSEC


## Milliseconds left before the bonus expires; zero when stopped.
func remaining_msec() -> int:
	if not is_running():
		return 0
	var elapsed: int = clock.now_msec() - _started_msec
	return maxi(DEADLINE_MSEC - elapsed, 0)
