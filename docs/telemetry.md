# Playtest telemetry

Telemetry writes offline JSONL files to `user://telemetry/`, one per launch.
On Windows the default is `%APPDATA%\Godot\app_userdata\Lexical Rogue\telemetry`.
Copy these files from each playtest machine into a collection folder. No server,
account, network upload, player name, device ID, or typed word is collected.
Tell testers that anonymous gameplay metrics are recorded. Set environment
variable `WORDWOVEN_TELEMETRY=0` before launching to disable collection.
Files remain until manually archived/deleted; clear the folder between studies.

## Identify the build

Editor play sessions read the current Git branch, full commit, and dirty flag.
Before **every export**, run from the repository root:

```powershell
python tools/playtest_telemetry.py stamp
```

This generates ignored `data/telemetry_build.json`. Include that exact file in
Godot's export preset **non-resource export filter** (`data/telemetry_build.json`).
Export immediately from that checkout. Git is not needed on playtest machines.
A missing manifest is labeled `unknown`, never attributed to a guessed version.
A stale manifest cannot be detected in an exported binary: stamping is a required
release step. Detached HEAD builds report `HEAD` and retain the exact commit.
Use committed, clean builds for comparisons: different uncommitted edits share
one commit/dirty label and cannot be distinguished reliably.

## Compare playtests

```powershell
python tools/playtest_telemetry.py report C:\Playtests\Collected > report.json
```

The report groups by branch **and full commit**, dirty flag, and debug use. It
includes run count, outcome counts, accepted/rejected casts, rejection rate,
mean calculated cast damage, and median successful-cast decision seconds.
Keep sample sizes visible; randomized enemies and player experience can explain
differences between builds. Damage is calculated cast damage, not actual HP
removed (overkill and subsequent damage-over-time differ).

Every event includes schema version, session/run IDs, sequence, UTC timestamp,
monotonic elapsed milliseconds, build, stage, biome, health, gold, and debug flag.
Events cover run start/end, encounter start/win, accepted/rejected words, player
damage, gold changes, and power selections. Accepted casts include prompted POS,
letter counts, elemental damage, effectiveness, and the combat decision timer.
Run/encounter duration is wall time including pauses; cast time follows the
existing combat timer. Gold changes do not identify purchase type.

Outcomes distinguish won, lost, restarted, abandoned (main menu), and quit.
Crashes or forced termination leave no ending and report as `incomplete`.
Losses are finalized immediately; victories on the victory summary screen.
Opening the debug overlay conservatively flags that run and subsequent runs in
the session, because forced letters/tags can persist. Reports apply the flag to
the entire run, including earlier casts. Duplicate copied events are counted
once; malformed/truncated lines are skipped and counted as `invalid_lines`.

Writes flush after each event. Unavailable storage disables tracking with a
warning without blocking play. Headless tests are excluded unless explicitly
launched with `WORDWOVEN_TELEMETRY=1`.

## Verification

```powershell
python tools/test_playtest_telemetry.py
$env:WORDWOVEN_TELEMETRY = '1'
godot --headless --path . res://tools/telemetry_test.tscn
```

Use a separate test user-data folder and exclude synthetic sessions from studies.
