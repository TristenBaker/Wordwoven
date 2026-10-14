# Game balance

Make gameplay balance changes in this directory. Values were relocated without
changing the current balance. Restart the game/run after editing; this is not a
live-reload system.

| File | What to change |
| --- | --- |
| `tuning.gd` | Starting health/gold, run length, starter count, letter power and leveling, hand size, damage multipliers, quick-cast timing, loot level caps, enemy growth, rarity weights, shop prices, forge odds, treasure rewards, cold rules, fishing tables and word-game limits |
| `enemies.json` | Enemy health, attack, gold, tiers, tags and elemental affinities |
| `relics.json` | Power effects, amounts, rarity and descriptions |
| `tag_counters.json` | Curated words that counter each enemy tag |
| `chameleon_tags.json` | Tag rotations for chameleon enemies |
| `tundra_events.json` | Optional encounter metadata and prompts |
| `encounter_modifier.gd` | Fate catalog, stat multipliers and effect descriptions |
| `encounter_modifier_runtime.gd` | Behavioral fate bonuses, limits and retaliation cadence |
| `fate_classifier.gd` | Fate concepts, confidence and margin thresholds |
| `chest_locks.gd` | Lock answer pools, guesses, rewards and their explanatory text |
| `traveler_rescue.gd` | Supply categories, warmth gains, rescue thresholds and healing |
| `portal_stabilization.gd` | Adverb categories, stability gains, goals and rewards |
| `counter_scorer.gd`, `semantic_scorer.gd` | WordNet scoring rules and thresholds |

The small encounter/scoring rule modules live here intentionally: their formulas
and player-facing explanations are part of their balance. Update descriptions
along with their associated values. UI layout, animation timings, dictionary
assets, and transient run state remain in their existing locations.

Scripts elsewhere reference `tuning.gd`; their public constants are aliases for
compatibility, not additional settings. Do not replace those aliases with numbers.
New gameplay tuning should be added here, not embedded in a controller.

Constraints when tuning:

- Counts, timer durations and divisors must be positive. Starter count cannot
  exceed the alphabet size, and recruitment counts cannot exceed their pools.
- Word-game answers must match `WORD_GAME_LENGTH`.
- Forge descriptions derive their ingredient count from `FORGE_INGREDIENT_COUNT`.
  Recipes still require all ingredients to match the rule.
- Enemy catalogs and the available Tundra roster must support the chosen run
  length. Changing run length alone does not author additional enemies.
- Rarity weights are relative weights. Keep at least one positive eligible
  weight; multiplier and probability changes should respect their callers' ranges.
- JSON files also contain presentation metadata; preserve resource paths and IDs.

After changes, import with Godot 4.7+ and run `tools/balance_test.tscn` for
baseline balance integration (update its expected outcomes for intentional balance
changes). Also run `tundra_minigames_test`, `encounter_modifier_test`,
`fate_classifier_test`, `frozen_letters_test`, and `quick_cast_test` in `tools/`.
Some older scene tests assume superseded UI nodes/APIs and need separate updates.
