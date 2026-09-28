# Word Woven

Mad Libs meets a roguelike deckbuilder: spell words for a requested
part of speech, counter the enemy's nature, and hear your exact
words woven into the story of its defeat.
Built with Godot 4.7 (standard build, pure GDScript).

Full design document: [docs/GDD.md](docs/GDD.md).
Code style: [docs/gdscript-style.md](docs/gdscript-style.md).

## The loop

Fight → draw letters → write a noun, base-form verb, adjective,
or adverb as prompted → counter the enemy's tags for bonus damage
→ survive retaliation → read your victory story and choose a free
power → recruit or dismiss letters and hear the bard at the tavern
→ choose the next encounter → defeat the boss.

## Gameplay rules

- Prompts cycle noun → verb → adjective → adverb after accepted
  words, with a different starting position each encounter.
  Rejected words consume no turn. Countering is optional: any
  valid word for the prompt still deals damage.
- Each letter item is attuned to **Fire, Lightning, Water, Ice, Nature,**
  or **Earth**. A word deals a mixture of the drawn letters' elemental
  damage; enemies show elemental weaknesses and resistances. The reward
  choice after each victory includes stacking elemental powers, such as
  Fire Burn and recursive Lightning echoes.
- Start with 18 level-1 vowels/common consonants, 50 HP, and 0g.
  Each drawn letter used in an accepted word gains one level after
  its effects resolve. Duplicate copies level independently.
  Undrawn letters contribute 20% base power and have no elemental or
  leveling effects.
- The tavern offers six distinct recruits, including at least one
  uncommon consonant, once per completed encounter. Offers persist
  on return. Recruitment costs 10g for vowels/common consonants or
  20g for uncommon consonants; dismissal costs 10g and requires at
  least ten letters remain. A meal costs 15g and heals 10 HP.
- Victory gold is 24/32/40/48/56/120g for rat/goblin/myconid/
  skeleton/flying eye/dragon. Each victory, including the boss,
  offers three color-coded powers: Common (white), Uncommon (green),
  Rare (blue), and Legendary (purple). Powers stack. Common powers
  scale elemental damage; Uncommon powers unlock Burn, Lightning
  echoes, Water healing, Ice slow, Nature poison, and Earth guard;
  Rare powers amplify those builds; Legendary powers reshape a run.
- Counters such as **water** against **fiery** score 1.0; their
  synonyms score 0.9. Matching-tag and unrelated words score zero.
  The semantic multiplier is `0.5 + 1.5 * counter_score`, plus
  Tome bonuses. The victory story includes every accepted word,
  grouped by its prompted part of speech.

## Setup

1. Install [Godot 4.7+](https://godotengine.org/) (standard
   build; .NET is not needed).
2. Open the project in Godot and run.

The first launch parses WordNet (~1 s) and caches a binary index
in `user://`; later launches load in well under a second.

## Architecture

- `scripts/nlp/` — WordNet reader (index/data file parsing,
  lemmatization), generic semantic scorer, thematic/antonym counter
  scorer, and Mad Libs storyteller. NLP is exposed through WordNet.
- `scripts/autoloads/` — `WordNet` (the single game-facing NLP
  interface), `RunState` (run data), `EventBus` (signals).
- `scripts/word/` — letter stats, deck manager, word validator.
- `scripts/combat/` — damage calculator, enemy factory, enemy,
  combat controller (turn state machine).
- `scripts/tavern/` — recruitment, dismissal, meals, tavern UI.
- `data/` — enemy affinities, quality-based powers, and thematic counter definitions (JSON).
- `tools/` — headless test scenes (see below).

## Tests

Headless checks run from the project root:

```
godot --headless --editor --recovery-mode --path . --import
godot --headless --path . -s res://tools/wordnet_smoke_test.gd
godot --headless --path . res://tools/combat_sim_test.tscn
godot --headless --path . res://tools/tavern_sim_test.tscn
```

Import first after pulling new scripts to refresh Godot's class
and resource caches. The suites cover generic WordNet similarity,
all enemy-tag counters, POS validation, fixed-hand combat,
leveling, stories, recruitment, paid dismissal, and power rewards.

## Debug tools

F12 toggles the developer overlay in-game: full damage-math
breakdown of the last word, a live counter tester, gold and
healing cheats, skip-to-tavern, and forcing enemy tags or drawn
letters.
