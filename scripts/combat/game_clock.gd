class_name GameClock
extends RefCounted
## Supplies the current time to timed rules. Tests substitute a
## manually advanced clock so deadlines can be checked exactly.


## Milliseconds elapsed since an arbitrary fixed starting point.
func now_msec() -> int:
	return Time.get_ticks_msec()
