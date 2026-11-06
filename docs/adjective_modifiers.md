# Adjective combat modifiers

Preparation uses an explicit vocabulary, not semantic similarity or random
selection. The full editable lists live in
[`adjective_vocabulary.gd`](../data/balance/adjective_vocabulary.gd).

Players may type a supported adjective or click an example. WordNet still
validates the adjective. Capitalization and surrounding whitespace are ignored.
A valid unsupported adjective receives an explanation and leaves confirmation
disabled. A Tundra-only word outside Tundra explains its restriction; it never
selects another effect.

The effect preview updates as the player edits. Preparation shows a short
descriptive effect and its gold adjustment; tooltips use the same wording.
Numerical HP, attack, damage and behavioral details remain in the existing
combat display. Enter in the text field only refreshes the preview. **Confirm Modifier** revalidates and caches the selection;
**Enter Combat** uses the existing scene transition. Reopening preparation
preserves a confirmed selection. The combat catalogue, runtime calculations,
active display, and encounter storage are unchanged.

## Vocabulary

There are **288 unique adjectives**, each assigned to exactly one of the
13 existing modifier IDs.

| Modifier ID | Count | Example |
| --- | ---: | --- |
| `titanbound` | 25 | strong |
| `doommarked` | 21 | weak |
| `war_blessed` | 25 | angry |
| `spirit_broken` | 22 | timid |
| `fate_exposed` | 21 | vulnerable |
| `spellwarden` | 24 | protected |
| `drowsy` | 22 | drowsy |
| `clumsy` | 21 | clumsy |
| `long_winded` | 21 | verbose |
| `echo_bound` | 20 | resonant |
| `chameleon` | 23 | fickle |
| `greedy` | 20 | greedy |
| `frostbite_tax` | 23 | frigid (Tundra only) |

All entries passed `WordValidator.validate(word, "a")` against this repository's
WordNet database. Inflected forms are not automatically added to the mapping:
for example, `frailest` is a valid adjective but is intentionally unsupported.
Accepted spelling variants such as `armored` / `armoured` are listed explicitly.

## Excluded candidates

The following 24 candidates failed the game's actual adjective validator, even
when their everyday usage might appear adjectival:

- Recognized in other parts of speech, but not as adjectives: `enfeebled`,
  `cowering`, `warded`, `defended`, `plated`, `secured`, `safeguarded`,
  `blundering`, `stumbling`, `ringing`, `vibrating`, `freezing`, `chill`,
  `hyperborean`.
- Not in the lexicon: `unfortified`, `snoozy`, `klutzy`, `hamfisted`,
  `accidentprone`, `heavyhanded`, `echoric`, `echoey`, `gluttonish`, `subzero`.

The old semantic match `wooden` was intentionally omitted: its material meaning
is more obvious than its figurative connection to clumsiness. Broad candidates
such as `sharp`, `hard`, `light`, and `heavy` were also avoided. The final review
removed `mortal`, `transient`, `penurious`, `boreal`, and `bitter` because their
meaning does not clearly imply the intended effect. `Gassy` and `windy` were
replaced with the more explicitly talkative `blabby` and `talky`.

## Maintaining the system

1. Add a lowercase, single-word adjective to exactly one list. Prefer clear
   everyday meanings over obscure senses. Keep a useful example first.
2. Leave modifier IDs and combat effects in `encounter_modifier.gd` and
   `encounter_modifier_runtime.gd`. Vocabulary edits should not change them.
3. Run `tools/fate_classifier_test.tscn` in Godot. It exhaustively checks each
   word with WordNet, detects duplicates, verifies normalization and biome
   restrictions, checks unsupported/invalid inputs, exercises editable previews
   and confirmation, and hands every modifier from preparation to combat.
4. Run the existing encounter, expanded-modifier, active-panel, balance, frozen
   letter, and quick-cast regression scenes when changing selection or UI flow.

Example command (replace `Godot` with your executable):

```sh
Godot --headless --path . tools/fate_classifier_test.tscn
```

Choosing known beneficial words repeatedly remains possible. Easier fights now
trade lower enemy gold for that advantage; there are no selection costs or
cross-encounter adjective limits.
Vocabulary expansion is manual; valid synonyms and comparatives not explicitly
listed remain unsupported. Combat counter scoring still uses WordNet separately
and is unaffected by this preparation-only change.

## Selection descriptions and risk rewards

`encounter_modifier.gd` stores `selection_effect` and `difficulty` separately from
its original numerical `effect` and combat fields. The 288 adjective mappings,
all original combat fields, and `encounter_modifier_runtime.gd` are unchanged.

| Modifier | Selection effect | Difficulty | Enemy gold |
| --- | --- | --- | ---: |
| TITANBOUND | Tougher Enemy | Harder | 1.25× |
| DOOMMARKED | Frail Enemy | Easier | 0.75× |
| WAR-BLESSED | Stronger Enemy Strikes | Harder | 1.25× |
| SPIRIT-BROKEN | Weaker Enemy Strikes | Easier | 0.75× |
| FATE-EXPOSED | Empowered Attacks | Easier | 0.75× |
| SPELLWARDEN | Weakened Attacks | Harder | 1.25× |
| DROWSY | Naps, Fierce Awakenings | Easier | 0.75× |
| CLUMSY | Enemy Strikes Itself | Easier | 0.75× |
| LONG-WINDED | Word Length Bonuses | Easier | 0.75× |
| ECHO-BOUND | Linked Word Power | Easier | 0.75× |
| CHAMELEON | Shifting Enemy Weaknesses | Mixed | 1.00× |
| GREEDY | Coins And Theft | Mixed | 1.00× |
| FROSTBITE TAX | Faster Freezing, Extra Heat | Mixed | 1.00× |

Classification follows the implemented mechanics:

- TITANBOUND gives the enemy more health; DOOMMARKED gives it less.
  WAR-BLESSED increases enemy attack; SPIRIT-BROKEN decreases it.
  FATE-EXPOSED boosts player direct damage; SPELLWARDEN reduces it.
- DROWSY sleeps on the first retaliation and every other retaliation thereafter.
  Awake hits are stronger, but two retaliation opportunities average only 62.5%
  of ordinary enemy damage. It is easier overall despite the catalogue's older
  `beneficial=false` presentation flag, which remains unchanged.
- CLUMSY replaces each third retaliation with a self-hit, sparing the player.
- LONG-WINDED grants damage for long words or Guard for short words; neither
  option penalizes the player. ECHO-BOUND adds an optional damage bonus without
  reducing the damage of unlinked words. Both are easier.
- CHAMELEON changes semantic counter targets, which can help or hinder a given
  hand. It does not increase enemy stats: mixed.
- GREEDY changes coins, not combat strength. Its capped theft is offset by cast
  coins and the victory bonus, so it retains standard enemy gold.
- FROSTBITE TAX freezes more frequently but doubles Heat generation, helping
  the player thaw letters. This compensating tradeoff stays mixed and Tundra-only.

Tier multipliers are configurable in `tuning.gd` under
`MODIFIER_REWARD_MULTIPLIERS`. A 1.50× very-challenging tier is available but none
of the current standalone effects warrants that initial classification.

Only **enemy victory gold** is scaled. Elite scaling and endless-wave base gold
are already included in that amount. Round the product once to the nearest whole
gold, with positive halves rounding up, then add Greedy's unchanged victory bonus
and any existing flat relic victory-gold bonus. Example: 10 base gold becomes
8 on an easier fight or 13 on a harder fight. Cast gold, theft, other combat coin
procs, letters, relics, powers, side quests, statistics definitions, and history
are not multiplied. Item rewards are discrete and remain unchanged.

The preview shows `Increased Gold`, `Decreased Gold`, or `Standard Gold`.
Selection labels and tooltips contain no numerical effects or reward amounts;
the configured multipliers and actual payouts remain unchanged.
Invalid or unsupported input clears the effect and reward together. Confirmation
and reopening use the same catalogue data. The existing layout, accent colors,
and reserved effect-label height are preserved.

Combat captures a route-node or encounter-stage receipt key when it starts.
RunState reserves that key before reward signals or item drops. Both repeated
callbacks and reloaded combat scenes therefore cannot claim the same victory
again. The base enemy reward is never overwritten, and post-fight screens only
show the already-settled total. Clearing the victory display does not clear
receipts; a new run does. The developer's explicit replay jump clears only that
route node's receipt to preserve its existing intentional replay behavior.

Validation with Godot 4.7.2: all 13 relevant test scenes passed:
`modifier_rewards_test`, `fate_classifier_test`, `encounter_modifier_test`,
`expanded_modifiers_test`, `active_modifier_panel_test`, `balance_test`,
`expedition_route_test`, `route_progression_test`, `tundra_minigames_test`,
`tundra_events_test`, `frozen_letters_test`, `quick_cast_test`, and
`tundra_sim_test`. Import completed without parsing or missing-resource errors.
The new reward suite covers all fates at opening/regular/boss stages, rounding,
reentrant and duplicate callbacks, scene reloads, receipts, and previews at
1280×720, 1600×900, and 1920×1080. The adjective suite passed 3,854 checks,
including all 288 mappings. Some older regression scenes still emit shutdown
ObjectDB/resource cleanup diagnostics despite passing their assertions.

## Sprint 5 verification results

Verified with Godot 4.7.2 on macOS. All 25 automated test scenes were attempted,
along with the WordNet smoke script: **18 passed; 8 failed or stalled**. The
Python telemetry test also passed (one test). The eight unsuccessful Godot checks
were reproduced in a temporary project using the pre-change classifier,
preparation screen, and classifier test from Git HEAD, with the same remaining
workspace resources. No unrelated scripts were changed to fix them.

The final adjective suite passed **3,814 checks with zero failures**, including
all 288 words, unique assignments, repeated deterministic lookup, WordNet
validation, case/whitespace normalization, unsupported and invalid inputs,
Tundra restrictions, clickable examples, editable previews, confirmation,
reopening preparation, 1280×720 layout bounds, and all 13 combat handoffs.

Passing Godot checks:

- `fate_classifier_test`, `encounter_modifier_test`,
  `expanded_modifiers_test`, `active_modifier_panel_test`.
- `balance_test`, `frozen_letters_test`, `quick_cast_test`,
  `word_feedback_test`, `attack_feedback_test` (12 monsters).
- `expedition_route_test`, `player_stats_test`, `rogue_inspector_test`,
  `route_progression_test`.
- `tundra_minigames_test`, `tundra_events_test`, `tundra_sim_test`.
- `telemetry_test` (with its required `WORDWOVEN_TELEMETRY=1` opt-in).
- `wordnet_smoke_test.gd`.

Existing unsuccessful checks, also reproduced before this change:

| Check | Result |
| --- | --- |
| `bear_animation_test` | Three assertions: attack row, damage contact frame, strike effect |
| `combat_sim_test` | Calls removed `DamageCalculator._semantic_multiplier()`; does not complete |
| `powers_ui_test` | References missing `EquipmentOverlay.powers_button` |
| `settings_test` | One assertion: all settings persisted |
| `sprint4_ui_test` | One assertion: gold retained |
| `tavern_sim_test` | References missing `tavern_hub.economy` |
| `tundra_story_test` | One assertion: intro visually freezes or removes letters |
| `ui_style_test` | No completion within 120 seconds; pre-change comparison also stalled (60-second bound) |

Tests that stalled or stopped on script errors were bounded/terminated rather
than allowed to run indefinitely. Sandbox headless runs emitted a macOS
certificate-access diagnostic, and a few older passing tests emitted resource
cleanup warnings; these did not fail their assertions. The statistics suite also
logs an intentional malformed-configuration read during its corruption checks.
The final adjective suite exits without the earlier looping-audio cleanup
warnings after explicitly releasing test audio and allowing the mixer to finish.

A rendered preparation screen was inspected for the blue-and-gold theme and
readability. A live confirmation/transition check verified `frigid` reaches
combat as `frostbite_tax`, consumes the pending selection, and retains
`freeze_every = 2` and `heat_per_word = 2`.
