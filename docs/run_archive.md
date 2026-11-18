# Final run loadouts

`RunArchive` stores one immutable snapshot when the existing victory/defeat
summary records a run. It is independent of `wordwoven_leaderboard.json`,
`player_profile.cfg`, and achievements. No existing save format is migrated
or rewritten by the archive. Previous leaderboard entries cannot supply
loadouts that were never recorded.

## Storage

Each new run has an in-memory random ID and start timestamp. At its end:

`user://run_archive/<32-character-run-id>.json`

The version 1 record contains:

- Existing score summary, mode, outcome, and completion timestamp.
- Start timestamp, when known.
- Final equipped letters: character, element, level, modifier, cosmetic ID.
- Final powers: ID, saved name, quality, effect, per-copy amount, stack count,
  and combined effect text calculated when the run ended.

Loose inventory, intermediate loadouts, talents, and per-letter combat
statistics are not captured. In legacy deck mode the deck is the loadout.

Writes go through a validated temporary file before an atomic rename. A
`.json.bak` copy is kept. Reads validate records and fall back to backups;
malformed/unsupported files are skipped, never overwritten. Reopening the
end screen returns the existing record for that run ID. Archive records
are not pruned when the leaderboard drops an entry from its top 20.

## Presentation

The leaderboard's **Past Loadouts** button opens the read-only archive.
Ranked rows also link to their matching archive when one can be identified
unambiguously, without changing the leaderboard save format. Equipped letters
occupy fixed A–Z inventory slots, with empty slots kept visible.
Selecting a saved letter shows its archived cosmetic and final details.
Powers display their saved stack totals, not today's balance calculations.

Each tavern shop phase chooses an archived run and one of its final equipped
letters. The choice stays stable across tavern activities. Clicking that
visitor opens its original loadout. With no eligible archives, the current
run visitor remains the fallback. No historical damage or usage is inferred.

## Tests

`tools/run_archive_test.tscn` uses a unique directory inside the ignored
`.tmp/tavern` directory. `WORDWOVEN_RUN_ARCHIVE_DIR` overrides the archive
directory for test fixtures. Headless runs disable archive access unless
an explicit non-default directory is supplied. Tests never create synthetic
records in the player's archive.
