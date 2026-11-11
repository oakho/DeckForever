# DeckForever

WoW addon fitting the HUD to the Steam Deck (1280×800), on top of Blizzard's gamepad UI and Easy
Controller. Client: WoW Forever / classic beta, Interface 16001, played with a gamepad in Game Mode.
User-facing strings are French; code and comments are English.

- `DeckForever.lua`: the Edit Mode layout (`LAYOUT`, written by `/df go`), the frames placed by hand
  (minimap, chat, tooltip, quests, class action), the fader (combat mode, `FADED`), the secure state
  driver (`CalmDriver`), the XP bar, fonts.
- `Legend.lua`: our gamepad help, redrawn from Blizzard's `GamepadPersistentInputLegend`.
- `Characters.lua`: every character on the Deck's UI from its first login, no command: AishUI's
  per-character setup kept quiet, the "Steam Deck" profiles back in use, `Placements.lua` applied,
  a new character's addons and per-character settings; the reload strip (`ns.NeedReload`). Anything
  new that lives per character, or that another addon changes for one, goes there.
- `Placements.lua`: where AishUI's blocks go (AishCore, EllesmereUI, Chattynator, WaypointUI
  profiles); run at each login, by `tools/deckprofile/build.lua` and by !DiagErreurs' F10.
- `Waypoint.lua`: TomTom's arrow on the followed (or closest watched) quest; TomTom's own quest
  integration is retail-only (this client is WOW_PROJECT_ID 18).
- `tools/`: dev only (not packaged): in-game test scripts and the `!DiagErreurs` diagnostics addon.

## Rules learned the hard way (taint)

This client's gamepad UI blocks `SetPreferredGamepadInteractTarget` as soon as addon code gets into
its execution path; the forbidden-action popup then re-triggers the block (freeze; `!AntiFreezeManette`
breaks the loop). So:

- Never replace a Blizzard function or method. Never call `SetAlpha`/`Show`/`Hide` on protected frames
  (PlayerFrame, gamepad bars) from addon code: use the secure state driver (`CalmDriver`).
- `hooksecurefunc` errors ("attempt to call a nil value" in `[C]`) when one hooked function calls
  another hooked one (seen: legend ShowGroup → HideAllGroups, GameTooltip_SetDefaultAnchor → SetOwner,
  frames' Show, CooldownViewer Layout). The error leaves execution tainted. Prefer reading state on
  a timer/OnUpdate over hooking; hook at most one function per call chain.
- Don't resize Blizzard containers whose OnSizeChanged runs layout code (quest tracker): move or
  narrow their children instead.
- Some text is a secret value (unit bars): never compare or concatenate it; wrap reads in `pcall`.
- With a controller, Blizzard's gamepad code holds some CVars in a temporary layer over the saved
  value (`CameraKeepCharacterCentered` = 1, which cancels any camera shoulder offset): `SetCVar` then
  "works" but changes nothing; use `C_CVar.SetTempCVar` too, again when the controller comes back.
- A game popup (`StaticPopup_Show`) from addon code taints the gamepad UI as it closes
  (SetPreferredGamepadInteractTarget forbidden). `ReloadUI` only works from a button press, and
  override bindings on PAD1/PAD2 lose to Easy Controller's: to take A/B, a frame's own
  `OnGamePadButtonDown` (`EnableGamePadButton`, `SetPropagateGamePadInput` per button).
- New .lua files in the .toc load only after the client restarts, not at a `/reload`.
- Edit Mode settings that exist in `Enum` may do nothing in this client (StatusTrackingBar
  Width/Height): measure before relying on one.

## Layout conventions

- `M = 8`: gap between the screen's edges and every block, measured on the *visible* border
  (background or tooltip border), not the frame rect or the text. `B = M + 4` from the bottom
  (over the 4 px XP bar).
- UIParent scale 0.96: survey units × 800/768 = Deck pixels.
- Nothing overlaps; check with `tools/cycle.sh` after every layout change.

## Testing in game (see the `ingame-test` skill)

WoW runs in Desktop Mode under Proton; drive it with `xdotool` (window "World of Warcraft") and
`spectacle`. Simulated input is allowed for UI testing only, never for gameplay.

- `tools/cycle.sh NAME [go]`: reload, optional `/df go`, screenshot, survey, overlap and error report.
- Keyboard is AZERTY: `xdotool type` mangles q/a/z/w/m; avoid them in typed commands.
- Easy Controller's on-screen keyboard opens with the chat: close it with its X (click 1070,358).
- Never press Escape blindly (opens the game menu). Never click the forbidden-action popup.
- Don't use a virtual uinput pad: it made the game drop the Deck's controller.

## Git

Repo `oakho/DeckForever` (remote `git@github-deckforever:oakho/DeckForever.git`), branch `main`.
Commit and push after each change the user validates. `core.fileMode` is off (Proton flips modes).
