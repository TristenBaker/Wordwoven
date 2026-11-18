extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var stats := LetterStats.create("a")
	stats.appearance_seed = 42
	check(CharacterScars.marks(stats).is_empty(), "New letters have no scars")
	stats.accepted_uses = 4
	check(CharacterScars.marks(stats).is_empty(), "No scar before the fifth use")
	stats.record_word_use("ash", 20)
	var first := CharacterScars.marks(stats)
	check(first.size() == 1 and first[0].site < 3, "First milestone gives a facial scar")
	stats.accepted_uses = 10
	var second := CharacterScars.marks(stats)
	check(second.size() == 2 and second[0] == first[0], "Second scar preserves the first")
	check(second[1].site < 3 and second[1].site != first[0].site, "Later scars use a different facial location")
	stats.accepted_uses = 15
	var third := CharacterScars.marks(stats)
	check(third.size() == 3 and third[0] == first[0] and third[1] == second[1], "Third scar preserves both previous marks")
	check(third[2].site != third[1].site and third[2].site != third[0].site, "Facial locations do not repeat")
	stats.accepted_uses = 200
	stats.level = 20
	stats.body_feature = 2
	stats.face_feature = 1
	check(CharacterScars.marks(stats) == third, "Growth and feature swaps preserve scar identity")
	check(CharacterScars.description(stats).begins_with("Grim"), "Maximum scars give the grimmest expression")
	var path := "res://.godot/scar_test.tres"
	check(ResourceSaver.save(stats, path) == OK, "Scar-bearing character saves")
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LetterStats
	check(CharacterScars.marks(restored) == third, "Scar identity survives resource reload")
	DirAccess.remove_absolute(path)
	var seen_types := {}
	var seen_sites := {}
	for seed_value in 100:
		stats.appearance_seed = seed_value
		var distinct_types := {}
		var distinct_sites := {}
		for mark in CharacterScars.marks(stats):
			check(mark.site >= 0 and mark.site < 3, "Scars stay on the face")
			seen_types[mark.type] = true
			seen_sites[mark.site] = true
			distinct_types[mark.type] = true
			distinct_sites[mark.site] = true
		check(distinct_types.size() == 3, "Each character gets distinct scar shapes")
		check(distinct_sites.size() == 3, "Each character gets distinct facial placements")
	check(seen_types.size() == 3, "All three scar types can appear")
	check(seen_sites.size() == 3, "Both cheeks and the brow can receive scars")
	print("Character scar tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
