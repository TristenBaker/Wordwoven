extends Node
## Observe accepted combat events. Checkpoint lifetime progress before each
## run so developer assistance can discard that entire contribution.
signal statistics_changed
signal achievements_changed
signal achievement_unlocked(id: String, title: String)
signal achievement_notifications_cleared
signal persistence_failed(message: String)

const ALPHABET: String = "abcdefghijklmnopqrstuvwxyz"
const SAVE_PATH: String = "user://achievements.cfg"
const SCHEMA_VERSION: int = 1
const DEFINITIONS: Array[Dictionary] = [
	{"id": "first_blood", "name": "First Blood",
		"description": "Defeat your first enemy.", "key": "kills", "goal": 1},
	{"id": "wordsmith", "name": "Wordsmith",
		"description": "Submit 25 accepted combat words.",
		"key": "words", "goal": 25},
	{"id": "heavy_hitter", "name": "Heavy Hitter",
		"description": "Deal 50 direct damage with one word.",
		"key": "highest_damage", "goal": 50},
	{"id": "noun_master", "name": "Noun Master",
		"description": "Submit 15 nouns in combat.", "key": "n", "goal": 15},
	{"id": "verb_master", "name": "Verb Master",
		"description": "Submit 15 verbs in combat.", "key": "v", "goal": 15},
	{"id": "adjective_master", "name": "Adjective Master",
		"description": "Submit 15 adjectives in combat.",
		"key": "a", "goal": 15},
	{"id": "adverb_master", "name": "Adverb Master",
		"description": "Submit 15 adverbs in combat.", "key": "r", "goal": 15},
	{"id": "alphabet_explorer", "name": "Alphabet Explorer",
		"description": "Use all 26 letters in accepted combat words.",
		"key": "alphabet", "goal": 26},
	{"id": "monster_slayer", "name": "Monster Slayer",
		"description": "Defeat 10 enemies across runs.",
		"key": "kills", "goal": 10},
	{"id": "victory", "name": "Victory!",
		"description": "Successfully complete a run.",
		"key": "wins", "goal": 1},
]

var _run: Dictionary = {}
var _lifetime: Dictionary = {}
var _baseline: Dictionary = {}
var _unlocked: Array[String] = []
var _baseline_unlocked: Array[String] = []
var _encounter_start: int = 0
var _processed_words: int = 0
var _encounter_open: bool = false
var _tracking: bool = false
var _finalized: bool = true
var _debug_assisted: bool = false
var _save_path: String = SAVE_PATH
var _persistence_enabled: bool = true
var _load_blocked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run = _empty_counters()
	_lifetime = _empty_counters()
	var override: String = OS.get_environment("WORDWOVEN_ACHIEVEMENTS_PATH")
	if not override.is_empty():
		_save_path = override
	_persistence_enabled = (
		DisplayServer.get_name() != "headless" or not override.is_empty()
	)
	if _persistence_enabled:
		load_progress()
	RunState.run_started.connect(_start_run)
	EventBus.encounter_started.connect(_start_encounter)
	EventBus.word_resolved.connect(_word_resolved)
	EventBus.player_damaged.connect(_player_damaged)
	EventBus.encounter_won.connect(_encounter_won)
	var notifications: CanvasLayer = preload(
		"res://scenes/ui/achievement_notifications.tscn"
	).instantiate()
	add_child(notifications)


func _empty_counters() -> Dictionary:
	var letters: Dictionary = {}
	for letter: String in ALPHABET:
		letters[letter] = 0
	return {
		"words": 0, "kills": 0, "encounters": 0, "damage": 0.0,
		"received": 0.0, "highest_damage": 0.0, "best_word": "",
		"n": 0, "v": 0, "a": 0, "r": 0, "wins": 0,
		"letters": letters,
	}


func _start_run() -> void:
	_run = _empty_counters()
	_baseline = _lifetime.duplicate(true)
	_baseline_unlocked = _unlocked.duplicate()
	_encounter_start = 0
	_processed_words = 0
	_encounter_open = false
	_tracking = true
	_finalized = false
	_debug_assisted = false
	_check_debug_overrides(false)
	statistics_changed.emit()
	achievements_changed.emit()


func _check_debug_overrides(include_map: bool = true) -> void:
	var debug: Node = get_node_or_null("/root/DebugTools")
	if debug != null and (
		not debug.forced_tags.is_empty()
		or not debug.forced_letters.is_empty()
		or (include_map and debug.free_map_select)
	):
		mark_debug_assisted()


func mark_debug_assisted() -> void:
	if not _tracking or _debug_assisted:
		return
	_debug_assisted = true
	_lifetime = _baseline.duplicate(true)
	_unlocked = _baseline_unlocked.duplicate()
	achievement_notifications_cleared.emit()
	achievements_changed.emit()
	if _save_progress() == OK and _persistence_enabled:
		# A backup from earlier in this run must not restore assisted progress.
		var error: Error = DirAccess.copy_absolute(
			_save_path, _save_path + ".bak"
		)
		if error != OK:
			DirAccess.remove_absolute(_save_path + ".bak")
			persistence_failed.emit("Achievement backup could not be saved.")
			push_warning("Achievement backup failed: %s" % error_string(error))


func _start_encounter(_enemy: Dictionary) -> void:
	if not _tracking:
		return
	_check_debug_overrides()
	_encounter_start = RunState.word_history.size()
	_processed_words = _encounter_start
	_encounter_open = true


func _word_resolved(result: Dictionary) -> void:
	if not _tracking or not _encounter_open:
		return
	# Only consume the authoritative newly recorded cast, never previews or
	# duplicate broadcasts of a previously processed result.
	var count: int = RunState.word_history.size()
	if count <= _processed_words:
		return
	var entry: Dictionary = RunState.word_history.back()
	if entry.get("word", "") != result.get("word", ""):
		return
	_processed_words = count
	_check_debug_overrides()
	_add_word(_run, entry)
	statistics_changed.emit()
	if not _debug_assisted:
		_add_word(_lifetime, entry)
		_evaluate_achievements()
		_save_progress()


func _add_word(counters: Dictionary, entry: Dictionary) -> void:
	var word: String = String(entry.word).to_lower()
	var damage: float = maxf(float(entry.damage), 0.0)
	counters.words += 1
	counters.damage += damage
	var pos: String = String(entry.get("pos", ""))
	if pos in ["n", "v", "a", "r"]:
		counters[pos] += 1
	for letter: String in word:
		if counters.letters.has(letter):
			counters.letters[letter] += 1
	if damage > float(counters.highest_damage):
		counters.highest_damage = damage
		counters.best_word = word


func _player_damaged(amount: float) -> void:
	# The existing event reports post-mitigation incoming damage, including
	# lethal overkill. It fires before RunState marks the player defeated.
	if _tracking and not _finalized:
		_run.received += maxf(amount, 0.0)
		statistics_changed.emit()


func _encounter_won(_gold: int) -> void:
	if not _tracking or not _encounter_open:
		return
	_check_debug_overrides()
	_encounter_open = false
	_run.kills += 1
	_run.encounters += 1
	statistics_changed.emit()
	if not _debug_assisted:
		_lifetime.kills += 1
		_evaluate_achievements()
		_save_progress()


func finalize_run(victory: bool = false) -> void:
	if _finalized:
		return
	_check_debug_overrides()
	_finalized = true
	_encounter_open = false
	if victory:
		_run.wins = 1
		if not _debug_assisted:
			_lifetime.wins += 1
			_evaluate_achievements()
	_tracking = false
	_save_progress()
	statistics_changed.emit()


func run_snapshot() -> Dictionary:
	var snapshot: Dictionary = _run.duplicate(true)
	var best_count: int = 0
	snapshot["most_used_letter"] = "None"
	for letter: String in ALPHABET:
		var count: int = int(snapshot.letters[letter])
		if count > best_count:
			best_count = count
			snapshot.most_used_letter = letter.to_upper()
	snapshot["debug_assisted"] = _debug_assisted
	return snapshot


func encounter_history() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index: int in range(_encounter_start, RunState.word_history.size()):
		entries.append(RunState.word_history[index].duplicate(true))
	return entries


func achievement_snapshot() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for definition: Dictionary in DEFINITIONS:
		var row: Dictionary = definition.duplicate(true)
		row["unlocked"] = _unlocked.has(String(row.id))
		row["progress"] = minf(_progress(String(row.key)), float(row.goal))
		rows.append(row)
	return rows


func _progress(key: String) -> float:
	if key != "alphabet":
		return float(_lifetime.get(key, 0))
	var count: int = 0
	for letter: String in ALPHABET:
		if int(_lifetime.letters[letter]) > 0:
			count += 1
	return float(count)


func _evaluate_achievements() -> void:
	for definition: Dictionary in DEFINITIONS:
		var id: String = String(definition.id)
		if (
			not _unlocked.has(id)
			and _progress(String(definition.key)) >= float(definition.goal)
		):
			_unlocked.append(id)
			achievement_unlocked.emit(id, String(definition.name))
	achievements_changed.emit()


func _save_progress() -> Error:
	if not _persistence_enabled:
		return OK
	if _load_blocked:
		return ERR_FILE_UNRECOGNIZED
	var config: ConfigFile = ConfigFile.new()
	config.set_value("achievements", "schema_version", SCHEMA_VERSION)
	config.set_value("achievements", "unlocked", _unlocked)
	for key: String in [
		"words", "kills", "n", "v", "a", "r", "wins", "highest_damage",
	]:
		config.set_value("progress", key, _lifetime[key])
	config.set_value("progress", "letters", _lifetime.letters)
	var temporary: String = _save_path + ".tmp"
	var backup: String = _save_path + ".bak"
	var error: Error = config.save(temporary)
	if error == OK and FileAccess.file_exists(_save_path):
		if FileAccess.file_exists(backup):
			error = DirAccess.remove_absolute(backup)
		if error == OK:
			error = DirAccess.rename_absolute(_save_path, backup)
	if error == OK:
		error = DirAccess.rename_absolute(temporary, _save_path)
		if error != OK and FileAccess.file_exists(backup):
			DirAccess.copy_absolute(backup, _save_path)
	if error != OK:
		persistence_failed.emit("Achievement progress could not be saved.")
		push_warning("Achievement save failed: %s" % error_string(error))
	return error


func load_progress() -> void:
	var loaded: bool = false
	for path: String in [_save_path, _save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var config: ConfigFile = ConfigFile.new()
		if config.load(path) != OK:
			continue
		var schema: Variant = config.get_value(
			"achievements", "schema_version", 0
		)
		if schema is int and schema > SCHEMA_VERSION:
			_load_blocked = true
			break
		if not schema is int or schema != SCHEMA_VERSION \
				or not _valid_progress(config):
			continue
		_lifetime = _empty_counters()
		for key: String in [
			"words", "kills", "n", "v", "a", "r", "wins", "highest_damage",
		]:
			_lifetime[key] = config.get_value("progress", key, 0)
		_lifetime.letters = config.get_value("progress", "letters")
		_unlocked.clear()
		var ids: Array = config.get_value("achievements", "unlocked", [])
		for definition: Dictionary in DEFINITIONS:
			var id: String = String(definition.id)
			if (
				ids.has(id)
				and _progress(String(definition.key)) >= float(definition.goal)
			):
				_unlocked.append(id)
		loaded = true
		# Restore the valid backup without rotating a corrupt primary over it.
		if path != _save_path:
			DirAccess.copy_absolute(path, _save_path)
		break
	if not loaded and (
		FileAccess.file_exists(_save_path)
		or FileAccess.file_exists(_save_path + ".bak")
	):
		_load_blocked = true
		push_warning("Achievement save invalid; existing files preserved.")
	achievements_changed.emit()


func _valid_progress(config: ConfigFile) -> bool:
	var ids: Variant = config.get_value("achievements", "unlocked", [])
	if not ids is Array:
		return false
	for key: String in ["words", "kills", "n", "v", "a", "r", "wins"]:
		var value: Variant = config.get_value("progress", key, 0)
		if not value is int or value < 0 or value > 2147483647:
			return false
	var highest: Variant = config.get_value("progress", "highest_damage", 0)
	if not (highest is float or highest is int):
		return false
	if not is_finite(float(highest)) or float(highest) < 0.0:
		return false
	var letters: Variant = config.get_value("progress", "letters", {})
	if not letters is Dictionary:
		return false
	for letter: String in ALPHABET:
		var count: Variant = letters.get(letter, -1)
		if not count is int or count < 0 or count > 2147483647:
			return false
	return true
