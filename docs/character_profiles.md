# Character profiles

Click the small i button on a letter to open its character profile. Combat,
equipment, shop, and forge letters also support right-click. Combat, equipment,
shop, and forge letters retain press-and-hold access. The selected tavern
character display also has an i button. Close with Escape, the close button, or a click outside the panel.

Each LetterStats resource owns its appearance seed, accepted-use count, and best
word. Best means highest resolved cast damage (including encounter modifiers),
recorded only for participating hand letters; ties keep the earlier word.
Previews and undrawn letters do not receive history. Itemized letters retain
their existing fixed-level rules while accumulating uses and records.

Default colors are stable per item. Portraits show metal rank fittings at levels
1, 5, 10, and 20, and scars at 5, 10, and 15 uses. Hand tiles show corresponding
cloth accents, rank studs, and scratches; battle actors share the item tint.
Custom portrait and animation selections remain in use.

Profile fields are exported with the letter resource and travel with the item
within a run. This does not introduce run saving or transfer between runs.
Favorite-letter transfer is deferred.

Regression scene: res://tools/character_profile_test.tscn
Pass -- --preview in a graphical run to capture .godot/profile_preview.png.

For quick scar testing, press F12 and select a letter in the bottom row (equipped
and inventory letters are listed separately, including duplicate glyphs). Click
+1 use to test a threshold or +5 uses to advance one scar tier. The updated profile
opens automatically; close it and press F12 to repeat. These simulated uses call
the same history method as combat, recording DEBUG at zero damage, and mark the
run debug-assisted. Existing higher-damage records, levels, rewards, and encounter
progress are unchanged. Start a run first to populate the selector.

## Modular class portraits

Default character profiles and the tavern portrait use three independently
selectable bodies and three faces per class (27 combinations total). The existing
appearance seed chooses a stable pair; gaining levels or scars does not reroll it.
`LetterStats.body_feature` and `face_feature` accept 0–2 for explicit choices or
-1 for the seeded default. Both fields serialize with the letter resource.

| Class | Bodies | Faces |
| --- | --- | --- |
| Warrior | Steel defender, leather vanguard, bronze sentinel | Auburn browband, curls and circlet, silver veteran |
| Healer | Emerald cleric, traveling apothecary, moss pilgrim | Braided herbalist, freckled copper, white curls |
| Rogue | Plum infiltrator, charcoal scout, midnight duelist | Swept hair and hood, textured bandana, silver sidecut |

Use F12's letter selector and **Next body / Next face** to inspect combinations.
These controls mark the run debug-assisted. Select Default in Cosmetics first if
the letter has an explicit costume. Custom cosmetics take priority as before.

Run `res://tools/character_features_gallery.tscn` for a scrollable collection;
hover a portrait to see its parts. Passing `-- --export` regenerates the contact
sheet at `art/party/features/combinations_preview.png`. Source atlases and the
imagegen prompts are alongside it. The reusable parts are portrait art; combat
SpriteFrames remain unchanged. Gear and earned scars still overlay the profile.

Regression scene: `res://tools/character_features_test.tscn`.

## Scars and expressions

At 5, 10, and 15 accepted uses, letters gain up to three red scar shapes: slash, claw, and stitched. Each occupies a different facial location (left cheek, right cheek, or brow). Scars use dark-red edges and red highlights, without skin-colored fills or body marks. The appearance seed fixes their order and placement, so earlier scars stay in place as history grows.

Default modular portraits become Watchful, Stern, then Grim as scars accumulate:
smiles flatten into frowns, brows lower, and the final stage adds tired eye shading.
Profiles and tavern portraits share this rendering. Custom cosmetic artwork keeps
its original expression; scars still overlay it. Combat animation art is unchanged.
Hand tiles retain their compact scar-count scratches.

F12's existing +1 / +5 uses buttons exercise this progression. Hover profile history
for the scar types, facial locations, and expression stage. Run
`res://tools/character_scars_gallery.tscn` to see all nine faces at all four stages.
A graphical run with `-- --export` saves `.godot/scar_preview.png`.
Regression scene: `res://tools/character_scars_test.tscn`.

F12's **Character matrix** toggle opens a separate movable, resizable window with
all 27 class/body/face combinations. Drag the canvas with the left or middle mouse
button to pan; scroll to zoom around the cursor. **Fit all** restores the overview
and **100%** shows the portraits at their native size. Use the scar, tint, gear,
and scar-seed controls to compare appearance variations without editing run data.
Closing the window clears the toggle; hiding and reopening retains the view.
Regression scene: `res://tools/character_matrix_test.tscn`.

The active modular art uses the detailed fantasy pixel style in the `_v2.png`
atlases: cool shadows, textured cloth/leather, dimensional metal, and natural
facial planes. Original atlas versions are retained. Profile gear ranks use small
metal fittings and a champion jewel, allowing the authored outfits to show.
See `art/party/features/RESTYLE.md` for source references and exact edit prompts.
`res://tools/character_style_preview.tscn` previews the party against the actual
tundra background and Glacier Bear; graphical `-- --export` saves its image.

The current coarse-pixel pass uses `_v3.png` atlases, retaining the previous styles.
Parts have larger color clusters and simpler shading. Composed portraits share a
64×64 logical grid, enlarged with nearest-neighbor sampling and crisp alpha edges.
See `art/party/features/PIXEL_STYLE.md` for the exact imagegen edit prompt.
