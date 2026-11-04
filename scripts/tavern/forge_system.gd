class_name ForgeSystem
extends RefCounted
const Balance = preload("res://data/balance/tuning.gd")
## Recipes determine eligibility and element; offline recognition supplies the letter.

const ELEMENTS: Array[int] = [
	LetterStats.Element.FIRE,
	LetterStats.Element.LIGHTNING,
	LetterStats.Element.WATER,
	LetterStats.Element.ICE,
	LetterStats.Element.NATURE,
	LetterStats.Element.EARTH,
]


func rules() -> Array[Dictionary]:
	return Balance.FORGE_RECIPES.duplicate(true)


func matching_rule(items: Array[LetterStats]) -> Dictionary:
	if items.size() != Balance.FORGE_INGREDIENT_COUNT:
		return {}
	var seen: Array[LetterStats] = []
	for item: LetterStats in items:
		if item == null or seen.has(item):
			return {}
		seen.append(item)
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


func can_extend_rule(selected: Array[LetterStats], candidate: LetterStats) -> bool:
	if candidate == null or selected.has(candidate) or selected.size() >= Balance.FORGE_INGREDIENT_COUNT:
		return false
	if selected.is_empty():
		return true
	for item: LetterStats in selected:
		if item.level != candidate.level:
			return false
	if selected.size() == 1:
		return true
	var completed: Array[LetterStats] = selected.duplicate()
	completed.append(candidate)
	return not matching_rule(completed).is_empty()


func next_step_text(selected: Array[LetterStats]) -> String:
	if selected.is_empty():
		return "Choose %d matching tiles." % Balance.FORGE_INGREDIENT_COUNT
	if selected.size() == 1:
		return "Choose another Level %d tile." % selected[0].level
	if selected.size() == 2:
		return "Choose one highlighted tile."
	var rule: Dictionary = matching_rule(selected)
	return "Recipe ready: %s." % rule.get("name", "Unknown")


func forge(items: Array[LetterStats], recognized_letter: String) -> LetterStats:
	var rule: Dictionary = matching_rule(items)
	var letter := recognized_letter.to_lower()
	if rule.is_empty() or letter.length() != 1 or not LetterStats.BASE_POWER.has(letter):
		return null
	var level: int = items[0].level + Balance.FORGE_LEVEL_GAIN
	var element: int = items[0].element
	match rule["id"]:
		"elemental_shuffle":
			element = ELEMENTS.pick_random()
		"wild_transmutation":
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
