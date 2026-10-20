---
name: ingame-test
description: Check a DeckForever change in the running game on the Steam Deck - reload, apply the layout, screenshot, measure every HUD block (gaps to the edges, overlaps) and report Lua errors and blocked actions. Use after any change to DeckForever's code, before telling the user it works or committing.
---

# In-game test of DeckForever

WoW must be running (Desktop Mode) with `!DiagErreurs` enabled. Install it once if missing:
`cp -r "tools/!DiagErreurs" ..` (it lives in `Interface/AddOns`, next to DeckForever).

## 1. Syntax first

`luac -p DeckForever.lua Legend.lua` — a syntax error only shows in game as a missing addon.

## 2. The cycle

```
OUT=/path/in/scratchpad tools/cycle.sh NAME        # code change only
OUT=/path/in/scratchpad tools/cycle.sh NAME go     # LAYOUT changed: rewrites the Edit Mode layout
```

Takes about 2 minutes (three reloads). Output:
- `$OUT/NAME.png`: the screenshot (1280×800).
- `$OUT/NAME.lua`: `DiagErreursDB` (errors, blocked actions, frame rects, Edit Mode layouts, fonts,
  chat textures, XP bar structure).
- stdout: each HUD block in Deck pixels with its gaps to the edges (g/d/h/b), the overlaps, then
  errors and blocked actions. Anything under "erreurs / actions bloquées" is a regression.

Blocked counts are per session: the first reload of the cycle saves the *previous* session (the
user's own play), so a block there may be older than the change. Read `started` in `NAME.lua`.

## 3. Look

Crop and zoom with ffmpeg, then read the image:
```
ffmpeg -loglevel error -y -i $OUT/NAME.png -vf "crop=W:H:X:Y,scale=4*W:-1:flags=neighbor" $OUT/NAME-z.png
```
Check visible borders, not rects: a block's background or tooltip border may sit outside its frame
(the chat's background reaches 6 px below and 2 px left of it; tooltip-style borders are drawn 2 px
inside their frame).

## 4. Probes (typed in game with tools/wowcmd.sh)

- `/dgp X Y`: every shown frame under screen pixel X, Y (saved in `probe` at the next reload).
- `/dgt`: shows a test tooltip at the default place for 3 s (rect in `tooltip`).
- `/df fx`: shows the combat fades out of combat (display only); again to stop.
- To open the chat's input line: `xdotool key Return`; close it with `Return` then click 1070,358
  (Easy Controller's keyboard). Never Escape.

Add a survey to `tools/!DiagErreurs/DiagErreurs.lua` (and copy it to `../!DiagErreurs`) when a
question needs data the survey doesn't keep yet. Wrap reads of unit text in `pcall` (secret values).

## 5. Report

Tell the user what was measured (numbers), what was seen, and what could not be tested from the
desktop (real gamepad input, combat): those need their check in Game Mode.
