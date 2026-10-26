# Character Cosmetic Asset Template

Copy this prompt and replace every `[PLACEHOLDER]` before generating art.

```text
Create a game-ready pixel-art cosmetic for WordWoven, a cozy dark-fantasy
word-combat game.

Character concept: [CHARACTER DESCRIPTION]
Combat archetype: [Warrior / Healer / Rogue / Mage]
Palette and theme: [COLORS, MATERIALS, MOOD]
Distinctive silhouette details: [WEAPON, HAT, ACCESSORY, POSE]

Art direction: detailed, charming pixel art with a strong dark outline and
clear silhouette at tiny sizes. No words, UI, border, effects, scenery, or
cast shadow. Use a fully transparent background.

Create two separate PNG files:

1. portrait.png
- Square portrait; upper body or head-and-shoulders.
- Character centered, clearly readable, transparent background.

2. sprite_sheet.png
- One horizontal row of transparent [32x32 or 64x64] pixel cells.
- Character faces right. The game mirrors it for left-facing movement.
- Keep the feet aligned at the same bottom baseline in every frame.
- No gaps, labels, frames, or padding between cells.

Use this exact frame order for [ARCHETYPE]:

Warrior (9 cells):
idle_0, idle_1, walk_0, walk_1, walk_2, walk_3, crouch, leap, slash

Healer (9 cells):
idle_0, idle_1, walk_0, walk_1, walk_2, walk_3, cast_0, cast_1, cast_2

Rogue (11 cells):
idle_0, idle_1, walk_0, walk_1, walk_2, walk_3, run_0, run_1, run_2,
run_3, grab

Mage (9 cells; healer-compatible):
idle_0, idle_1, walk_0, walk_1, walk_2, walk_3, cast_0, cast_1, cast_2

Action direction: [DESCRIBE HOW THE CHARACTER ATTACKS, CASTS, OR MOVES].
```

## Import contract

The game stores each cosmetic as a `CharacterCosmetic` resource containing a
portrait, a `SpriteFrames` animation set, its archetype, and an action map.
New spritesheets should therefore use the frame order above. The importer maps
them to the semantic actions combat requests (`idle`, `walk`, `attack`, etc.).

Native 32x32 sprites render at the normal scale. 64x64 sprites are supported
for more detailed generated art; set `render_scale` per cosmetic to tune its
on-screen presence (the Mage currently uses `1.0`).

Portraits and combat sprites may be assigned to any letter. The cosmetic's
archetype chooses its battle action style, while the letter still keeps its own
element and damage calculation. This guarantees the selected cosmetic supplies
every animation its combat behavior needs.
