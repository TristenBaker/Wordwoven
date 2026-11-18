class_name RunArchive
extends RefCounted
## Append-only final loadouts. Independent of leaderboard/profile persistence.
const DIRECTORY := "user://run_archive"
const SCHEMA_VERSION := 1
var _directory: String
var _enabled: bool


func _init(directory: String = DIRECTORY) -> void:
	var override := OS.get_environment("WORDWOVEN_RUN_ARCHIVE_DIR")
	_directory = override if directory == DIRECTORY and not override.is_empty() else directory
	# Automated scenes opt into their own directory, never the player's archive.
	_enabled = DisplayServer.get_name() != "headless" or _directory != DIRECTORY


func record_current(summary: Dictionary) -> Dictionary:
	if not _enabled:
		return {}
	if RunState.archive_run_id.is_empty():
		RunState.archive_run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var id := RunState.archive_run_id
	var path := _directory.path_join(id + ".json")
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		return load_run(id) # Reopening the end screen cannot rewrite a final loadout.
	var letters: Array[Dictionary] = []
	for tile: LetterStats in RunState.combat_letters():
		var cosmetic := PlayerProfile.combat_cosmetic_for(tile)
		var cosmetic_id := ""
		for key: String in PlayerProfile.COSMETIC_RESOURCES:
			if PlayerProfile.COSMETIC_RESOURCES[key] == cosmetic:
				cosmetic_id = key
				break
		letters.append({
			"letter": tile.letter, "element": tile.element_name_text().to_lower(),
			"level": tile.level, "modifier": LetterStats.Modifier.keys()[tile.modifier].to_lower(),
			"cosmetic": cosmetic_id,
		})
	letters.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.letter) < String(b.letter))
	var powers: Array[Dictionary] = []
	var power_system := RelicSystem.new()
	var seen: Array[String] = []
	for power_id: String in RunState.relics:
		if seen.has(power_id):
			continue
		seen.append(power_id)
		var info := power_system.relic_info(power_id)
		powers.append({
			"id": power_id, "name": info.get("name", power_id),
			"count": RunState.relics.count(power_id), "quality": info.get("quality", "common"),
			"effect": info.get("effect", ""), "amount": info.get("amount", 0.0),
			"combined_effect": power_system.calculated_effect_text(power_id),
		})
	var record := {
		"schema_version": SCHEMA_VERSION, "id": id,
		"started_at": RunState.run_started_at if RunState.run_started_at > 0 else null,
		"finished_at": summary.get("recorded_at", Time.get_unix_time_from_system()),
		"summary": summary.duplicate(true), "equipped_letters": letters, "powers": powers,
	}
	if not _write_new(path, record):
		push_warning("Final loadout could not be archived; existing saves are unchanged.")
		return {}
	return record


func _write_new(path: String, record: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or not _valid_record(_read_file(temporary)):
		return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		return false
	if DirAccess.copy_absolute(path, path + ".bak") != OK:
		push_warning("Run loadout saved, but its backup could not be created.")
	return true


func entries() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not _enabled:
		return records
	var directory := DirAccess.open(_directory)
	if directory == null:
		return records
	var seen: Array[String] = []
	for filename: String in directory.get_files():
		var id := filename.trim_suffix(".bak").trim_suffix(".json")
		if not (filename.ends_with(".json") or filename.ends_with(".json.bak")) or seen.has(id):
			continue
		seen.append(id)
		var record := load_run(id)
		if not record.is_empty():
			records.append(record)
	records.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.finished_at) > float(b.finished_at))
	return records


func load_run(id: String) -> Dictionary:
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{32}$")
	if not _enabled or pattern.search(id) == null:
		return {}
	var path := _directory.path_join(id + ".json")
	for candidate: String in [path, path + ".bak"]:
		var record := _read_file(candidate)
		if _valid_record(record) and record.id == id:
			return record
	return {}


func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}


func _valid_record(record: Dictionary) -> bool:
	if record.get("schema_version", 0) != SCHEMA_VERSION or not record.get("id", "") is String \
			or not record.get("summary") is Dictionary or not record.get("equipped_letters") is Array \
			or not record.get("powers") is Array or not (record.get("finished_at") is float or record.get("finished_at") is int):
		return false
	var summary: Dictionary = record.summary
	if not (summary.get("score") is int or summary.get("score") is float) \
			or not summary.get("mode") is String or not summary.get("victory") is bool \
			or not summary.get("biome") is String:
		return false
	for tile: Variant in record.equipped_letters:
		if not tile is Dictionary or not tile.get("letter") is String or String(tile.letter).length() != 1 \
				or not "abcdefghijklmnopqrstuvwxyz".contains(tile.letter) \
				or not tile.get("element") is String \
				or not String(tile.get("element", "")).to_upper() in LetterStats.Element.keys() \
				or not tile.get("modifier", "none") in ["none", "keen", "gilded", "heavy"] \
				or not tile.get("cosmetic", "") is String:
			return false
		if not (tile.get("level") is float or tile.get("level") is int) or int(tile.level) < 1:
			return false
	for power: Variant in record.powers:
		if not power is Dictionary or not power.get("id") is String or not power.get("name") is String \
				or not power.get("combined_effect") is String or not power.get("effect") is String \
				or not power.get("quality", "common") is String:
			return false
		if not (power.get("count") is float or power.get("count") is int) or int(power.count) < 1:
			return false
	return true


static func letter_from_record(tile: Dictionary) -> LetterStats:
	var stats := LetterStats.create_item(String(tile.letter), LetterStats.Element.keys().find(String(tile.element).to_upper()), int(tile.level))
	stats.modifier = LetterStats.Modifier.keys().find(String(tile.get("modifier", "none")).to_upper()) as LetterStats.Modifier
	return stats


func random_guest() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for record: Dictionary in entries():
		if not record.equipped_letters.is_empty():
			candidates.append(record)
	if candidates.is_empty():
		return {}
	var record: Dictionary = candidates.pick_random()
	var tile: Dictionary = record.equipped_letters.pick_random()
	return {"run": record, "tile": tile, "stats": letter_from_record(tile)}
