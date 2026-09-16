class_name EconomySystem
extends Node
## Tavern transactions for recruiting letters, paid dismissals, and meals.
## Offers belong to the run so revisiting the tavern cannot reroll stock,
## haggling prompts, attempts, or discounts.

const RECRUIT_COUNT: int = 6
const RECRUIT_PRICE: int = 10
const RARE_RECRUIT_PRICE: int = 20
const DROP_PRICE: int = 10
const MIN_DECK_SIZE: int = 10
const MEAL_PRICE: int = 15
const MEAL_HEAL: int = 10

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# The offer whose haggle this tavern visit started; a reopened tavern
# starts with none, so an interrupted attempt cannot be won later.
var _active_haggle: int = -1


func _init() -> void:
	rng.randomize()


func _ready() -> void:
	ensure_recruitment_offers()


## A completed encounter brings six distinct recruits, including a rogue.
func ensure_recruitment_offers() -> void:
	var latest: int = 0
	for encounter: int in RunState.completed_encounters:
		latest = maxi(latest, encounter)
	if RunState.recruitment_encounter == latest:
		_ensure_haggle_fields()
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
	_ensure_haggle_fields()


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


## The current price of one offer, including a won haggle discount.
func offer_price(offer_index: int) -> int:
	if not _valid_offer(offer_index):
		return -1
	var offer: Dictionary = RunState.recruitment_stock[offer_index]
	var price: int = recruit_price(offer["letter"])
	if price >= 0 and offer.get("discounted", false):
		return HaggleChallenge.discounted_price(price)
	return price


## Each offer can be bought once; owned copies remain separate characters.
func buy_recruit(offer_index: int) -> bool:
	ensure_recruitment_offers()
	if not _valid_offer(offer_index):
		return false
	var offer: Dictionary = RunState.recruitment_stock[offer_index]
	if offer["purchased"]:
		return false
	var letter: String = offer["letter"]
	var price: int = offer_price(offer_index)
	if price < 0 or not RunState.spend_gold(price):
		return false
	offer["purchased"] = true
	RunState.deck.append(LetterStats.create(letter))
	EventBus.emit_deck_changed()
	return true


## True when the offer still has its one free haggle attempt.
func can_haggle(offer_index: int) -> bool:
	if not _valid_offer(offer_index):
		return false
	var offer: Dictionary = RunState.recruitment_stock[offer_index]
	return not offer["purchased"] \
			and not offer.get("haggle_attempted", true) \
			and not Dictionary(offer.get("haggle_prompt", {})).is_empty()


## Consumes the attempt and returns its prompt, or {} if unavailable.
func begin_haggle(offer_index: int) -> Dictionary:
	if _active_haggle >= 0 or not can_haggle(offer_index):
		return {}
	var offer: Dictionary = RunState.recruitment_stock[offer_index]
	offer["haggle_attempted"] = true
	_active_haggle = offer_index
	return Dictionary(offer["haggle_prompt"]).duplicate()


## Checks an answer for the haggle in progress.
func check_haggle_answer(text: String, offer_index: int) -> Dictionary:
	if offer_index != _active_haggle or not _valid_offer(offer_index):
		return {"valid": false, "reason": "This haggle has ended."}
	var offer: Dictionary = RunState.recruitment_stock[offer_index]
	return HaggleChallenge.validate(text, offer["haggle_prompt"])


## Ends the haggle in progress; success applies the discount.
## Returns whether a discount was applied.
func finish_haggle(offer_index: int, success: bool) -> bool:
	if offer_index != _active_haggle:
		return false
	_active_haggle = -1
	if not success or not _valid_offer(offer_index):
		return false
	var offer: Dictionary = RunState.recruitment_stock[offer_index]
	if offer["purchased"]:
		return false
	offer["discounted"] = true
	return true


func is_haggling() -> bool:
	return _active_haggle >= 0


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


func _valid_offer(offer_index: int) -> bool:
	return offer_index >= 0 \
			and offer_index < RunState.recruitment_stock.size()


# Offers gain their prompt once the lexicon is available; prompts that
# already exist are never rebuilt.
func _ensure_haggle_fields() -> void:
	if not WordNet.is_ready:
		return
	for offer: Dictionary in RunState.recruitment_stock:
		if offer.has("haggle_prompt"):
			continue
		offer["haggle_prompt"] = HaggleChallenge.build_prompt(
			offer["letter"], rng
		)
		offer["haggle_attempted"] = false
		offer["discounted"] = false
