-- Builds the "Steam Deck" profiles of AishUI (AishCore + EllesmereUI) from AishUI's own ones, in the
-- account's SavedVariables. Run with WoW CLOSED (the game rewrites SavedVariables when it quits).
--
--   lua build.lua <WTF/Account/<account>/SavedVariables>
--
-- AishUI is laid out for a big screen at UI scale 0.62. The Deck wants 0.96 (768 / 800 physical px).
-- Every offset measured from the screen is multiplied by K = 0.62 / 0.96, so each block keeps its place
-- on screen while drawn 1.55 times bigger; offsets between two blocks stay as they are (they are
-- drawn bigger with their blocks). Then the Deck changes (see DECK below).
local dir = arg[0]:match("^(.*)/[^/]*$") or "."
package.path = dir .. "/?.lua;" .. package.path
local sv = require("sv")

local SV = assert(arg[1], "usage: lua build.lua <SavedVariables dir>")
local NAME = "Steam Deck"
local FROM_SCALE, TO_SCALE = 0.62, 0.96
local K = FROM_SCALE / TO_SCALE

local function round(v) return math.floor(v * 10 + 0.5) / 10 end
local function scale(t, ...)
  for _, f in ipairs({ ... }) do
    if type(t[f]) == "number" then t[f] = round(t[f] * K) end
  end
end

---------------------------------------------------------------------------------------------- AishCore
do
  local path = SV .. "/AishCore.lua"
  local env, order = sv.load(path)
  local D = env.AishaddonDB
  local src = D._profiles[D._deckSource or D._globalProfile]
  if D._globalProfile == NAME then src = D._profiles[D._deckSource or "Default"] end
  assert(src, "AishCore: no source profile")
  local P = sv.copy(src)

  -- Blocks placed on UIParent (offsets from the screen)
  for _, k in ipairs({ "castBar", "focusCastBar", "targetCastBar", "location", "menuBar", "resourceCircle",
                       "rotationHelper", "skyriding", "addonCompartment" }) do
    if type(P[k]) == "table" then scale(P[k], "x", "y") end
  end
  for _, b in pairs(P.extraBars and P.extraBars.bars or {}) do scale(b, "x", "y") end
  for _, b in pairs(P.unitBars and P.unitBars.bars or {}) do scale(b, "x", "y") end

  -- DECK: the combat block stays centred on the screen, below and right of the character (which
  -- DeckForever's DynamicCam profile puts left of the centre), over the compact gamepad bar (its top
  -- 161 units up). The out-of-combat circles go with the character instead: by its left side, at its
  -- knees (measured at the default zoom: the character at 44 % of the width, its knees at 41 % of
  -- the height). They are placed in fractions of the screen (anchorPct, from the bottom left).
  local CX = 0
  if P.resourceCircle then P.resourceCircle.x = CX end
  if P.castBar then P.castBar.x, P.castBar.y = CX, 175 end   -- from the screen's bottom, over the gamepad bar
  if P.healthCircle then
    P.healthCircle.anchorPctX, P.healthCircle.anchorPctY, P.healthCircle.x, P.healthCircle.y = 0.394, 0.41, 0, 0
  end
  if P.outOfCombatResourceCircle then
    local c = P.outOfCombatResourceCircle
    c.anchorPctX, c.anchorPctY, c.x, c.y = 0.4006, 0.3925, 0, 0
  end

  -- DECK: the pet under the player, the target's target under the target (they were spread out on
  -- the sides, across the whole width). Unit bars sit by their BOTTOM on the screen's centre;
  -- "parent" layout = the reference bar's position + relX / relY.
  local bars = P.unitBars and P.unitBars.bars
  if bars then
    if bars.player then bars.player.x = CX - 179 end
    if bars.target then bars.target.x = CX + 179 end
    if bars.focus then bars.focus.x = CX + 450 end
    local under = -30
    if bars.pet then
      bars.pet.layout, bars.pet.mirrorOf, bars.pet.relX, bars.pet.relY = "parent", "player", 0, under
      bars.pet.width = 140
    end
    if bars.targettarget then
      bars.targettarget.layout, bars.targettarget.mirrorOf = "parent", "target"
      bars.targettarget.relX, bars.targettarget.relY = 0, under
      bars.targettarget.width = 140
    end
  end

  D._profiles[NAME] = P
  D._deckSource = D._deckSource or D._globalProfile
  D._globalProfile = NAME
  sv.save(path, env, order)
  print("AishCore: profile '" .. NAME .. "' from '" .. D._deckSource .. "', active")
end

---------------------------------------------------------------------------------------------- EllesmereUI
do
  local path = SV .. "/EllesmereUI.lua"
  local env, order = sv.load(path)
  local db = env.EllesmereUIDB
  local srcName = db._deckSource or db.activeProfile
  if srcName == NAME then srcName = db.lastNonSpecProfile end
  local P = sv.copy(assert(db.profiles[srcName], "EllesmereUI: no source profile"))

  -- Unlock-mode anchors: offsets from the screen's edges or centre
  for _, a in pairs(P.unlockLayout and P.unlockLayout.anchors or {}) do
    if type(a.target) == "string" and a.target:match("^SCREEN_") then
      scale(a, "offsetX", "offsetY", "edgeOffY", "edgeOffX")
      if type(a.edge) == "table" then scale(a.edge, "offset") end
    end
  end
  local uf = P.addons and P.addons.EllesmereUIUnitFrames
  for _, pos in pairs(uf and uf.positions or {}) do scale(pos, "x", "y") end

  db.profiles[NAME] = P
  local listed = false
  for _, n in ipairs(db.profileOrder or {}) do listed = listed or n == NAME end
  if not listed then table.insert(db.profileOrder, 1, NAME) end
  db._deckSource = srcName
  db.activeProfile = NAME
  db.lastNonSpecProfile = NAME
  db.ppUIScale = TO_SCALE
  sv.save(path, env, order)
  print("EllesmereUI: profile '" .. NAME .. "' from '" .. srcName .. "', active, UI scale " .. TO_SCALE)
end
