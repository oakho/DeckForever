# DeckForever

A World of Warcraft addon that fits the interface to the Steam Deck's screen (1280×800), on top of
Blizzard's gamepad UI and addons like [Easy Controller](https://github.com/moust4ki/EasyControllerWowForever).

Made for **WoW Forever** (Interface 16001) played with a gamepad.

## What it does

- **A layout for the Deck.** An Edit Mode layout named *DeckForever*, with every element 8 px from
  the screen's edges and nothing overlapping:
  - a thin XP bar along the whole bottom edge, in Blizzard's colours;
  - the compact gamepad bar at the bottom;
  - the player and target frames either side of the character, with the cooldown rows centred
    between them;
  - the chat in the bottom-left corner, without its tabs, its input line over its top while you type;
  - the gamepad help in the top-left corner;
  - a square minimap in the bottom-right corner, with a tooltip-style border;
  - the game's tooltip in the top-right corner (the quests fade under it).
- **A lighter gamepad help.** Blizzard's legend, redrawn with short labels, columns that fit the
  text and the look of the game's tooltips. It shows the same groups (at rest, LB, RB, LB + RB,
  menus) and follows the options' button swaps.
- **Combat mode.**
  - In combat, what isn't needed fades: the minimap, the quests, the XP bar and the gamepad help
    (back as you hold LB or RB).
  - Out of combat, with no target, the player frame, the gamepad bars and the cooldown rows fade, so
    you see the world.

DeckForever only moves, scales and fades frames. It replaces no Blizzard function and changes no
binding: the gamepad UI of this client blocks its own actions as soon as an addon's code gets into
it. The protected frames are faded through a secure state driver, the game's own mechanism for that.

## Install

Clone or download into your game's `Interface/AddOns/DeckForever` folder (the folder must be
named `DeckForever`), then restart the game.

## Commands

| Command | |
|---|---|
| `/df go` | Creates the *DeckForever* layout and makes it the one in use (then `/reload`). |
| `/df back` | Goes back to the layout it was copied from. |
| `/df fx` | Shows the combat fades out of combat, to look at them (display only). |

`/df go` copies a layout named *SteamDeck* if you have one, else the layout in use, else the game's
*Gamepad* layout. Your other layouts are left untouched, and a copy of them as they were is kept in
the addon's saved variables.

## License

[MIT](LICENSE)
