extends Node
## Offline playtest events. Each line is independently readable after a crash.

const BUILD_PATH: String = "res://data/telemetry_build.json"
var log_path: String = ""
var _file: FileAccess
var _build: Dictionary = {}
var _session: String = ""
var _run: String = ""
var _sequence: int = 0
var _run_started: int = 0
var _encounter_started: int = 0
var _debug_used: bool = false


func _ready() -> void:
	if OS.get_environment("WORDWOVEN_TELEMETRY") == "0":
		return
	# Automated headless suites must opt in explicitly.
	if DisplayServer.get_name() == "headless" \
			and OS.get_environment("WORDWOVEN_TELEMETRY") != "1":
		return
	_build = _read_build()
	_session = Crypto.new().generate_random_bytes(16).hex_encode()
	var directory: String = "user://telemetry"
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_warning("Telemetry directory unavailable; tracking disabled.")
		return
	log_path = directory.path_join(_session + ".jsonl")
	_file = FileAccess.open(log_path, FileAccess.WRITE)
	if _file == null:
		push_warning("Telemetry file unavailable; tracking disabled.")
		return
	RunState.run_started.connect(_start_run)
	RunState.run_starting.connect(end_run.bind("restarted"))
	EventBus.encounter_started.connect(_start_encounter)
	EventBus.word_rejected.connect(_reject_word)
	EventBus.word_resolved.connect(_resolve_word)
	EventBus.encounter_won.connect(_win_encounter)
	EventBus.player_defeated.connect(_lose_run)
	EventBus.player_damaged.connect(_player_damage)
	EventBus.gold_changed.connect(_gold_changed)
	EventBus.relic_gained.connect(_relic_gained)
	EventBus.debug_toggled.connect(_debug_toggled)
	track("session_started", {"platform": OS.get_name()})


func _exit_tree() -> void:
	end_run("quit")
	track("session_ended")
	if _file != null:
		_file.close()


func track(event: String, data: Dictionary = {}) -> void:
	if _file == null:
		return
	_sequence += 1
	var row: Dictionary = {
		"schema_version": 1, "event": event,
		"session_id": _session, "run_id": _run,
		"sequence": _sequence, "build": _build,
		"utc": Time.get_datetime_string_from_system(true),
		"elapsed_ms": Time.get_ticks_msec(),
		"debug_used": _debug_used,
		"encounter": RunState.encounter_index,
		"biome": RunState.selected_biome,
		"health": RunState.player_health, "gold": RunState.gold,
		"data": data,
	}
	_file.store_line(JSON.stringify(row))
	_file.flush()
	if _file.get_error() != OK:
		push_warning("Telemetry write failed; tracking disabled.")
		_file.close()
		_file = null


func end_run(outcome: String) -> void:
	if _run.is_empty():
		return
	track("run_ended", {
		"outcome": outcome,
		"duration_ms": Time.get_ticks_msec() - _run_started,
		"encounters_completed": RunState.completed_encounters.size(),
	})
	_run = ""


func _start_run() -> void:
	_run = Crypto.new().generate_random_bytes(16).hex_encode()
	_run_started = Time.get_ticks_msec()
	track("run_started", {"itemized": RunState.use_itemized_letters})


func _start_encounter(enemy: Dictionary) -> void:
	_encounter_started = Time.get_ticks_msec()
	var details: Dictionary = {}
	for key: String in ["id", "name", "health", "attack", "tags"]:
		if enemy.has(key):
			details[key] = enemy[key]
	track("encounter_started", {"enemy": details})


func _reject_word(word: String, reason: String) -> void:
	# Store no player-entered text, including text embedded in feedback.
	var category: String = "validation"
	if reason == "Too short":
		category = "too_short"
	elif reason == "Letters only":
		category = "non_letters"
	elif reason == "Not in the lexicon":
		category = "unknown_word"
	elif "already" in reason.to_lower():
		category = "repeated_word"
	elif "noun" in reason or "verb" in reason or "adjective" in reason:
		category = "part_of_speech"
	track("word_rejected", {
		"length": word.length(), "category": category,
	})


func _resolve_word(result: Dictionary) -> void:
	var data: Dictionary = {"length": str(result.get("word", "")).length()}
	for key: String in [
		"damage", "elapsed_seconds", "pos", "drawn_count",
		"undrawn_count", "elemental_damage", "water_heal",
		"effectiveness", "speed_multiplier",
	]:
		if result.has(key):
			data[key] = result[key]
	track("word_resolved", data)


func _win_encounter(gold: int) -> void:
	track("encounter_won", {
		"reward_gold": gold,
		"duration_ms": Time.get_ticks_msec() - _encounter_started,
	})


func _lose_run() -> void:
	end_run("lost")


func _player_damage(amount: float) -> void:
	track("player_damaged", {"amount": amount})


func _gold_changed(total: int) -> void:
	track("gold_changed", {"total": total})


func _relic_gained(id: String) -> void:
	track("power_selected", {"id": id})


func _debug_toggled(enabled: bool) -> void:
	# Sticky across runs: forced tags and letters survive a restart.
	_debug_used = _debug_used or enabled
	track("debug_toggled", {"enabled": enabled})


func _read_build() -> Dictionary:
	# Editor runs read Git live; exported games use a stamped manifest.
	if OS.has_feature("editor"):
		var root: String = ProjectSettings.globalize_path("res://")
		var commit: String = _git(root, ["rev-parse", "HEAD"])
		if not commit.is_empty():
			return {
				"branch": _git(root, ["rev-parse", "--abbrev-ref", "HEAD"]),
				"commit": commit,
				"dirty": not _git(root, ["status", "--porcelain"]).is_empty(),
			}
	if FileAccess.file_exists(BUILD_PATH):
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(BUILD_PATH)
		)
		if parsed is Dictionary:
			return parsed
	push_warning("Telemetry build unknown. Stamp metadata before exporting.")
	return {"branch": "unknown", "commit": "unknown", "dirty": null}


func _git(root: String, arguments: Array[String]) -> String:
	var output: Array = []
	var args: PackedStringArray = PackedStringArray(["-C", root])
	args.append_array(PackedStringArray(arguments))
	if OS.execute("git", args, output) != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()
