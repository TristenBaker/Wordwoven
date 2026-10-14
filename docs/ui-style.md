# UI style

The project default is `assets/Themes/Default_UI_Theme.tres`, configured
under `gui/theme/custom`. Both scene controls and dynamically created
controls inherit it.

- Use Junicode for body text and controls, with Junicode Bold for rich-text
  emphasis. Keep Black Chancery for prominent screen titles.
- Use 20–22 px body text and at least 18 px for menu descriptions and hints.
  Reserve smaller type for compact gameplay metadata.
- Use warm ivory text on dark ink panels, muted gold borders, and a 6 px
  corner radius. Keep padding appropriate to the content and screen.
- Action buttons use the explicit WordWovenActionButton variation from
  WordWoven_Button_Theme.tres; dropdowns use WordWovenOptionButton.
- Preserve element, rarity, enemy, and status colors on gameplay cards.
  Do not apply decorative action frames to letter or enemy cards.
- Keep controls at their intended display scale so text and focus rings
  remain readable. Allow descriptive text to wrap or scroll.

Run `tools/ui_style_test.tscn` headlessly to verify scene loading, action
styles, gameplay card isolation, button sizing, and interaction wiring.
Run `tools/ui_preview.tscn` with the compatibility renderer to save eight
representative 1280 × 720 screenshots under `.godot/ui-preview`.
