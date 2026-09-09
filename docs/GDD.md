# Lexical Rogue: Godot Prototype Game Design Document

## 1. Game Idea & High-Level Concept
The purpose of this prototype is to validate the core fantasy: Mad Libs meets a roguelike deckbuilder. Players spell words for requested parts of speech, counter enemy tags for bonus damage, and read a short story of each monster's defeat using their exact words.

*   **Genre:** Roguelike deckbuilder / Word puzzle RPG.
*   **Perspective & Tone:** 2D card-game layout heavily inspired by Balatro, set within a fantasy tavern aesthetic.
*   **Players:** Single-player.
*   **Core Design Thesis:** Combat effectiveness combines word length, letter classes and levels, prompted parts of speech, and thematic or antonym counters to the enemy's nature through Princeton's WordNet database.
*   **Progression:** Earn gold in fights, recruit new letters or pay to dismiss letters at the tavern, and level letters through use in accepted words. Choose one free passive relic after every victory, including the boss.

## 2. Core Features & Gameplay Loop
The prototype must prioritize the following core systems to build a functional loop.

*   **Core Game Loop:** Enter fight -> draw letters -> read the enemy tags and POS prompt -> submit a valid word, preferably a counter -> enemy retaliates -> win and earn gold -> read the Mad Libs victory story and choose a free relic -> recruit, dismiss, or heal at the tavern -> hear completed stories -> choose the next encounter -> defeat the boss.
*   **Win/Loss Conditions:** The win state is making it to and defeating the final boss. The loss state is the player's health reaching zero during combat.
*   **The World/Map:** A run-based progression system where players choose their next encounter after visiting the tavern.
*   **Base/Hub:** The Tavern offers letter recruitment, paid dismissal, and a healing meal. The bard recounts completed encounters in order using every accepted player word and the defeated monster's identity.
*   **Architecture:** Standalone Godot 4.7 single-player client with pure GDScript WordNet processing behind the WordNet autoload.

## 3. Detailed Specifications

### Core Entities & AI
*   **Enemies:** Enemies are entities with health pools and attack values that spawn with random word tags (e.g., "big" or "fiery"). 
*   **Letter Characters:** Each letter has a category-defined class and an individual level. Vowels AEIOU are Healers; common consonants BCDFGHLMNPRST are Warriors; uncommon consonants JKQVWXYZ are Rogues. Duplicate recruited copies are independent resources.
*   **The NLP Storyteller:** Generates a stable two-to-five-sentence victory story from accepted words, grouping exact inputs in POS-specific sentence slots and ending with the monster's defeat. Unused slots are omitted. Encounter numbers keep repeated monster names separate. Victory rewards show the story immediately; the tavern bard shows completed stories in order.

### Player Movement & Controls
*   Required player states: Navigating UI, Deck Management, Combat Drafting.
*   **Word Drafting:** Players draw a hand of letters and attempt to make a word using as many drawn letters as possible. Players can use letters not in their hand to complete words, but are mechanically encouraged to rely on their drawn hand.
*   **Mad Libs Prompt:** Require noun -> base-form verb -> adjective -> adverb, advancing only after accepted words and rotating the first prompt between encounters. Reject words that fail dictionary, spelling, uniqueness, or requested-POS validation without consuming a turn. The prompted POS controls damage for words with multiple parts of speech.

### Core Interactions & Systems
*   **Damage Calculation:** Damage is calculated by considering the length of the word, the number of drawn characters used, character modifiers and classes, the word's part of speech, and the individual character levels.
*   **Counter Combat (WordNet Integration):** Curated thematic counters cover every enemy tag and prompted POS; WordNet contributes antonyms and counter synonyms. Direct counters, their inflections, and antonyms score 1.0; counter synonyms score 0.9. Same-tag words, tag synonyms, and unrelated words score 0. The semantic multiplier is `0.5 + 1.5 * counter_score`, plus Tome bonuses. Countering is optional; every accepted word can deal damage. Generic similarity APIs remain available for other callers.
*   **Class Effects and Levels:** Each drawn Healer restores HP equal to its level; each drawn Warrior adds twice its level to damage power; each drawn Rogue grants twice its level in gold. Every letter also contributes its existing base power and level scaling. Apply effects at the current level, then raise each used drawn instance exactly one level. Undrawn letters contribute 20% base power and no class or leveling effect.
*   **Starting Party:** One copy of every vowel and common consonant, 18 level-1 letters total, with 50 HP and zero gold.
*   **Recruitment and Dismissal:** Six distinct random alphabet offers per tavern visit, including at least one uncommon consonant. Each offer can be purchased once; persist offers and purchased flags until another completed encounter. Existing-party duplicates are permitted and begin at level 1. Recruitment costs 10g for vowels/common consonants or 20g for uncommon consonants. Dismissal costs 10g and cannot reduce the party below ten. A meal costs 15g and heals 10 HP. Remove training, forging, and the relic shelf.
*   **Fight Rewards:** Rat 24g, goblin 32g, myconid 40g, skeleton 48g, flying eye 56g, dragon 120g. Pay victory gold once using relics owned before the new choice.
*   **Free Relic Choice:** Offer three random relics from the expanded catalog after each victory, including the boss. Copies stack: Quill of Fortune grants +5 victory gold; Iron Bookmark adds 10 maximum health and heals 10; Tome of Echoes adds 0.12 to the semantic multiplier; Lantern of Insight makes counter synonyms as strong as direct counters; Traveler's Satchel grants +3 victory gold; and Red Thread draws one extra letter into every combat hand. Separate guards prevent repeated victory payouts and multiple selections for one encounter. Relic catalog/granting logic is separate from tavern spending.

## 4. Technical Implementation Scope
The AI agent can take whatever development path it likes to build the prototype, but it must keep strictly to this list of features to implement—and absolutely no more.

1.  Balatro-style 2D UI layout for combat and tavern screens.
2.  Deck structure and letter drawing logic.
3.  Word input with dictionary, spelling, uniqueness, and prompted-POS validation.
4.  WordNet counter scoring and part-of-speech tagging, preserving generic similarity APIs.
5.  Enemy spawning with assigned random word tags.
6.  Damage math factoring in letter classes, existing modifiers, levels, and NLP counters.
7.  Turn-based combat state machine (Player drafts word -> Enemy takes damage -> Enemy retaliates).
8.  Tavern recruitment, paid letter dismissal, and healing meals; free post-victory relic selection.
9.  Encounter selection menu.
10. Mad Libs stories on the victory screen and at the tavern bard.

**Non-Goals:** Do not implement real-time combat, 3D graphics, multiplayer, grid-based movement, or complex visual attack animations.

## 5. Architectural & Code Design Guidelines
To ensure the prototype is maintainable and easily expandable in the future, adhere to the following code design disciplines:
*   **No God Objects:** Do not design monolithic "Core", "Game", or "GameManager" objects that handle everything.
*   **Separation of Concerns:** Split functionality into distinct, focused objects and node components for clarity (e.g., separate `WordValidator`, `SemanticScorer`, `DeckManager`, `EconomySystem`).
*   **Loose Coupling:** Ensure objects are not tightly coupled. Use Godot's signal system to communicate between disconnected systems rather than hardcoding node paths or direct script references. WordNet processing must remain behind the WordNet autoload. Preserve existing EventBus signatures and add optional trailing POS parameters to validation, damage, and history interfaces.

## 6. Debugging & Developer Tools
Implement dedicated debug capabilities to accelerate testing and iteration. Specific implementations are game-dependent, but should generally include:
*   **Debug Menu/Shortcuts:** Include a simple way to toggle debug features (e.g., a hidden UI overlay or specific F-keys).
*   **Game-Specific Testing Tools:** Add debug buttons to instantly draw specific letters, force-spawn an enemy with a specific semantic tag (e.g., force "fiery"), skip to the tavern, and grant infinite gold.
*   **NLP Debugging:** Display a visual damage breakdown with counter score and strategy, prompted-POS multiplier, class effects, and letter modifier bonuses. The live tester evaluates counters against enemy tags.
