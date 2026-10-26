extends RefCounted
## Authoritative numeric tuning and content tables. Restart the run after editing.

const FORGE_INGREDIENT_COUNT: int = 3
const FORGE_LEVEL_GAIN: int = 1
const WORD_GAME_GUESSES: int = 6
const WORD_GAME_LENGTH: int = 5
const ENEMY_STAGES_PER_TIER: float = 2.0
const ENEMY_REGULAR_MAX_TIER: int = 3
const TUNDRA_STARTER_ENEMY: String = "frostfang_wolf"
const TUNDRA_BOSS_ENEMY: String = "frost_wyrm"
const LETTER_LEVELS_PER_USE: int = 1

# RUN_STATE
const RUN_STATE_STARTING_HEALTH: int = 50
const RUN_STATE_STARTING_GOLD: int = 0
const RUN_STATE_ENCOUNTERS_PER_RUN: int = 6

# COMBAT_CONTROLLER
const COMBAT_CONTROLLER_PROMPT_ORDER: Array[String] = ["n", "v", "a", "r"]

# DAMAGE_CALCULATOR
const DAMAGE_CALCULATOR_UNDRAWN_POWER_FACTOR: float = 0.2
const DAMAGE_CALCULATOR_LENGTH_BONUS_STEP: float = 0.1
const DAMAGE_CALCULATOR_SPEED_BONUS_DURATION: float = 20.0
const DAMAGE_CALCULATOR_SPEED_MULTIPLIER_MAX: float = 1.5
const DAMAGE_CALCULATOR_SPEED_MULTIPLIER_MIN: float = 1.0
const DAMAGE_CALCULATOR_POS_MULTIPLIERS: Dictionary[String, float] = {
	"v": 1.25,
	"a": 1.15,
	"r": 1.1,
	"n": 1.0,
}
const DAMAGE_CALCULATOR_SEMANTIC_MULTIPLIER_MIN: float = 0.5
const DAMAGE_CALCULATOR_SEMANTIC_MULTIPLIER_MAX: float = 2.0
const DAMAGE_CALCULATOR_TOME_MULTIPLIER_BONUS: float = 0.12
const DAMAGE_CALCULATOR_LANTERN_MULTIPLIER_BONUS: float = 0.08

# ENEMY_FACTORY
const ENEMY_FACTORY_BOSS_TIER: int = 4
const ENEMY_FACTORY_TUNDRA_REGULARS: Array[String] = [
	"glacier_bear", "frozen_revenant", "winter_wraith", "tundra_behemoth",
]
const ENEMY_FACTORY_ENDLESS_HEALTH_PER_WAVE: int = 9
const ENEMY_FACTORY_ENDLESS_ATTACK_WAVE_INTERVAL: int = 2
const ENEMY_FACTORY_ENDLESS_GOLD_BASE: int = 3
const ENEMY_FACTORY_ENDLESS_GOLD_PER_WAVE: int = 2

# RELIC_SYSTEM
const RELIC_SYSTEM_QUALITY_WEIGHTS: Dictionary[String, int] = {
	"common": 60,
	"uncommon": 20,
	"rare": 15,
	"legendary": 5,
}

# TUNDRA_COLD
const TUNDRA_COLD_FREEZE_EVERY: int = 3
const TUNDRA_COLD_HEAT_PER_WORD: int = 1
const TUNDRA_COLD_MAX_HEAT: int = 5
const TUNDRA_COLD_THAW_COST: int = 2
const TUNDRA_COLD_MIN_USABLE: int = 5

# ICE_FISHING_CONTROLLER
const ICE_FISHING_CONTROLLER_HOLE_COUNT: int = 3
const ICE_FISHING_CONTROLLER_WORD_SECONDS: float = 8.0
const ICE_FISHING_CONTROLLER_WARM_SEEDS: Array[String] = [
	"warm", "hot", "heated", "sunny", "summer", "fire",
]
const ICE_FISHING_CONTROLLER_FISH_TABLE: Array[Dictionary] = [
	{
		"name": "Frost Minnow",
		"rarity": "Common",
		"weight": 50,
		"words": 1,
		"item_level": 1,
		"color": Color("b7d8e8"),
	},
	{
		"name": "Snowperch",
		"rarity": "Uncommon",
		"weight": 28,
		"words": 2,
		"item_level": 2,
		"color": Color("79d291"),
	},
	{
		"name": "Glacial Trout",
		"rarity": "Rare",
		"weight": 14,
		"words": 3,
		"item_level": 3,
		"color": Color("67a9ff"),
	},
	{
		"name": "Aurora Pike",
		"rarity": "Epic",
		"weight": 6,
		"words": 4,
		"item_level": 4,
		"color": Color("c48cff"),
	},
	{
		"name": "Icebound Leviathan",
		"rarity": "Legendary",
		"weight": 2,
		"words": 5,
		"item_level": 5,
		"color": Color("ffca55"),
	},
]

# ECONOMY_SYSTEM
const ECONOMY_SYSTEM_RECRUIT_COUNT: int = 6
const ECONOMY_SYSTEM_LETTER_DEALER_OFFER_COUNT: int = 6
const ECONOMY_SYSTEM_RECRUIT_PRICE: int = 10
const ECONOMY_SYSTEM_RARE_RECRUIT_PRICE: int = 20
const ECONOMY_SYSTEM_DROP_PRICE: int = 10
const ECONOMY_SYSTEM_MIN_DECK_SIZE: int = 10
const ECONOMY_SYSTEM_MEAL_PRICE: int = 15
const ECONOMY_SYSTEM_MEAL_HEAL: int = 10

# FORGE_ROOM
const FORGE_ROOM_BASE_SUCCESS_CHANCE: float = 0.70

# WORD_GAME
const WORD_GAME_WORDS: Array[String] = ["ember", "frost", "quill", "rhyme", "stone", "thorn", "tidal", "gloom", "spark", "flame"]

# ENCOUNTER_SELECT
const ENCOUNTER_SELECT_CHOICE_COUNT: int = 2

# DECK_MANAGER
const DECK_MANAGER_HAND_SIZE: int = 8

# LETTER_STATS
const LETTER_STATS_VOWELS: String = "aeiou"
const LETTER_STATS_COMMON_CONSONANTS: String = "bcdfghlmnprst"
const LETTER_STATS_UNCOMMON_CONSONANTS: String = "jkqvwxyz"
const LETTER_STATS_BASE_POWER: Dictionary[String, int] = {
	"a": 1, "b": 3, "c": 3, "d": 2, "e": 1, "f": 4, "g": 2,
	"h": 4, "i": 1, "j": 8, "k": 5, "l": 1, "m": 3, "n": 1,
	"o": 1, "p": 3, "q": 10, "r": 1, "s": 1, "t": 1, "u": 1,
	"v": 4, "w": 4, "x": 8, "y": 4, "z": 10,
}
const LETTER_STATS_LEVEL_POWER_STEP: float = 0.25

# WORD_VALIDATOR
const WORD_VALIDATOR_MINIMUM_LENGTH: int = 2
const DROP_MAX_LEVEL: int = 5
const DROP_LEVEL_OFFSET: int = 1
const STARTER_COUNT: int = 10
const DEALER_PRICE_PER_LEVEL: int = 5
const HEAVY_POWER: float = 4.0
const KEEN_MULTIPLIER: float = 2.0
const ELEMENT_CAST_GOLD: int = 1
const LENGTH_BONUS_BASE: int = 3
const LIGHTNING_MAX_PROCS: int = 6
const TUNDRA_HEALTH_GROWTH: int = 6
const TUNDRA_GOLD_GROWTH: int = 6
const TUNDRA_ATTACK_GROWTH: int = 1
const TUNDRA_GROWTH_START: int = 2
const TUNDRA_GROWTH_CAP: int = 3
const FORGE_MAX_QUALITY_SCORE: float = 16.0
const FORGE_MULTIPLIER_MIN: float = 0.80
const FORGE_MULTIPLIER_MAX: float = 1.30
const TREASURE_MID_SCORE: int = 8
const TREASURE_HIGH_SCORE: int = 15
const TREASURE_GOLD: Array[int] = [10, 22, 38]
const FROSTBITE_FREEZE_EVERY: int = 2
const FROSTBITE_HEAT_PER_WORD: int = 2
const FISHING_SEMANTIC_THRESHOLD: float = 0.40
const FISHING_MIN_LENGTH: int = 3
const FISHING_MAX_LENGTH: int = 14

# Forge recipe descriptions and outputs.
const FORGE_RECIPES: Array[Dictionary] = [
		{
			"id": "perfect_copy",
			"name": "Perfect Copy",
			"description": "%d same letter · same level · same element" % FORGE_INGREDIENT_COUNT,
			"result": "Same tile",
		},
		{
			"id": "elemental_shuffle",
			"name": "Elemental Shuffle",
			"description": "%d same letter · same level · different elements" % FORGE_INGREDIENT_COUNT,
			"result": "Same letter · random element",
		},
		{
			"id": "letter_shuffle",
			"name": "Letter Shuffle",
			"description": "%d different letters · same level · same element" % FORGE_INGREDIENT_COUNT,
			"result": "Random letter · same element",
		},
		{
			"id": "wild_transmutation",
			"name": "Wild Transmutation",
			"description": "%d different letters · same level · different elements" % FORGE_INGREDIENT_COUNT,
			"result": "Random letter · random element",
		},
	]
