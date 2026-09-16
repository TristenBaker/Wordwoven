class_name ManualClock
extends GameClock
## A clock that only moves when a test advances it.

var current_msec: int = 0


func now_msec() -> int:
	return current_msec


func advance(msec: int) -> void:
	current_msec += msec
