-- Builds the "Steam Deck" profiles of AishUI (AishCore, EllesmereUI) from AishUI's own ones
-- (and places Chattynator's window),
-- in the account's SavedVariables. Run with WoW CLOSED (the game rewrites SavedVariables when it quits).
--
--   lua build.lua <WTF/Account/<account>/SavedVariables>
--
-- AishUI is laid out for a big screen at UI scale 0.62; the Deck wants 0.96 (768 / 800 physical px).
-- Every offset measured from the screen is first multiplied by K = 0.62 / 0.96, so each block keeps its
-- place on screen while drawn 1.55 times bigger (offsets between two blocks stay: they grow with their
-- blocks). Then placements.lua puts the blocks where the Deck wants them. Rerun after an AishUI update:
-- its installer rewrites these SavedVariables; each profile is built again from AishUI's (_deckSource).
local dir = arg[0]:match("^(.*)/[^/]*$") or "."
package.path = dir .. "/?.lua;" .. package.path
local sv = require("sv")
dofile(dir .. "/placements.lua")

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

local files = {}
local function open(name)
	local path = SV .. "/" .. name .. ".lua"
	local env, order = sv.load(path)
	files[#files + 1] = { path = path, env = env, order = order }
	return env
end

-------------------------------------------------------------------------------------------- AishCore
local D = open("AishCore").AishaddonDB
if D._globalProfile ~= NAME then D._deckSource = D._globalProfile end
D._deckSource = D._deckSource or "Default"
local A = sv.copy(assert(D._profiles[D._deckSource], "AishCore: no source profile"))
-- blocks placed on UIParent (offsets from the screen)
for _, k in ipairs({ "castBar", "focusCastBar", "targetCastBar", "location", "menuBar", "resourceCircle",
                     "rotationHelper", "skyriding", "addonCompartment" }) do
	if type(A[k]) == "table" then scale(A[k], "x", "y") end
end
for _, b in pairs(A.extraBars and A.extraBars.bars or {}) do scale(b, "x", "y") end
for _, b in pairs(A.unitBars and A.unitBars.bars or {}) do scale(b, "x", "y") end
D._profiles[NAME] = A
D._globalProfile = NAME

-------------------------------------------------------------------------------------------- EllesmereUI
local db = open("EllesmereUI").EllesmereUIDB
if db.activeProfile ~= NAME then db._deckSource = db.activeProfile end
local E = sv.copy(assert(db.profiles[db._deckSource], "EllesmereUI: no source profile"))
-- unlock-mode anchors: offsets from the screen's edges or centre. EllesmereUI works with the live ones
-- (EllesmereUIDB.unlockAnchors, the account's); the profile keeps a copy: the source's copy for both
local function anchors(list)
	for _, a in pairs(list) do
		if type(a.target) == "string" and a.target:match("^SCREEN_") then
			scale(a, "offsetX", "offsetY", "edgeOffY", "edgeOffX")
			if type(a.edge) == "table" then scale(a.edge, "offset") end
		end
	end
end
E.unlockLayout = E.unlockLayout or {}
E.unlockLayout.anchors = E.unlockLayout.anchors or {}
anchors(E.unlockLayout.anchors)
db.unlockAnchors = sv.copy(E.unlockLayout.anchors)
-- the modules' own positions on the screen (a point and x / y, e.g. the minimap's)
local function positions(t, depth)
	if depth > 6 then return end
	if type(t.point) == "string" and (t.relPoint or t.relativePoint) and type(t.x) == "number" then scale(t, "x", "y") end
	for _, v in pairs(t) do if type(v) == "table" then positions(v, depth + 1) end end
end
positions(E.addons or {}, 0)
local uf = E.addons and E.addons.EllesmereUIUnitFrames
for _, pos in pairs(uf and uf.positions or {}) do scale(pos, "x", "y") end
db.profiles[NAME] = E
local listed = false
for _, n in ipairs(db.profileOrder or {}) do listed = listed or n == NAME end
if not listed then table.insert(db.profileOrder, 1, NAME) end
db.activeProfile, db.lastNonSpecProfile, db.ppUIScale = NAME, NAME, TO_SCALE

-------------------------------------------------------------------------------------------- Chattynator
-- (one profile, DEFAULT: set in place)
local ct = open("Chattynator").CHATTYNATOR_CONFIG
local C = ct and ct.Profiles and ct.Profiles.DEFAULT

-------------------------------------------------------------------------------------------- the Deck
DeckPlacements(A, E, db.unlockAnchors, C)
for _, f in ipairs(files) do sv.save(f.path, f.env, f.order) end
print(("'%s' built and active: AishCore from '%s', EllesmereUI from '%s' (UI scale %s)")
	:format(NAME, D._deckSource, db._deckSource, TO_SCALE))
