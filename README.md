# Word Woven

Mad Libs meets a roguelike deckbuilder: spell words for a requested
part of speech, counter the enemy's nature, and hear your exact
words woven into the story of its defeat.
Built with Godot 4.7 (standard build, pure GDScript).

Full design document: [docs/GDD.md](docs/GDD.md).
Code style: [docs/gdscript-style.md](docs/gdscript-style.md).
Adding enemies, abilities, relics, and effects:
[docs/EXTENDING.md](docs/EXTENDING.md).

## The loop

Set up the encounter (foe, one adjective, previewed terrain) → draw
letters → write a noun, base-form verb, adjective, or adverb as
prompted, quickly for a swift bonus → counter the enemy's tag for
bonus damage → survive retaliation and enemy abilities → read your
victory story and choose a free relic → recruit, haggle, or dismiss
letters and hear the bard at the tavern → set up the next encounter
→ defeat the boss.

## Gameplay rules

- Prompts cycle noun → verb → adjective → adverb after accepted
  words, with a different starting position each encounter.
  Rejected words consume no turn. Countering is optional: any
  valid word for the prompt still deals damage.
- Vowels **AEIOU** are Healers (heal HP equal to level), common
  consonants **BCDFGHLMNPRST** are Warriors (add twice their level
  in damage power), and uncommon consonants **JKQVWXYZ** are Rogues
  (earn twice their level in gold).
- Start with 18 level-1 vowels/common consonants, 50 HP, and 0g.
  Each drawn letter used in an accepted word gains one level after
  its effects resolve. Duplicate copies level independently.
  Undrawn letters contribute 20% base power and have no class or
  leveling effects.
- The tavern offers six distinct recruits, including at least one
  uncommon consonant, once per completed encounter. Offers persist
  on return. Recruitment costs 10g for vowels/common consonants or
  20g for uncommon consonants; dismissal costs 10g and requires at
  least ten letters remain. A meal costs 15g and heals 10 HP.
- Victory gold is 24/32/40/48/56/120g for rat/goblin/myconid/
  skeleton/flying eye/dragon. Each victory, including the boss,
  requires one free relic choice before continuing. Copies stack:
  Quill of Fortune grants +5g on future victories; Iron Bookmark
  grants +10 maximum HP and heals 10; Tome of Echoes adds 0.12 to
  the semantic damage multiplier per copy. Traveler's Satchel grants
  +3g; Lantern of Insight upgrades counter
  synonyms to direct-counter strength; and Red Thread draws one extra
  letter into every combat hand. Additional copies stack where applicable.
- Every encounter, including the first and the boss, starts with
  setup: pick one of the stage's foes, type one supported adjective
  (listed on screen) as its only counterable tag, and confirm. Each
  option previews its environment, rolled once: normal, or icy with a
  one-in-three chance.
- The Giant Rat poisons one random unpoisoned hand tile after each
  attack you survive; poison lasts until combat ends and halves that
  tile's damage, healing, and gold. Halved healing and gold are summed
  before rounding down once per word. The Goblin steals one random hand
  tile after each attack you survive. The tile is not replaced right
  away and returns when the Goblin dies; your party never loses it.
  Enemies apply nothing before their first attack.
- On icy ground, two random hand tiles (or all, if fewer) freeze at
  the start of each turn, and the previous turn's ice thaws first. A
  frozen tile is still spent but gives only 20% of its base letter
  power, with no class effect and no level gain.
- Casting an accepted word within 12 seconds of your turn starting
  deals ×1.5 final damage; healing and gold are unchanged. Rejected
  words neither reset the timer nor use the turn.
- Click hand tiles and confirm to redraw them for 2g each, once per
  turn. Redrawing never triggers an attack, class effects, or leveling.
  The same tiles cannot come straight back, and nothing is charged if
  there are not enough replacement tiles.
- Each recruit offer allows one free 15-second haggle: type a
  dictionary word of the shown part of speech (base-form verbs)
  containing the offered letter to cut its price by 20% (10g → 8g,
  20g → 16g). Timing out or leaving uses up the attempt. Buying is
  still a separate confirmed purchase.
- Gold purchases, relic choices, and encounter entry ask for
  confirmation, show the exact cost or consequence, and are checked
  again when confirmed. The battle log can be collapsed.
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
  encounter planner and conditions, speed timer, environment catalog,
  combat controller (turn state machine).
- `scripts/combat/abilities/` — enemy and environment ability handlers
  and their registry.
- `scripts/combat/relics/` — cached relic catalog and effect handlers.
- `scripts/tavern/` — recruitment, haggling, dismissal, meals, tavern UI.
- `scripts/ui/` — screens plus the reusable confirmation dialog and
  typing challenge.
- `data/` — enemy, environment, relic, and thematic counter
  definitions (JSON).
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
all enemy-tag counters, and POS validation. The combat suite uses
fixed enemies, decks, seeded generators, and a manual clock to cover
letter conditions, abilities, the swift timer, redraws, encounter
setup, relic catalog stacking, and confirmations. The tavern suite
covers recruitment, dismissal, meals, stories, haggling, and purchase
confirmations.

## Debug tools

F12 toggles the developer overlay in-game: full damage-math
breakdown of the last word, a live counter tester, gold and
healing cheats, skip-to-tavern, and forcing enemy tags or drawn
letters.
