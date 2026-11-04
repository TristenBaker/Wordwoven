# Adjective combat modifiers

Preparation uses an explicit vocabulary, not semantic similarity or random
selection. The full editable lists live in
[`adjective_vocabulary.gd`](../data/balance/adjective_vocabulary.gd).

Players may type a supported adjective or click an example. WordNet still
validates the adjective. Capitalization and surrounding whitespace are ignored.
A valid unsupported adjective receives an explanation and leaves confirmation
disabled. A Tundra-only word outside Tundra explains its restriction; it never
selects another effect.

The effect preview updates as the player edits. HP and attack modifiers show
rounded before/after values for the coming enemy. Enter in the text field only
refreshes the preview. **Confirm Modifier** revalidates and caches the selection;
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

Choosing known beneficial words repeatedly remains possible, as it was before.
No costs, cross-encounter adjective limits, or new balancing rules were added.
Vocabulary expansion is manual; valid synonyms and comparatives not explicitly
listed remain unsupported. Combat counter scoring still uses WordNet separately
and is unaffected by this preparation-only change.

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
