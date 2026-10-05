class_name ForgeSystem
extends RefCounted
## Centralized forge recipes. The UI only supplies selected item tiles and a
## word-quality result; new recipes can be added here without changing it.

const ELEMENTS: Array[int] = [
	LetterStats.Element.FIRE,
	LetterStats.Element.LIGHTNING,
	LetterStats.Element.WATER,
	LetterStats.Element.ICE,
	LetterStats.Element.NATURE,
	LetterStats.Element.EARTH,
]


func rules() -> Array[Dictionary]:
	return [
		{
			"id": "perfect_copy",
			"name": "Perfect Copy",
			"description": "3 same letter · same level · same element",
			"result": "Same tile",
		},
		{
			"id": "elemental_shuffle",
			"name": "Elemental Shuffle",
			"description": "3 same letter · same level · different elements",
			"result": "Same letter · random element",
		},
		{
			"id": "letter_shuffle",
			"name": "Letter Shuffle",
			"description": "3 different letters · same level · same element",
			"result": "Random letter · same element",
		},
		{
			"id": "wild_transmutation",
			"name": "Wild Transmutation",
			"description": "3 different letters · same level · different elements",
			"result": "Random letter · random element",
		},
	]


func matching_rule(items: Array[LetterStats]) -> Dictionary:
	if items.size() != 3:
		return {}
	var same_level: bool = _all_same_level(items)
	var same_letter: bool = _all_same_letter(items)
	var same_element: bool = _all_same_element(items)
	var different_letters: bool = _all_different_letters(items)
	var different_elements: bool = _all_different_elements(items)
	if same_letter and same_level and same_element:
		return rules()[0]
	if same_letter and same_level and different_elements:
		return rules()[1]
	if different_letters and same_level and same_element:
		return rules()[2]
	if different_letters and same_level and different_elements:
		return rules()[3]
	return {}


func forge(items: Array[LetterStats], succeeded: bool) -> LetterStats:
	var rule: Dictionary = matching_rule(items)
	if rule.is_empty():
		return null
	var level: int = items[0].level + (1 if succeeded else 0)
	var letter: String = items[0].letter
	var element: int = items[0].element
	match rule["id"]:
		"elemental_shuffle":
			element = ELEMENTS.pick_random()
		"letter_shuffle":
			letter = _random_letter()
		"wild_transmutation":
			letter = _random_letter()
			element = ELEMENTS.pick_random()
	return LetterStats.create_item(letter, element, level)


func _all_same_level(items: Array[LetterStats]) -> bool:
	for item: LetterStats in items:
		if item.level != items[0].level:
			return false
	return true


func _all_same_letter(items: Array[LetterStats]) -> bool:
	for item: LetterStats in items:
		if item.letter != items[0].letter:
			return false
	return true


func _all_same_element(items: Array[LetterStats]) -> bool:
	for item: LetterStats in items:
		if item.element != items[0].element:
			return false
	return true


func _all_different_letters(items: Array[LetterStats]) -> bool:
	var values: Array[String] = []
	for item: LetterStats in items:
		if values.has(item.letter):
			return false
		values.append(item.letter)
	return true


func _all_different_elements(items: Array[LetterStats]) -> bool:
	var values: Array[int] = []
	for item: LetterStats in items:
		if values.has(item.element):
			return false
		values.append(item.element)
	return true


func _random_letter() -> String:
	var letters: Array[String] = []
	for letter: String in LetterStats.BASE_POWER:
		letters.append(letter)
	return letters.pick_random()
