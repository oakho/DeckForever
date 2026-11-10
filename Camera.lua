--------------------------------------------------------------------------------
-- A DynamicCam profile for the Deck (/df camera): AishUI's "Immersion" (its character off centre, the
-- camera closer in a fight, further mounted...), copied as a profile of its own ("DeckForever") and
-- made the one in use, the character raised on the screen in a fight: the Deck's screen is small, and
-- a fight's bars (AishCore's, over the gamepad bar) stand up to about 37 % of its height. Out of one,
-- Immersion's own view. "Immersion" itself is left as it is; run again to copy it anew (after an
-- AishUI update). Nothing without DynamicCam.
--------------------------------------------------------------------------------

local _, ns = ...

local PROFILE = "DeckForever"
local SOURCE = "Immersion"

-- the character raised in a fight: DynamicCam's dynamic pitch pad (higher: the character higher on the
-- screen) up by PITCH_RAISE in each fight situation (DynamicCam's ids: world, dungeon boss / trash, raid
-- boss / trash, arena, battleground), from its own pad or else the standard one, at most PITCH_MAX.
-- (Out of a fight, +0.54 put its feet at 41 % up, from 21 %)
local PITCH = "test_cameraDynamicPitchBaseFovPad"
local PITCH_RAISE, PITCH_MAX = 0.54, 1
local FIGHTS = { "006", "023", "024", "033", "034", "051", "061" }

-- The game's "keep the character centred" (motion sickness) option cancels the shoulder offset. With
-- a controller, Blizzard's gamepad code holds it on in a temporary layer over the saved setting (so
-- setting it alone does nothing): off in both, whatever DynamicCam profile is in use (AishUI's
-- "Immersion" and "Default" put the character to a side too, and stayed centred), at each login and
-- each time the controller comes back
local CENTRED = "CameraKeepCharacterCentered"
local function Uncentre()
	if C_CVar and C_CVar.SetTempCVar then pcall(C_CVar.SetTempCVar, CENTRED, "0") end
	if GetCVar(CENTRED) ~= "0" then SetCVar(CENTRED, 0) end
end

local function DynamicCam()
	local ace = LibStub and LibStub("AceAddon-3.0", true)
	return ace and ace:GetAddon("DynamicCam", true)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
for _, e in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED" }) do pcall(f.RegisterEvent, f, e) end
f:SetScript("OnEvent", function()
	-- (after the gamepad code has set its own layer)
	if DynamicCam() then C_Timer.After(0.5, Uncentre) end
end)

function ns.CameraProfile(print)
	local DC = DynamicCam()
	if not (DC and DC.db) then print("DynamicCam n'est pas chargé.") return end
	if InCombatLockdown() then print("pas en combat.") return end
	if not rawget(DC.db.profiles, SOURCE) then print(("pas de profil « %s » dans DynamicCam (celui d'AishUI)."):format(SOURCE)) return end
	DC.db:SetProfile(PROFILE)
	DC.db:CopyProfile(SOURCE, true)
	local profile = DC.db.profile
	local standard = tonumber(profile.standardSettings and profile.standardSettings.cvars[PITCH]) or 0.3
	for _, id in ipairs(FIGHTS) do
		local situation = profile.situations and profile.situations[id]
		local settings = situation and situation.situationSettings
		if settings then
			settings.cvars = settings.cvars or {}
			settings.cvars[PITCH] = math.min(PITCH_MAX, (tonumber(settings.cvars[PITCH]) or standard) + PITCH_RAISE)
		end
	end
	DC:RefreshConfig()
	Uncentre()
	print(("profil caméra « %s » de DynamicCam actif : « %s » d'AishUI, le personnage plus haut en combat."):format(PROFILE, SOURCE))
end
