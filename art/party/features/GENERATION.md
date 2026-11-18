# Portrait feature art

Created with the built-in imagegen tool. References: the matching existing
`art/party/portraits/{class}_1.png`, used as style references only.
PNG alpha is preserved. Runtime compositing uses the measured neck anchors in
`scripts/cosmetics/character_features.gd`; original generated atlases are retained.

## Shared prompt

Create a production modular character portrait sprite atlas for the Wordwoven game. Match the reference's charming tiny medieval pixel art, clean hard pixel steps, limited palette, dark outlines, full front-facing chibi proportions. Transparent PNG, exactly 1536x1024 pixels. EXACT 3-column by 2-row grid, six 512x512 cells, no borders, no labels, no text. This is a paper-doll parts atlas, NOT six complete characters. TOP ROW: three HEADLESS fully clothed bodies, with boots, arms and class equipment, no heads or hair. In each local 512x512 cell body centered at x256, neckline at y220, shoulders y238, feet y465; leave y0..219 transparent (except tall weapon beside body). BOTTOM ROW: three standalone complete heads/faces including hair or headgear and short neck, NO bodies. Each head local center x256,y140; top y40, bottom of neck y232. Leave below y233 transparent. All heads and bodies MUST align when their 512x512 cells overlay at identical origins: neck overlaps collar at y220. Each class's 3 body silhouettes differ visibly, each head has distinct skin tone, facial structure, expression, hair/headgear. All eyes uncovered and faces readable for scars. No baked scars. Keep all parts wholly inside their cells. No floor, shadow, sparkles, scenery or checkerboard. Reference is style only. 

## Class prompts

### warrior

Bodies: broad steel plate with red tabard and shield; lean leather brigandine with blue sash and sword; stocky bronze lamellar with ochre cape and axe. Heads: light skin square face with auburn short hair and open iron browband; deep brown skin round face with black curls and gold circlet; warm tan angular face with silver cropped hair and short beard. All faces point forward.

### healer

Bodies: slender emerald cleric robe with ivory stole and wooden staff; broad cream apothecary coat with teal sash and potion satchel; compact moss-green pilgrim tunic with gold mantle and small prayer book. Heads: brown skin oval face with dark braided hair and green headband; light freckled round face with copper bob and small leaf pin; deep brown angular face with white curls and gold circlet. All faces point forward.

### rogue

Bodies: lean plum leather jerkin with dagger and crossbody belt; broad charcoal scout coat with teal sash and utility pouches; compact midnight-blue duelist vest with burgundy scarf and short sword. Heads: tan angular face with black swept hair and lowered hood framing face; deep brown round face with short textured hair and purple bandana; pale narrow face with silver sidecut and dark headband. No face masks. All faces point forward.
