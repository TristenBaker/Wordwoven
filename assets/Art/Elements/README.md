# Element art and innate effects

Three transparent PNGs per element, generated with the built-in image_gen tool:

| Suffix | Purpose | First use |
| --- | --- | --- |
| `_emblem` | Compact elemental identity | Letter tooltips, talent branches, power cards |
| `_spell` | Impact or casting effect | Animated Burn, Poison, and Lightning hit effects |
| `_flourish` | Low decoration that leaves text space | Bottom of elemental power cards |

Elements: `fire`, `lightning`, `water`, `ice`, `nature`, `earth`.
Each PNG has a sibling `.prompt.md` containing its generation prompt.
Source images retain their transparency and original resolution. `ElementArt`
caches an `AtlasTexture` using the visible alpha bounds, so source margins do
not affect displayed sizes. UI uses nearest-neighbor filtering.

## Baseline effects

All effects are innate; powers and talents add to them. Numerical defaults
live in `data/balance/tuning.gd`, under `ELEMENT_BASE_EFFECTS`.

| Element | Baseline |
| --- | --- |
| Fire | Burn for 15% of Fire damage on the next enemy turn |
| Lightning | 10% chance to echo for 50% of the original Lightning hit; each echo rolls again, capped at 6 echoes |
| Water | Heal for 10% of Water damage |
| Ice | Reduce next retaliation by 10% of Ice damage |
| Nature | Poison for 15% of Nature damage on the next enemy turn |
| Earth | Guard against next retaliation for 15% of Earth damage |

Non-Lightning effects round to whole points, with a minimum of 1 for a
positive elemental hit. Absent elements trigger nothing. Casts combine
each element's damage before calculating and rounding its effect once.
Ice and Earth retain flat bonuses from existing powers/talents in addition
to the damage-based baseline.

Tile level, elemental damage powers, and potency talents raise the damage
feeding these effects. Signature-effect powers/talents add to the relevant
ratio, chance, or flat amount. Existing quick-cast behavior is preserved:
its bonus multiplies direct damage separately from secondary effects.

`DamageCalculator.elemental_secondary_effects()` serves both actual combat
and letter information. Tooltip values describe a single tile before word
bonuses and enemy affinity; cast values use the combined elemental damage
after those factors. Healing is capped by missing health when applied.
