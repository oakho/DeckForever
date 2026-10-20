--------------------------------------------------------------------------------
-- A DynamicCam profile for the Deck (/df camera): a natural camera, a little left of the character,
-- closer in combat and further out of it, further still mounted or in a vehicle. Written as a
-- DynamicCam profile of its own ("DeckForever"), made the one in use; your other profiles are left
-- as they are, and DynamicCam's options change it as any other. Run again to set it back to these
-- values. Nothing without DynamicCam.
--------------------------------------------------------------------------------

local _, ns = ...

local PROFILE = "DeckForever"

-- the camera itself (DynamicCam's standard settings: its cvars)
local CVARS = {
	test_cameraOverShoulder = -1,              -- the camera a little left of the character
	cameraDistanceMaxZoomFactor = 2.6,         -- up to 39 yards away (mounted, vehicles)
	-- the view tilts with the zoom, the character a little low in it (ActionCam's dynamic pitch)
	test_cameraDynamicPitch = 1,
	test_cameraDynamicPitchBaseFovPad = 0.35,
	test_cameraDynamicPitchBaseFovPadFlying = 0.75,
	test_cameraDynamicPitchBaseFovPadDownScale = 0.25,
	test_cameraDynamicPitchSmartPivotCutoffDist = 10,
	-- no head bobbing, no turning to enemies on its own; a light turn to whom you talk to
	test_cameraHeadMovementStrength = 0,
	test_cameraTargetFocusEnemyEnable = 0,
	test_cameraTargetFocusInteractEnable = 1,
	test_cameraTargetFocusInteractStrengthYaw = 0.5,
	test_cameraTargetFocusInteractStrengthPitch = 0.3,
}

-- the zoom by situation (DynamicCam's ids): kept within [min, max] yards, your own zoom free inside;
-- leaving a situation goes back to the one under it (combat → world)
local ZOOMS = {
	["004"] = { min = 11, max = 15 },          -- world
	["005"] = { min = 7, max = 10 },           -- world, indoors
	["001"] = { min = 9, max = 13 },           -- city
	["006"] = { min = 7, max = 9, enter = 0.75 }, -- world, combat
	["024"] = { min = 8, max = 10, enter = 0.75 }, -- dungeon, combat (trash)
	["023"] = { min = 10, max = 13, enter = 0.75 }, -- dungeon, combat (boss)
	["100"] = { min = 17, max = 22 },          -- mounted
	["170"] = { min = 20, max = 26 },          -- vehicle
}

function ns.CameraProfile(print)
	local DC = LibStub and LibStub("AceAddon-3.0", true) and LibStub("AceAddon-3.0"):GetAddon("DynamicCam", true)
	if not (DC and DC.db) then print("DynamicCam n'est pas chargé.") return end
	if InCombatLockdown() then print("pas en combat.") return end
	DC.db:SetProfile(PROFILE)
	local profile = DC.db.profile
	for cvar, value in pairs(CVARS) do profile.standardSettings.cvars[cvar] = value end
	for id, zoom in pairs(ZOOMS) do
		local situation = profile.situations[id]
		if situation then
			situation.enabled = true
			situation.viewZoom.enabled = true
			situation.viewZoom.viewZoomType = "zoom"
			situation.viewZoom.zoomType = "range"
			situation.viewZoom.zoomMin = zoom.min
			situation.viewZoom.zoomMax = zoom.max
			if zoom.enter then situation.transitionTime.timeToEnter = zoom.enter end
		end
	end
	DC:RefreshConfig()
	print(("profil caméra « %s » de DynamicCam actif (réglable dans ses options)."):format(PROFILE))
end
