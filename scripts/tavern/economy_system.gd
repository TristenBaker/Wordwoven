class_name EconomySystem
extends Node
## Tavern transactions for recruiting letters, paid dismissals, and meals.
## Offers belong to the run so revisiting the tavern cannot reroll stock.

const RECRUIT_COUNT: int = 6
const RECRUIT_PRICE: int = 10
const RARE_RECRUIT_PRICE: int = 20
const DROP_PRICE: int = 10
const MIN_DECK_SIZE: int = 10
const MEAL_PRICE: int = 15
const MEAL_HEAL: int = 10


func _ready() -> void:
	ensure_recruitment_offers()


## A completed encounter brings six distinct recruits, including a rogue.
func ensure_recruitment_offers() -> void:
	var latest: int = 0
	for encounter: int in RunState.completed_encounters:
		latest = maxi(latest, encounter)
	if RunState.recruitment_encounter == latest:
		return
	var candidates: Array[String] = []
	var rares: Array[String] = []
	for letter: String in LetterStats.BASE_POWER:
		candidates.append(letter)
	for letter: String in LetterStats.UNCOMMON_CONSONANTS:
		rares.append(letter)
	var rare: String = rares.pick_random()
	candidates.erase(rare)
	candidates.shuffle()
	var offered: Array[String] = [rare]
	for index: int in range(RECRUIT_COUNT - 1):
		offered.append(candidates[index])
	offered.sort()
	RunState.recruitment_stock = []
	for letter: String in offered:
		RunState.recruitment_stock.append({
			"letter": letter,
			"purchased": false,
		})
	RunState.recruitment_encounter = latest


func recruitment_offers() -> Array[Dictionary]:
	ensure_recruitment_offers()
	return RunState.recruitment_stock.duplicate(true)


func recruit_price(letter: String) -> int:
	var normalized: String = letter.to_lower()
	if not LetterStats.BASE_POWER.has(normalized):
		return -1
	if LetterStats.UNCOMMON_CONSONANTS.contains(normalized):
		return RARE_RECRUIT_PRICE
	return RECRUIT_PRICE


## Each offer can be bought once; owned copies remain separate characters.
func buy_recruit(offer_index: int) -> bool:
	ensure_recruitment_offers()
	if offer_index < 0 or offer_index >= RunState.recruitment_stock.size():
		return false
	var offer: Dictionary = RunState.recruitment_stock[offer_index]
	if offer["purchased"]:
		return false
	var letter: String = offer["letter"]
	var price: int = recruit_price(letter)
	if price < 0 or not RunState.spend_gold(price):
		return false
	offer["purchased"] = true
	RunState.deck.append(LetterStats.create(letter))
	EventBus.emit_deck_changed()
	return true


## Dismissals cost gold and preserve a minimum party of ten letters.
func drop_letter(stats: LetterStats) -> bool:
	if RunState.deck.size() <= MIN_DECK_SIZE:
		return false
	if not RunState.deck.has(stats):
		return false
	if not RunState.spend_gold(DROP_PRICE):
		return false
	RunState.deck.erase(stats)
	EventBus.emit_deck_changed()
	return true


func buy_meal() -> bool:
	if RunState.player_health >= RunState.player_max_health:
		return false
	if not RunState.spend_gold(MEAL_PRICE):
		return false
	RunState.heal_player(MEAL_HEAL)
	return true
