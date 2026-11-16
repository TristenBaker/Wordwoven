class_name TundraEvents
extends RefCounted
## Optional rewards use existing RunState APIs; combat-local systems remain untouched.
const Balance = preload("res://data/balance/tuning.gd")
const DATA_PATH: String = "res://data/balance/tundra_events.json"
const IDS: Array[String] = ["frozen_traveler", "treasure_chest"]

static func definition(id: String) -> Dictionary:
	var catalogue: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return catalogue.get(id, {}).duplicate(true)

static func frame_texture(data: Dictionary, frame: int) -> AtlasTexture:
	var sheet: Texture2D = load(String(data.texture))
	var width: int = int(data.frame_width)
	var start: int = frame * width
	var actual_width: int = mini(width, sheet.get_width() - start)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(start, 0, actual_width, sheet.get_height())
	# The chest's last cell is one pixel shorter; transparent padding keeps every
	# displayed frame the same size without resampling or editing the source PNG.
	atlas.margin = Rect2(0, 0, width - actual_width, 0)
	atlas.filter_clip = true
	return atlas

static func rules(id: String) -> GDScript:
	match id:
		"frozen_traveler": return preload("res://data/balance/traveler_rescue.gd")
		"treasure_chest": return preload("res://data/balance/chest_locks.gd")
	return null

static func progress(id: String) -> Dictionary:
	if not RunState.optional_encounter_progress.has(id):
		RunState.optional_encounter_progress[id] = rules(id).initial_state()
	return RunState.optional_encounter_progress[id]

static func requested_pos(id: String) -> String:
	if id == "frozen_traveler":
		return rules(id).requested_pos(progress(id))
	return String(definition(id).pos)

## Validate at the service boundary as well as providing human-readable feedback.
static func submit_word(id: String, text: String, choice: int = -1) -> Dictionary:
	if not RunState.optional_encounter_available(id) or RunState.pending_optional_encounter != id:
		return {"valid": false, "reason": "This encounter is already complete."}
	if not WordNet.is_ready:
		return {"valid": false, "reason": "The lexicon is warming up. Try again in a moment."}
	var word: String = text.strip_edges().to_lower()
	var validator := WordValidator.new()
	var verdict: Dictionary = validator.validate(word, requested_pos(id))
	validator.free()
	if not verdict.valid:
		return verdict
	var state: Dictionary = progress(id)
	var game: GDScript = rules(id)
	if game.is_finished(state) or state.awaiting_next:
		return {"valid": false, "reason": "Continue to the next round first."}
	game.play(state, word, choice)
	return {"valid": true, "reason": "", "result": complete(id) if game.is_finished(state) else {}}

static func next_round(id: String) -> void:
	if RunState.pending_optional_encounter == id and RunState.optional_encounter_available(id):
		progress(id).awaiting_next = false

## Rewards derive only from stored, completed gameplay; callers cannot supply a score.
static func complete(id: String, skipped: bool = false) -> Dictionary:
	if not RunState.optional_encounter_available(id) or RunState.pending_optional_encounter != id:
		return {}
	var state: Dictionary = progress(id)
	if not skipped and not rules(id).is_finished(state):
		return {}
	var result: Dictionary = {"skipped": skipped, "words": state.words.duplicate(), "word": "", "dialogue": "You leave the mystery for another adventurer.", "reward": "No reward.", "score": state.value}
	if not state.words.is_empty():
		result.word = state.words[-1]
	# Claim before emitting gold signals, preventing re-entrant and double rewards.
	RunState.optional_encounters[id] = result
	if not skipped:
		var earned: Dictionary = rules(id).outcome(state)
		result.dialogue = "%s\n%s" % [state.feedback, earned.dialogue]
		if earned.has("story"):
			result.story = earned.story
			result.story_title = earned.story_title
			result.dialogue = "%s\n\n%s\n\n%s" % [earned.story_title, earned.story, earned.dialogue]
		result.reward = _apply_rewards(earned)
	return result.duplicate(true)

## One settlement path for both side quests, called only after the claim is stored.
static func _apply_rewards(earned: Dictionary) -> String:
	var messages: Array[String] = []
	var healing: int = ceili(RunState.player_max_health * float(earned.get("heal_fraction", 0.0)))
	if healing > 0:
		var before: int = RunState.player_health
		RunState.heal_player(healing)
		messages.append("Restored %d HP." % (RunState.player_health - before))
	var gold: int = int(earned.amount)
	if gold > 0:
		RunState.add_gold(gold)
		messages.append("Found %d gold." % gold)
	if randf() < float(earned.get("bonus_chance", 0.0)):
		var item: LetterStats = RunState.rolled_letter_drop_at_level(Balance.SIDE_QUEST_BONUS_LETTER_LEVEL)
		if RunState.use_itemized_letters:
			RunState.add_letter_item(item)
		else:
			RunState.deck.append(item)
			EventBus.emit_deck_changed()
		messages.append("Bonus: level %d letter %s!" % [item.level, item.letter.to_upper()])
	return " ".join(messages) if not messages.is_empty() else "No reward."
