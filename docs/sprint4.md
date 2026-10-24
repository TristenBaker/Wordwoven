# Sprint 4: statistics, combat history, and achievements

## Player access

- Victory and defeat screens display a scrollable run-statistics panel beneath
  the existing gold/key-item tally. Backgrounds, music and navigation remain.
- **Word History**, immediately left of **Show Log** in combat, opens a read-only
  chronological list. It is available during player input only. Close or Escape
  resumes the same draft and quick-cast clock.
- **Achievements** is available in the main menu and pause menu. Escape returns
  from the pause submenu to the pause menu; a second Escape resumes gameplay.

## Data ownership and counting

`PlayerStats` observes existing combat events and exposes detached snapshots.
`RunState.word_history` remains the only word-entry collection; its entries now
include scalar effectiveness metadata. `WordEffectivenessFormat` supplies the
same classification to combat feedback and history, without recalculation.

Only accepted combat casts count. Each cast belongs to the prompted POS. Every
character occurrence counts, including undrawn letters. Most-used-letter ties
resolve alphabetically; an empty run displays `None`.

**Word Damage Dealt** sums final direct resolved cast values, including overkill,
after encounter modifiers. It excludes burn, poison, enemy self-hits and developer
kills. Highest Word Damage uses that same measure. **Damage Received** sums the
existing post-mitigation incoming-damage events, including lethal overkill; it is
not capped to remaining HP. Enemy/encounter counts consume one victory per
encounter-start event and exclude treasure rooms and other activities.

`RunState.run_started` resets only the run counters and history boundary.
Encounter starts reset only the history boundary. Opening menus never resets
counters. Summary finalization is idempotent and leaves the snapshot available
until the next new run. Abandoning to the main menu finalizes without a win.

## Achievements and developer assistance

Stable IDs and conditions are defined in `PlayerStats.DEFINITIONS`:

| ID | Achievement | Lifetime condition |
| --- | --- | --- |
| `first_blood` | First Blood | 1 defeated enemy |
| `wordsmith` | Wordsmith | 25 accepted combat words |
| `heavy_hitter` | Heavy Hitter | One direct cast of at least 50 damage |
| `noun_master` | Noun Master | 15 noun casts |
| `verb_master` | Verb Master | 15 verb casts |
| `adjective_master` | Adjective Master | 15 adjective casts |
| `adverb_master` | Adverb Master | 15 adverb casts |
| `alphabet_explorer` | Alphabet Explorer | All 26 letters used across runs |
| `monster_slayer` | Monster Slayer | 10 defeated enemies |
| `victory` | Victory! | 1 completed winning run |

Conditions are evaluated on gameplay events, not every frame. A persistent
CanvasLayer queues notifications without taking focus or intercepting clicks.

Actual developer actions mark the current run assisted, including gold, healing,
skips, auto-kill, free-map navigation, Hangman reset and forced tags/letters.
Merely viewing F12 does not mark assistance. Inherited forced overrides are also
checked when a run or combat begins and when a cast resolves.

Lifetime progress is checkpointed at each run start. If assistance is used later,
all progress and unlocks contributed by that run are rolled back, including data
already saved; queued notifications are cleared. Prior runs remain intact, and
run statistics remain visible. Consequently a live unlock can be revoked if the
same run later uses a developer shortcut. Developer tools themselves remain
available. Ordinary new runs become eligible again unless overrides remain.

## Persistence

`user://achievements.cfg` stores schema version, stable unlocked IDs, accepted
word/POS/kill totals, letter counts, highest direct cast damage and completed
wins. It is independent of settings, telemetry and WordNet cache.

Progress saves after qualifying casts, victories, finalization and debug
rollback. Writes use a temporary file and previous-file backup. Loading validates
counter types/ranges, finite damage, alphabet entries and unlock conditions.
A valid backup recovers a corrupt/missing primary. If neither existing copy is
valid, or the schema is newer, files are preserved and writes are blocked for
that session rather than overwriting potentially recoverable progress. Errors
are logged and emitted through `persistence_failed`; gameplay continues.

Headless runs do not read or write player achievement data by default. To opt in
for a persistence test, set `WORDWOVEN_ACHIEVEMENTS_PATH` to an isolated temporary
file. Normal desktop builds use `user://achievements.cfg` automatically.

## Automated checks

Run from the project root with Godot 4.7:

```sh
godot --headless --editor --recovery-mode --path . --import
godot --headless --path . res://tools/player_stats_test.tscn
godot --headless --path . res://tools/sprint4_ui_test.tscn
```

The first suite covers aggregates, detached snapshots, encounter boundaries,
resets, every achievement, duplicate protection, lethal damage, whole-run debug
rollback, persistence and corrupt-save recovery. The second uses real combat
submission and checks invalid/repeated casts, metadata, chronological history,
paused submission/timing, focus, Escape, menus, summaries, debug auto-kill and
notification queuing across scene replacement.

Separate-process persistence check (use a fresh temporary path):

```sh
WORDWOVEN_ACHIEVEMENTS_PATH=/tmp/wordwoven-restart.cfg \
  godot --headless --path . res://tools/player_stats_test.tscn \
  -- persistence-write
WORDWOVEN_ACHIEVEMENTS_PATH=/tmp/wordwoven-restart.cfg \
  godot --headless --path . res://tools/player_stats_test.tscn \
  -- persistence-read
```

Desktop visual review, mouse/keyboard feel and audio remain manual QA tasks.
Existing legacy `combat_sim_test` and `powers_ui_test` reference removed APIs
(`DamageCalculator._semantic_multiplier` and `EquipmentOverlay.powers_button`)
and cannot currently finish; these unrelated tests were not rewritten.

## Validation performed

Godot 4.7.2 imported the project and ran both new suites with zero failures.
A separate write process followed by a new read process restored achievement
progress and unlocks. Headless UI checks include supported desktop resolutions.

Existing suites passing with zero failures:

- `quick_cast_test`
- `word_feedback_test`
- `encounter_modifier_test`
- `expanded_modifiers_test`
- `route_progression_test`
- `settings_test`
- `active_modifier_panel_test`
- `tundra_events_test`
- `tundra_minigames_test`

The two legacy API failures above were reproduced against an untouched HEAD
snapshot. The expanded-modifier suite needed a longer timeout and then passed.
The importer also reported sandbox restrictions saving editor preferences/help
cache. Runtime output includes existing macOS certificate, victory-art UID
fallback and occasional shutdown resource warnings. Corrupt-save diagnostics
in `player_stats_test` are intentional fault injection. No visual/manual gameplay
or audio review was performed, and telemetry's opt-in file-writing test was not
run. Headless tests leave the player's normal achievement save untouched.
