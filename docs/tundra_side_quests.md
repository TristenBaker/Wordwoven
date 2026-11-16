# Tundra side quests

Frozen Traveler uses 15 handcrafted four-blank tales in
`data/balance/traveler_stories.json`. Each entry has a stable `id`, a `title`,
`text` with numbered `{0}`–`{3}` placeholders, and a parallel `blanks` list.
POS codes are `n` (noun), `v` (base-form verb), `a` (adjective), and `r`
(adverb). Every current tale uses all four in varying order. Sentence frames
avoid indefinite articles and verb conjugation so creative answers fit reasonably.

A random tale is selected once when encounter progress is created. The previous
tale is excluded when another is available; this memory lasts for the current
application session, including new runs. Reopening an encounter resumes its stored
tale and words. Existing WordValidator/WordNet validation applies: trim and lowercase,
letters only, dictionary minimum length, required POS, and base-form verbs.
No meaning or answer list is checked, and repeated words are allowed. Invalid
entries change no progress. Next Blank acknowledges each accepted entry.

The final result shows the title and entire tale, with inserted words in uppercase
angle quotes (`‹TELESCOPE›`). It remains visible until Return to Map, including
when the completed encounter is reopened. Art, layout, theme, and route flow are
unchanged.

Rewards are configured in `data/balance/tuning.gd`:

| Encounter | Guaranteed reward | Bonus |
| --- | --- | --- |
| Frozen Traveler, completed tale | Heal ceil(max HP × 0.20), capped at max HP; 20 gold | 10% chance of one level-1 rolled letter item |
| Treasure Chest | 10 gold per opened lock (0/10/20/30) | 20% chance of one level-1 rolled letter item only if all three locks open |

Bonuses use the existing letter-drop rarity/element roller. They enter letter
inventory in itemized mode or the deck in legacy mode. Each successful completion
rolls once; skipping grants nothing. The completion claim is stored before rewards
emit signals, preventing duplicate or reentrant payouts. Chest adjective clues,
synonyms, two-guesses-per-lock rules, and UI remain unchanged apart from reward text.

Run `tools/tundra_minigames_test.tscn` for all templates, per-blank validation,
normalization, story rendering/persistence/layout, no immediate repeats, rewards,
bonus/no-bonus outcomes in both inventory modes, and duplicate-claim protection.
Also run `tundra_events_test`, `expedition_route_test`, `route_progression_test`,
`tundra_sim_test`, and `balance_test` in `tools/`.
