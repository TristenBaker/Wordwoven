class_name WordValidator
extends Node
## Decides whether typed text is a playable word: real dictionary
## word, letters only, long enough, and not already played this
## encounter. Reports a human-readable reason when it is not.

const MINIMUM_LENGTH: int = 2

# Words already accepted this encounter; repeats are rejected to
# push the player toward linguistic variety.
var _played_words: Array[String] = []


func start_encounter() -> void:
	_played_words = []


## Returns {"valid": bool, "reason": String}.
func validate(text: String, required_pos: String = "") -> Dictionary:
	var word: String = text.strip_edges().to_lower()
	if word.length() < MINIMUM_LENGTH:
		return _verdict(false, "Too short")
	for character: String in word:
		if character < "a" or character > "z":
			return _verdict(false, "Letters only")
	if _played_words.has(word):
		return _verdict(false, "Already played this fight")
	if not WordNet.word_exists(word):
		return _verdict(false, "Not in the lexicon")
	if not required_pos.is_empty():
		if not WordNet.parts_of_speech(word).has(required_pos):
			return _verdict(
				false, "Use a %s" % WordNet.pos_name(required_pos)
			)
		if required_pos == "v" and not WordNet.is_base_form(word, "v"):
			return _verdict(false, "Use a base-form verb, such as run")
	return _verdict(true, "")


## Records an accepted word so it cannot be replayed this fight.
func mark_played(word: String) -> void:
	_played_words.append(word.strip_edges().to_lower())


func _verdict(valid: bool, reason: String) -> Dictionary:
	return {"valid": valid, "reason": reason}
