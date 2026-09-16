# Extending enemies, abilities, relics, and effects

Most content is data. New *behavior* is one focused handler class
registered in one place; screens never need to change.

## Add an enemy

Add an entry to `data/enemies.json`:

```json
"bandit": {
	"name": "Road Bandit",
	"description": "Takes more than your purse.",
	"health": 30, "attack": 6, "gold": 36,
	"texture": "uid://...", "frame_width": 150,
	"tag_pool": ["greedy", "sneaky"], "tag_count": 1,
	"tier": 2,
	"abilities": [{"id": "steal_tile", "count": 1}]
}
```

- `tier` decides the stage: tiers 1–3 cover encounters 1–5 in pairs,
  and tier 4 is the boss.
- During encounter setup the player types the enemy's single tag.
  `tag_pool` and `tag_count` are used only when combat starts without a
  confirmed setup (debug flows).
- `abilities` lists existing ability ids with their parameters. An
  enemy that uses only existing abilities needs no code.

## Add an environment

Add an entry to `data/environments.json` with `name`, `description`,
background texture UIDs, and `abilities` in the same format as enemies.
`EnvironmentCatalog.roll` picks between `normal` and `icy`; to offer
another environment, extend that roll.

## Add an ability

1. Create `scripts/combat/abilities/<name>_ability.gd` extending
   `EncounterAbility`. Override only the hooks you need:
   - `after_enemy_attack(context, params)` runs after an attack the
     player survived. Defeated enemies never trigger it.
   - `on_player_turn_start(context, params)` runs before input opens.
   - `describe(params)` returns the preview and tooltip text.

   Each hook returns log lines. `context.conditions` holds per-instance
   poison, freezing, and theft; `context.deck` is the encounter's
   `DeckManager`. Change only this encounter's state; never edit
   `RunState.deck` or permanent `LetterStats`.
2. Register the handler id in
   `EncounterAbilityRegistry._ensure_defaults()`.
3. Reference the id from enemy or environment data, and add a case to
   `tools/combat_sim_test.gd`.

If an ability needs a new *kind* of letter condition, add it to
`EncounterConditions` and read it in `DamageCalculator.calculate` using
the `conditions` context entry.

## Add a relic

Add an entry to `data/relics.json`:

```json
"ink_pot": {
	"name": "Ink Pot",
	"description": "+2 gold per victory and one extra hand tile.",
	"effects": [
		{"type": "victory_gold", "amount": 2},
		{"type": "hand_size", "amount": 1}
	]
}
```

Names, descriptions, and amounts are read only from this file.
`RelicCatalog` loads it once, validates each entry, and skips invalid
entries with an error. Older entries written as `"effect"` plus
`"amount"` still work. Each owned copy applies its effects again, so
copies stack.

## Add a relic effect type

1. Create `scripts/combat/relics/<name>_relic_effect.gd` extending
   `RelicEffect`:
   - `stat_bonus(stat, params)` adds to a passive total that systems
     read through `RelicSystem.total_effect(stat)`.
   - `on_granted(params)` applies a one-time change when the relic is
     claimed.
   - `validate(params)` reports parameter problems. The default checks
     for a numeric `amount`.

   A simple passive stat can reuse `StatBonusRelicEffect.new("stat")`.
2. Register it in `RelicEffectRegistry._ensure_defaults()`.
3. Read the new stat where it matters, with
   `RelicSystem.new().total_effect("stat")`.

There is no inventory or consumable system. Relics stay passive.
