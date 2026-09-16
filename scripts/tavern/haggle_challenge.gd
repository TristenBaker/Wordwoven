class_name HaggleChallenge
extends RefCounted
## Rules for haggling over a recruit: type a dictionary word of the
## displayed part of speech containing the offered letter. Prompts
## are built only from verified solutions, so every offer is solvable.

const DURATION_MSEC: int = 15000
const DISCOUNT: float = 0.2
const CANDIDATE_SAMPLE: int = 12
const PROMPT_POSITIONS: Array[String] = ["n", "v", "a", "r"]


## A prompt {"pos", "letter", "solution"} with a verified solution,
## or an empty dictionary when no part of speech has one.
static func build_prompt(
	letter: String, rng: RandomNumberGenerator
) -> Dictionary:
	var normalized: String = letter.to_lower()
	var positions: Array[String] = PROMPT_POSITIONS.duplicate()
	for index: int in range(positions.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: String = positions[index]
		positions[index] = positions[swap_index]
		positions[swap_index] = held
	for pos: String in positions:
		var solutions: Array[String] = WordNet.words_containing(
			normalized, pos, CANDIDATE_SAMPLE, rng.randi()
		)
		while not solutions.is_empty():
			var index: int = rng.randi_range(0, solutions.size() - 1)
			var solution: String = solutions[index]
			var prompt: Dictionary = {
				"pos": pos, "letter": normalized, "solution": solution,
			}
			if validate(solution, prompt)["valid"]:
				return prompt
			solutions.remove_at(index)
	return {}


## Returns {"valid": bool, "reason": String} for a typed answer.
static func validate(text: String, prompt: Dictionary) -> Dictionary:
	var word: String = text.strip_edges().to_lower()
	var letter: String = String(prompt.get("letter", ""))
	var pos: String = String(prompt.get("pos", ""))
	if letter.is_empty() or pos.is_empty():
		return {"valid": false, "reason": "No challenge is available."}
	var verdict: Dictionary = WordValidator.check_word(word, pos)
	if not verdict["valid"]:
		return verdict
	if not word.contains(letter):
		return {
			"valid": false,
			"reason": "The word must contain %s." % letter.to_upper(),
		}
	return verdict


static func prompt_text(prompt: Dictionary) -> String:
	var pos: String = String(prompt.get("pos", "n"))
	var article: String = "an" if pos in ["a", "r"] else "a"
	var text: String = "Type %s %s containing %s" % [
		article, WordNet.pos_name(pos),
		String(prompt.get("letter", "")).to_upper(),
	]
	if pos == "v":
		text += " (base form)"
	return text


## Price after a won haggle: 10g becomes 8g and 20g becomes 16g.
static func discounted_price(price: int) -> int:
	return int(round(float(price) * (1.0 - DISCOUNT)))
