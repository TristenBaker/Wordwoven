class_name HangmanRules
extends RefCounted

const ALPHABET := "abcdefghijklmnopqrstuvwxyz"
const LENGTH_BANDS: Array[Vector2i] = [
	Vector2i(2, 6), Vector2i(7, 9), Vector2i(10, 0),
]


static func tier_for_depth(depth: int) -> int:
	return clampi((depth - 2) / 2, 0, 2)


static func new_puzzle(depth: int, tier_override: int = -1) -> Dictionary:
	var tier: int = tier_for_depth(depth) if tier_override < 0 else clampi(tier_override, 0, LENGTH_BANDS.size() - 1)
	var band: Vector2i = LENGTH_BANDS[tier]
	var word: String = WordNet.random_combat_word(band.x, band.y)
	if word.is_empty():
		return {}
	var missing_count: int = mini(word.length(), maxi(tier + 2, int(ceil(word.length() * 0.35))))
	var positions: Array[int] = []
	for index: int in word.length():
		positions.append(index)
	positions.shuffle()
	positions.resize(missing_count)
	positions.sort()
	var hand: Array[String] = []
	for index: int in positions:
		hand.append(word[index])
	var decoy_pool: Array[String] = []
	for letter: String in ALPHABET:
		if not word.contains(letter):
			decoy_pool.append(letter)
	decoy_pool.shuffle()
	for index: int in mini(3 + tier * 2, decoy_pool.size()):
		hand.append(decoy_pool[index])
	hand.sort()
	var default_time: float = 20.0
	return {
		"word": word, "missing": positions, "hand": hand,
		"seconds": default_time / float(tier + 1),
		"reward_count": 2 + tier, "reward_level": 1 + tier,
		"tier": tier,
	}


static func expected_letters(puzzle: Dictionary) -> String:
	var answer := ""
	for index: int in puzzle.missing:
		answer += String(puzzle.word)[index]
	return answer
