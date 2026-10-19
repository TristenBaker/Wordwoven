class_name RunLeaderboard
extends RefCounted
## Local persistence boundary. A future service can replace these load/save calls.

const SAVE_PATH := "user://wordwoven_leaderboard.json"
const MAX_ENTRIES := 20

var _entries: Array[Dictionary] = []


func _init() -> void:
	_load()


func record(run: Dictionary) -> Array[Dictionary]:
	_entries.append(run.duplicate(true))
	_entries.sort_custom(_higher_score_first)
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	_save()
	return entries()


func entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


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
		for entry: Variant in parsed:
			if entry is Dictionary:
				_entries.append(entry)
	_entries.sort_custom(_higher_score_first)


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_entries))
	file.close()
