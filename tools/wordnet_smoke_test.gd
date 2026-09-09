extends SceneTree
## Headless smoke test for the WordNet stack. Loads the database,
## checks validation, parts of speech, lemmatization, and semantic
## similarity, and prints timings. Exits non-zero on failure.
##
## Run from the project root:
##   godot --headless --path . -s res://tools/wordnet_smoke_test.gd

var _failures: int = 0


func _initialize() -> void:
	print("=== WordNet smoke test ===")
	var start_ms: int = Time.get_ticks_msec()
	var reader: WordNetReader = WordNetReader.new()
	var loaded: bool = reader.load_from_dict(
		"res://assets/wordnet/dict"
	)
	var load_ms: int = Time.get_ticks_msec() - start_ms
	print("load ok=%s in %d ms" % [str(loaded), load_ms])
	if not loaded:
		quit(1)
		return
	_test_validation(reader)
	_test_parts_of_speech(reader)
	_test_similarity(reader)
	print("=== %d failure(s) ===" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_validation(reader: WordNetReader) -> void:
	_expect(reader.word_exists("dragon"), "dragon exists")
	_expect(reader.word_exists("running"), "running exists")
	_expect(reader.word_exists("swords"), "swords exists")
	_expect(
		not reader.word_exists("zzxqjy"), "zzxqjy rejected"
	)
	_expect(not reader.word_exists(""), "empty rejected")


func _test_parts_of_speech(reader: WordNetReader) -> void:
	var fiery_pos: Array[String] = reader.parts_of_speech("fiery")
	_expect(fiery_pos.has("a"), "fiery is adjective")
	var run_pos: Array[String] = reader.parts_of_speech("run")
	_expect(run_pos.has("v"), "run is verb")
	_expect(run_pos.has("n"), "run is noun")
	var ran_pos: Array[String] = reader.parts_of_speech("ran")
	_expect(ran_pos.has("v"), "ran lemmatizes to verb run")


func _test_similarity(reader: WordNetReader) -> void:
	var scorer: SemanticScorer = SemanticScorer.new(reader)
	var pairs: Array[Array] = [
		["fire", "fire"],
		["fire", "blaze"],
		["fire", "flame"],
		["fiery", "fire"],
		["fiery", "water"],
		["big", "large"],
		["big", "huge"],
		["dog", "cat"],
		["dog", "sword"],
		["water", "flood"],
		["icy", "frost"],
		["sneaky", "shadow"],
		["feast", "hungry"],
		["sword", "armed"],
		["gold", "greedy"],
		["torch", "dark"],
	]
	for pair: Array in pairs:
		var start_ms: int = Time.get_ticks_msec()
		var result: Dictionary = scorer.score_detailed(
			pair[0], pair[1]
		)
		var elapsed_ms: int = Time.get_ticks_msec() - start_ms
		print("%12s ~ %-10s = %.3f (%s: %s) [%d ms]" % [
			pair[0], pair[1], result["score"],
			result["strategy"], result["detail"], elapsed_ms,
		])
	# Sanity ordering: related pairs must beat unrelated ones.
	var related: float = scorer.similarity("fire", "blaze")
	var unrelated: float = scorer.similarity("dog", "sword")
	_expect(
		related > unrelated,
		"fire~blaze (%.3f) > dog~sword (%.3f)" % [
			related, unrelated
		]
	)
	var cross_pos: float = scorer.similarity("fiery", "fire")
	_expect(
		cross_pos > 0.5,
		"fiery~fire crosses POS (%.3f)" % cross_pos
	)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		print("  FAIL  " + label)
		_failures += 1
