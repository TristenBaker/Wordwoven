# Coarse pixel pass

Active atlases: `warrior_parts_v3.png`, `healer_parts_v3.png`, and
`rogue_parts_v3.png`. Made with the built-in imagegen editor from the respective
`_v2.png` atlases, which remain available alongside the originals.

## Exact shared edit prompt

Edit this modular sprite atlas to look SIGNIFICANTLY MORE PIXELATED. Preserve the exact 1536x1024 canvas, transparency, three headless bodies above three separate heads, all part positions, silhouettes, size, neck anchors, facial landmark positions, costumes, skin tones and palette. Keep the current mature fantasy designs. Redraw using large clearly visible square pixel clusters, as though the ENTIRE atlas were authored at 192x128 logical pixels and enlarged exactly 8x with nearest-neighbor. Hard stair-step edges, flat solid color blocks, 4-5 tones per material, readable tiny eyes. Eliminate all fine speckled texture, subpixel detail, smooth gradients and soft highlights. Simplify hair into chunky locks, armor into broad pixel planes, cloth into a few decisive stepped folds. It must read as genuinely low-resolution 16-bit game sprites, not a detailed painting with a pixel filter. No added outlines/grid/borders/text, no glow, no background; fully transparent outside parts. Do not assemble characters or move anything.

## Rendering

The assembled portrait is sampled onto a shared 64 by 64 grid and enlarged to
256 by 256 using nearest-neighbor sampling. Alpha is binary at that grid size
so faint source mattes cannot appear over snow or dark UI backgrounds. The
assembled heads and bodies thus use consistent, visibly chunky pixels.

`combinations_preview.png` shows all pairings. `style_context_preview.png` shows
the current art beside the game's Glacier Bear on the tundra background.
