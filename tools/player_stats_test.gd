extends Node
## Isolated aggregate, achievement, rollback and persistence checks.
var failures: int = 0
var notifications: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func cast(word: String, pos: String = "n", damage: float = 10.0) -> void:
	RunState.record_word(word, "Test Enemy", [], damage, pos)
	PlayerStats._word_resolved({"word": word, "damage": damage, "pos": pos})


func encounter() -> void:
	EventBus.emit_encounter_started({"id": "test_enemy"})


func _run() -> void:
	# Persistence tests run with an explicit temporary path, never player data.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("persistence-read"):
		check(PlayerStats._persistence_enabled, "persistence enabled")
		check(PlayerStats._lifetime.words == 25, "restart restores words")
		check(PlayerStats._lifetime.n == 15, "restart restores POS progress")
		check(PlayerStats._lifetime.kills == 10, "restart restores kills")
		check(PlayerStats._unlocked.has("victory"), "restart restores unlocks")
		check(PlayerStats._progress("alphabet") == 26, "restart alphabet")
		_finish()
		return
	PlayerStats._persistence_enabled = false
	PlayerStats._lifetime = PlayerStats._empty_counters()
	PlayerStats._unlocked.clear()
	PlayerStats.achievement_unlocked.connect(
		func(id: String, _title: String) -> void: notifications.append(id)
	)
	RunState.start_new_run()
	check(PlayerStats.run_snapshot().most_used_letter == "None", "no letters")
	encounter()
	EventBus.emit_word_rejected("no", "invalid")
	PlayerStats._word_resolved({"word": "preview", "damage": 999})
	check(PlayerStats.run_snapshot().words == 0, "no rejected or preview words")
	cast("balloon", "n", 12.5)
	var stats: Dictionary = PlayerStats.run_snapshot()
	check(stats.words == 1 and stats.n == 1, "accepted word and prompted POS")
	check(stats.letters.l == 2 and stats.letters.o == 2, "repeated letters")
	check(stats.most_used_letter == "L", "alphabetical tie")
	check(is_equal_approx(stats.damage, 12.5), "final direct damage")
	PlayerStats._word_resolved({"word": "balloon", "damage": 12.5})
	EventBus.emit_enemy_damaged(999999.0)
	check(PlayerStats.run_snapshot().words == 1, "duplicate event ignored")
	check(PlayerStats.run_snapshot().damage == 12.5, "other damage excluded")
	stats.letters.l = 999
	check(PlayerStats.run_snapshot().letters.l == 2, "snapshot detached")
	EventBus.emit_encounter_won(10)
	EventBus.emit_encounter_won(10)
	check(PlayerStats.run_snapshot().kills == 1, "victory deduplicated")
	check(PlayerStats.run_snapshot().encounters == 1, "combat tally")
	RunState.complete_treasure_room()
	check(PlayerStats.run_snapshot().encounters == 1, "treasure excluded")
	encounter()
	check(PlayerStats.encounter_history().is_empty(), "new history boundary")
	check(RunState.word_history.size() == 1, "run history preserved")
	cast("run", "v", 50.0)
	check(PlayerStats.encounter_history().size() == 1, "current fight only")
	var history: Array[Dictionary] = PlayerStats.encounter_history()
	history[0].word = "changed"
	check(RunState.word_history.back().word == "run", "history detached")
	RunState.damage_player(999)
	check(PlayerStats.run_snapshot().received == 999.0, "lethal damage")
	PlayerStats.finalize_run()
	RunState.start_new_run()
	check(PlayerStats.run_snapshot().words == 0, "new run resets counters")
	check(PlayerStats._lifetime.words == 2, "lifetime retained across runs")
	encounter()
	cast("help", "v", 100.0)
	cast(PlayerStats.ALPHABET)
	check(PlayerStats._unlocked.has("alphabet_explorer"), "live unlock")
	PlayerStats.mark_debug_assisted()
	check(not PlayerStats._unlocked.has("alphabet_explorer"),
		"assistance revokes unlocks from this run")
	check(PlayerStats._lifetime.words == 2, "entire assisted run rolled back")
	check(PlayerStats.run_snapshot().words == 2, "debug run stats retained")
	cast("debug", "n", 200.0)
	EventBus.emit_encounter_won(10)
	PlayerStats.finalize_run(true)
	check(PlayerStats._lifetime.words == 2, "assisted words excluded")
	check(PlayerStats._lifetime.kills == 1, "assisted kills excluded")
	check(not PlayerStats._unlocked.has("victory"), "assisted victory excluded")
	DebugTools.forced_letters = "abc"
	RunState.start_new_run()
	encounter()
	cast("cat")
	check(PlayerStats._lifetime.words == 2, "inherited override excluded")
	DebugTools.forced_letters = ""
	# Build all ten thresholds over multiple ordinary runs.
	PlayerStats._lifetime = PlayerStats._empty_counters()
	PlayerStats._unlocked.clear()
	notifications.clear()
	RunState.start_new_run()
	for index: int in 10:
		encounter()
		if index == 0:
			for word_index: int in 15:
				cast("noun", "n", 50.0)
		elif index == 1:
			for word_index: int in 10:
				cast("verb", "v")
		EventBus.emit_encounter_won(1)
	PlayerStats.finalize_run(true)
	PlayerStats.finalize_run(true)
	check(PlayerStats._lifetime.wins == 1, "finalization idempotent")
	check(PlayerStats._lifetime.words == 25, "Wordsmith threshold")
	if args.has("persistence-write"):
		PlayerStats._lifetime.letters = _alphabet_counts()
		PlayerStats._evaluate_achievements()
		PlayerStats._persistence_enabled = true
		check(PlayerStats._save_progress() == OK, "save restart fixture")
		_finish()
		return
	RunState.start_new_run()
	encounter()
	for index: int in 15:
		cast("quick", "a")
		cast("quickly", "r")
	for index: int in 5:
		cast("run", "v")
	cast(PlayerStats.ALPHABET, "n")
	check(PlayerStats._unlocked.size() == 10, "all ten achievements")
	var unique: Dictionary = {}
	for id: String in notifications:
		unique[id] = true
	check(unique.size() == 10 and notifications.size() == 10,
		"one notification per unlock")
	var toast: CanvasLayer = PlayerStats.get_child(0)
	check(toast.panel.visible and toast._queue.size() > 0, "toasts queued")
	check(toast.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"toast does not intercept input")
	var path: String = "/tmp/wordwoven-stats-%d.cfg" % OS.get_process_id()
	PlayerStats._save_path = path
	PlayerStats._persistence_enabled = true
	check(PlayerStats._save_progress() == OK, "save temporary progress")
	PlayerStats._lifetime = PlayerStats._empty_counters()
	PlayerStats._unlocked.clear()
	PlayerStats.load_progress()
	check(PlayerStats._unlocked.size() == 10, "all unlocks restored")
	check(PlayerStats._progress("alphabet") == 26, "coverage restored")
	RunState.start_new_run()
	encounter()
	cast("normal")
	PlayerStats.mark_debug_assisted()
	var config: ConfigFile = ConfigFile.new()
	check(config.load(path) == OK, "rollback saved")
	check(config.get_value("progress", "words") == 61, "rollback persisted")
	var backup: ConfigFile = ConfigFile.new()
	check(backup.load(path + ".bak") == OK, "rollback backup saved")
	check(backup.get_value("progress", "words") == 61, "backup excludes debug")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[broken")
	file.close()
	PlayerStats.load_progress()
	check(PlayerStats._unlocked.size() == 10, "corrupt primary uses backup")
	# A malformed counter in both copies is preserved and blocks overwrites.
	config.set_value("progress", "words", -1)
	config.save(path)
	config.save(path + ".bak")
	PlayerStats._load_blocked = false
	PlayerStats.load_progress()
	check(PlayerStats._load_blocked, "malformed counters block overwrites")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	PlayerStats._persistence_enabled = false
	_finish()


func _alphabet_counts() -> Dictionary:
	var letters: Dictionary = {}
	for letter: String in PlayerStats.ALPHABET:
		letters[letter] = 1
	return letters


func _finish() -> void:
	print("Player statistics: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
