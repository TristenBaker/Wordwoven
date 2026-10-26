class_name RunLeaderboard
extends RefCounted
## Local persistence boundary. A future service can replace these load/save calls.

const SAVE_PATH := "user://wordwoven_leaderboard.json"
const MAX_ENTRIES := 20

var _boards: Dictionary = {
	"story": [],
	"endless": [],
}


func _init() -> void:
	_load()


func record(run: Dictionary) -> Array[Dictionary]:
	var key := _mode_key(String(run.get("mode", "Story")))
	var board: Array = _boards.get(key, [])
	board.append(run.duplicate(true))
	board.sort_custom(_higher_score_first)
	if board.size() > MAX_ENTRIES:
		board.resize(MAX_ENTRIES)
	_boards[key] = board
	_save()
	return entries(key)


func entries(mode: String = "") -> Array[Dictionary]:
	var key := _mode_key(mode if not mode.is_empty() else _current_mode_name())
	var copied: Array[Dictionary] = []
	for entry: Variant in _boards.get(key, []):
		if entry is Dictionary:
			copied.append(entry.duplicate(true))
	return copied


func _higher_score_first(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("score", 0)) > int(right.get("score", 0))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		# Migrate the original single-board save into Story rankings.
		for entry: Variant in parsed:
			if entry is Dictionary:
				var key := _mode_key(String(entry.get("mode", "Story")))
				var board: Array = _boards.get(key, [])
				board.append(entry)
				_boards[key] = board
	elif parsed is Dictionary:
		for key: String in _boards:
			var board: Array = []
			for entry: Variant in parsed.get(key, []):
				if entry is Dictionary:
					board.append(entry)
			_boards[key] = board
	for key: String in _boards:
		var board: Array = _boards.get(key, [])
		board.sort_custom(_higher_score_first)
		_boards[key] = board


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_boards))
	file.close()


func _current_mode_name() -> String:
	return "Endless" if RunState.is_endless() else "Story"


func _mode_key(mode: String) -> String:
	return "endless" if mode.to_lower() == "endless" else "story"
