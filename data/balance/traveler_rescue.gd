extends RefCounted
## Data-driven creative writing. No semantic scoring or UI/run-state mutations.
const Balance = preload("res://data/balance/tuning.gd")
const STORIES_PATH: String = "res://data/balance/traveler_stories.json"
# Session memory deliberately survives new runs; encounter progress stores its own tale.
static var last_story_id: String = ""

static func stories() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(STORIES_PATH))

static func initial_state() -> Dictionary:
	var pool: Array = stories().filter(func(story: Dictionary) -> bool: return story.id != last_story_id)
	if pool.is_empty():
		pool = stories()
	var story: Dictionary = pool.pick_random().duplicate(true)
	last_story_id = story.id
	return {"turn": 0, "value": 0, "words": [], "story": story, "feedback": "My journal froze shut. Help me invent what happened!", "awaiting_next": false}

static func requested_pos(state: Dictionary) -> String:
	return String(state.story.blanks[mini(int(state.turn), state.story.blanks.size() - 1)])

static func story_text(state: Dictionary, distinguish: bool = false) -> String:
	var replacements: Array = []
	for index: int in state.story.blanks.size():
		if index < state.words.size():
			var word: String = state.words[index]
			replacements.append("‹%s›" % word.to_upper() if distinguish else word)
		else:
			replacements.append("[%s]" % WordNet.pos_name(state.story.blanks[index]).to_upper())
	return String(state.story.text).format(replacements)

static func presentation(state: Dictionary, _word: String = "") -> Dictionary:
	var total: int = state.story.blanks.size()
	var pos: String = WordNet.pos_name(requested_pos(state))
	return {"heading": state.story.title, "meter": "Words filled: %d / %d" % [state.turn, total], "maximum": total, "instruction": story_text(state), "preview": "Blank %d / %d: enter a %s%s. Any meaning is welcome!" % [mini(int(state.turn) + 1, total), total, pos, " (base form)" if requested_pos(state) == "v" else ""], "choices": [], "submit": "Add Word"}

static func play(state: Dictionary, word: String, _choice: int) -> void:
	state.words.append(word)
	state.turn += 1
	state.value = state.turn
	state.feedback = "Saved '%s'. The traveler nods as though this explains everything." % word
	state.awaiting_next = not is_finished(state)

static func is_finished(state: Dictionary) -> bool:
	return int(state.turn) >= state.story.blanks.size()

static func outcome(state: Dictionary) -> Dictionary:
	return {"type": "gold", "amount": Balance.TRAVELER_GOLD, "heal_fraction": Balance.TRAVELER_HEAL_FRACTION, "bonus_chance": Balance.TRAVELER_BONUS_CHANCE, "story_title": state.story.title, "story": story_text(state, true), "dialogue": "The traveler laughs. 'Exactly as I remember it. Especially the bits that never happened.'"}
