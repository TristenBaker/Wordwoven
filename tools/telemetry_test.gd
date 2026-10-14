extends Node
## Exercise real autoload signals and inspect the flushed event stream.

func _ready() -> void:
	assert(Telemetry._file != null)
	RunState.start_new_run()
	EventBus.emit_encounter_started({"id": "test_enemy"})
	EventBus.emit_word_rejected("private input", "Unknown private input")
	Telemetry._resolve_word({
		"word": "private input", "damage": 12.0,
		"elapsed_seconds": 2.5, "pos": "n",
	})
	EventBus.emit_debug_toggled(true)
	RunState.start_new_run()
	RunState.damage_player(999)
	Telemetry.end_run("lost")
	var source: String = FileAccess.get_file_as_string(Telemetry.log_path)
	assert(not "private input" in source)
	var starts: int = 0
	var endings: Array[String] = []
	var previous: int = 0
	for line: String in source.strip_edges().split("\n"):
		var row: Dictionary = JSON.parse_string(line)
		assert(int(row.sequence) > previous)
		previous = int(row.sequence)
		assert(row.build.has("commit"))
		if row.event == "run_started":
			starts += 1
		if row.event == "run_ended":
			endings.append(row.data.outcome)
	assert(starts == 2)
	assert(endings == ["restarted", "lost"])
	print("TELEMETRY TEST PASSED: ", Telemetry.log_path)
	get_tree().quit()

