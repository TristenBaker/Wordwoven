# Lexical Rogue

Godot 4.7 (standard build, pure GDScript — no C#/.NET). The
design contract is [docs/GDD.md](docs/GDD.md): implement its
feature list and nothing beyond it.

## Rules

- Follow [docs/gdscript-style.md](docs/gdscript-style.md)
  strictly: explicit type on every declaration (never `:=`),
  80-column lines, comments on their own line, resource UIDs over
  paths, one class per file.
- Architecture: no god objects; separate focused systems
  (WordNetReader, SemanticScorer, DeckManager, EconomySystem...);
  communicate across systems through EventBus signals.
- All NLP goes through the `WordNet` autoload; nothing else
  touches `assets/wordnet/dict` (which is gitignored — it must be
  downloaded per `assets/wordnet/SETUP.txt`).

## Verification

Headless tests (run with the Godot console binary):

```
godot --headless --path . -s res://tools/wordnet_smoke_test.gd
godot --headless --path . res://tools/combat_sim_test.tscn
godot --headless --path . res://tools/tavern_sim_test.tscn
```

Note: `-s` scripts cannot reference autoloads at compile time;
game-level tests are scenes (`.tscn`) run headless instead.
