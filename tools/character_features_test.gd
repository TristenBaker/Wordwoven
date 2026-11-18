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
	stats.appearance_seed = 12345
	var original := CharacterFeatures.choices(stats)
	stats.level = 20
	stats.accepted_uses = 15
	check(CharacterFeatures.choices(stats) == original, "Progress does not reroll identity")
	check(CharacterFeatures.archetype(LetterStats.Element.FIRE) == 0, "Fire is a warrior")
	check(CharacterFeatures.archetype(LetterStats.Element.EARTH) == 0, "Earth is a warrior")
	check(CharacterFeatures.archetype(LetterStats.Element.WATER) == 1, "Water is a healer")
	check(CharacterFeatures.archetype(LetterStats.Element.NATURE) == 1, "Nature is a healer")
	check(CharacterFeatures.archetype(LetterStats.Element.ICE) == 2, "Ice is a rogue")
	check(CharacterFeatures.archetype(LetterStats.Element.LIGHTNING) == 2, "Lightning is a rogue")
	var hashes := {}
	for kind in 3:
		for body in 3:
			for face in 3:
				var texture := CharacterFeatures.combination(kind, body, face)
				check(texture.get_size() == Vector2(256, 256), "Every pairing has a consistent canvas")
				check(texture == CharacterFeatures.combination(kind, body, face), "Composites are cached")
				var image := texture.get_image()
				check(image.get_pixel(0, 0).a == 0, "Portrait backgrounds remain transparent")
				hashes[image.get_data().hex_encode().sha256_text()] = true
	check(hashes.size() == 27, "All 27 pairings are visually distinct")
	stats.body_feature = 2
	stats.face_feature = 1
	check(CharacterFeatures.choices(stats) == Vector2i(2, 1), "Parts can be independently selected")
	var path := "res://.godot/character_features_test.tres"
	check(ResourceSaver.save(stats, path) == OK, "Feature selections save")
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LetterStats
	check(CharacterFeatures.choices(restored) == Vector2i(2, 1), "Feature selections survive serialization")
	DirAccess.remove_absolute(path)
	PlayerProfile.letter_cosmetics.clear()
	LetterInspector.open_for(stats)
	var inspector := get_tree().get_first_node_in_group("letter_inspector")
	check(inspector._portrait.texture == CharacterFeatures.portrait(stats), "Inspector uses modular portrait")
	PlayerProfile.letter_cosmetics["a"] = "mage"
	LetterInspector.open_for(stats)
	check(inspector._portrait.texture == PlayerProfile.MAGE, "Custom cosmetics still override generated portraits")
	PlayerProfile.letter_cosmetics.clear()
	RunState.use_itemized_letters = false
	RunState.deck.assign([stats])
	RunState.letter_inventory.clear()
	DebugTools._refresh_profile_letters()
	DebugTools._cycle_profile_feature(true)
	check(CharacterFeatures.choices(stats) == Vector2i(0, 1), "Debug body cycling wraps without changing face")
	DebugTools._cycle_profile_feature(false)
	check(CharacterFeatures.choices(stats) == Vector2i(0, 2), "Debug face cycling leaves body unchanged")
	check(stats.accepted_uses == 15 and stats.level == 20, "Feature changes preserve progress")
	inspector.queue_free()
	print("Character feature tests: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
