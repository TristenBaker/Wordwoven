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

Default colors are stable per item. Portraits show layered equipment at levels
1, 5, 10, and 20, and scars at 5, 10, and 15 uses. Hand tiles show corresponding
cloth accents, rank studs, and scratches; battle actors share the item tint.
Custom portrait and animation selections remain in use.

Profile fields are exported with the letter resource and travel with the item
within a run. This does not introduce run saving or transfer between runs.
Favorite-letter transfer is deferred.

Regression scene: res://tools/character_profile_test.tscn
Pass -- --preview in a graphical run to capture .godot/profile_preview.png.
