--------------------------------------------------------------------------------
-- A DynamicCam profile for the Deck (/df camera): AishUI's "Immersion" (its character off centre, the
-- camera closer in a fight, further mounted...), copied as a profile of its own ("DeckForever") and
-- made the one in use, the character raised on the screen: the Deck's screen is small, and the bars of
-- a fight (AishCore's, over the gamepad bar) stand up to about 37 % of its height. "Immersion" itself
-- is left as it is; run again to copy it anew (after an AishUI update). Nothing without DynamicCam.
--------------------------------------------------------------------------------

local _, ns = ...

local PROFILE = "DeckForever"
local SOURCE = "Immersion"

-- the character raised: DynamicCam's dynamic pitch pad (higher: the character higher on the screen)
-- up by PITCH_RAISE in its standard settings and in every situation that sets its own, at most PITCH_MAX
local PITCH = "test_cameraDynamicPitchBaseFovPad"
local PITCH_RAISE, PITCH_MAX = 0.54, 1          -- (0.36 left its feet at 35 % up, under the top of a fight's bars)

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
	local function Raise(cvars)
		local v = cvars and tonumber(cvars[PITCH])
		if v then cvars[PITCH] = math.min(PITCH_MAX, v + PITCH_RAISE) end
	end
	Raise(profile.standardSettings and profile.standardSettings.cvars)
	for _, situation in pairs(profile.situations or {}) do
		Raise(situation.situationSettings and situation.situationSettings.cvars)
	end
	DC:RefreshConfig()
	Uncentre()
	print(("profil caméra « %s » de DynamicCam actif : « %s » d'AishUI, le personnage plus haut."):format(PROFILE, SOURCE))
end
