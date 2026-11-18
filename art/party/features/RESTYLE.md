# Detailed fantasy pixel-art restyle

Generated with the built-in imagegen tool. Active atlases:
- `warrior_parts_v2.png`
- `healer_parts_v2.png`
- `rogue_parts_v2.png`

The original `_parts.png` files remain available as the first style pass.
Each original atlas was the edit target. Style references were the actual
Glacier Bear idle sheet in `assets/Art/Enemies/Tundra Monsters/Bear/` and
`art/backgrounds/Tundra Biome/T1.png`.

The restyle uses detailed pixel clusters, cool shadow ramps, pale highlights,
textured leather/cloth, faceted metal, and more natural facial features.
Heads retain their modular alignment. Dark gloves permit all skin-tone pairings.
The 27 combinations, seeded identity, scar placement, and progression remain.
Profile equipment ranks use small highlighted metal fittings rather than broad
flat polygons, keeping the authored armor and clothing visible.

## Exact shared edit prompt

Restyle ONLY image 1, a modular paper-doll character parts atlas. Images 2 and 3 are STYLE REFERENCES ONLY: the game's Glacier Bear sprite sheet and tundra environment. Deliver the revised atlas as a transparent PNG EXACTLY 1536x1024. Preserve ALL six parts, their layout, exact placement, scale, silhouettes, neck connectors, eye/nose/mouth landmark positions and equipment from image 1. Three HEADLESS bodies across top row and three separate heads across bottom row. NEVER assemble the heads onto bodies. No extra parts, labels, borders or scenery.

Style change: match the detailed hand-crafted 16-bit fantasy pixel rendering of the reference bear and tundra: precise angular pixel clusters, richer stepped color ramps, deep cool navy/blue-violet shadow planes, directional pale highlights, textured worn leather and cloth, dimensional faceted metal, hair rendered as detailed pixel locks. Remove the flat cute mobile-avatar aesthetic and thick muddy cartoon outline. Faces should have more natural adult planes, smaller realistically proportioned eyes within the existing eye locations, carefully shaded cheekbones/noses and restrained neutral mouths; preserve distinct skin colors and headgear. Keep the original head silhouette/scale and positions so existing code still aligns expressions. Mildly heroic stylization is fine. No smooth painting, no blur, no airbrushed gradients, no glow halos, no fake transparency checkerboard. Exposed hands should wear fitted dark leather gloves so heads of any skin tone can pair with any body. Retain the class color coding but shift to restrained jewel tones and earthy neutrals accented by cold highlights. Fully transparent everywhere outside the actual part silhouettes. No scars baked in.

Each call appended `Class for this atlas: warrior.`, `healer.`, or `rogue.`.

## Preview

`tools/character_style_preview.tscn` places the three classes beside the actual
Glacier Bear on the tundra background. A graphical run with `-- --export` saves
`art/party/features/style_context_preview.png`.
