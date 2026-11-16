# Tavern interaction icons

Generated transparent pixel-art PNGs using the built-in image_gen tool.
Each image's full generation prompt is saved in the matching `.prompt.md`.

| File | Interaction |
| --- | --- |
| `bartender.png` | Food with green healing symbols; opens the bartender shop |
| `dealer.png` | Coin pouch and letter tiles; opens the letter dealer |
| `forge.png` | Anvil and hammer; opens the forge |

`TavernPanorama.add_poi()` accepts an optional icon path. Icons replace
location labels and off-screen text markers; hover tooltips retain the names.
Icons sit on dark circular backings with gold borders. The border forms a
small pointer toward the location; off-screen pointers follow the screen edge.
The original hotspot buttons and their signals remain the interaction targets.
Source images are unchanged; their alpha bounds are trimmed by AtlasTexture
when rendered. Icons use nearest-neighbor filtering.
