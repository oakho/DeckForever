--------------------------------------------------------------------------------
-- A DynamicCam profile for the Deck (/df camera): AishUI's "Immersion" (its character off centre, the
-- camera closer in a fight, further mounted...), copied as a profile of its own ("DeckForever") and
-- made the one in use, the character raised on the screen, more in a fight: the Deck's screen is small,
-- and a fight's bars (AishCore's, over the gamepad bar) stand up to about 37 % of its height; the moves
-- into and out of a fight eased. "Immersion" itself is left as it is; run again to copy it anew (after an
-- AishUI update). Nothing without DynamicCam.
--------------------------------------------------------------------------------

local _, ns = ...

local PROFILE = "DeckForever"
local SOURCE = "Immersion"

-- the character raised: DynamicCam's dynamic pitch pad (higher: the character higher on the screen) up by
-- PITCH_RAISE in each fight situation (DynamicCam's ids: world, dungeon boss / trash, raid boss / trash,
-- arena, battleground), from its own pad or else the standard one, and by CALM_RAISE out of a fight (the
-- standard pad, and each other situation's own); at most PITCH_MAX. (+0.54 put its feet at 41 % up,
-- from Immersion's 21 %)
local PITCH = "test_cameraDynamicPitchBaseFovPad"
local PITCH_RAISE, CALM_RAISE, PITCH_MAX = 0.54, 0.18, 1
local FIGHTS = { "006", "023", "024", "033", "034", "051", "061" }
-- into and out of a fight in that long, seconds (Immersion's: 0.2 in, 0 out: sharp)
local FIGHT_IN, FIGHT_OUT = 0.8, 1.5

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
	local cvars = profile.standardSettings.cvars
	local standard = tonumber(cvars[PITCH]) or 0.3
	cvars[PITCH] = math.min(PITCH_MAX, standard + CALM_RAISE)
	local fight = {}
	for _, id in ipairs(FIGHTS) do fight[id] = true end
	for id, situation in pairs(profile.situations or {}) do
		local settings = situation.situationSettings
		if settings then
			settings.cvars = settings.cvars or {}
			local own = tonumber(settings.cvars[PITCH])
			if fight[id] then
				settings.cvars[PITCH] = math.min(PITCH_MAX, (own or standard) + PITCH_RAISE)
				situation.transitionTime = situation.transitionTime or {}
				situation.transitionTime.timeToEnter, situation.transitionTime.timeToExit = FIGHT_IN, FIGHT_OUT
			elseif own then
				settings.cvars[PITCH] = math.min(PITCH_MAX, own + CALM_RAISE)
			end
		end
	end
	DC:RefreshConfig()
	Uncentre()
	print(("profil caméra « %s » de DynamicCam actif : « %s » d'AishUI, le personnage plus haut, plus encore en combat."):format(PROFILE, SOURCE))
end
