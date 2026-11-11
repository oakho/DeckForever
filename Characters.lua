--------------------------------------------------------------------------------
-- Every character on the same Deck UI, a new one from its first login, with no command to type.
-- What the other addons keep per character, or change for the whole account from one character, is
-- put back here; a reload is asked (A on a strip, top centre) when that changed what's on the screen.
--
-- At each login (any character):
--   * AishUI's setup per character (AishCore, AishUISetup.lua) kept quiet: its Edit Mode layout
--     ("AishUI", over ours), its EllesmereUI modules (the list below does it), and above all its
--     profile by role: answered "DPS" on a new character, it switched EllesmereUI's profile (the
--     account's: every character) to "AishUI - DPS Hide Bars". Never asked, any choice made forgotten.
--     Platynator set as AishUI sets it, as it loads (no popup).
--   * AishCore's and EllesmereUI's profiles: "Steam Deck" (tools/deckprofile/build.lua) in use.
--   * Placements.lua run on them (and Chattynator's, WaypointUI's): what we placed, as it is now.
--   * our Edit Mode layout (DeckForever.lua) and DynamicCam profile (Camera.lua): theirs, below.
-- At a character's first login with DeckForever (DeckForeverDB.chars, by GUID), once:
--   * its addons on or off as the Deck's (ADDONS_OFF off, the others on);
--   * Spoken's subtitles (its window style, per character: DialogueUI's window by default);
--   * Easy Controller's wheel bindings (per character): the consumables wheel, the "Quêtes" macro;
--   * GlowingBars' AFK rainbow and Lueur's gathering switch and "other" glow (per character).
-- Change one of these, or add one: here (and the README's list), never by hand in a single character.
--------------------------------------------------------------------------------

local _, ns = ...

local PROFILE = "Steam Deck"

-- off on the Deck (the others on): EllesmereUI's modules the game's or another addon's frames replace,
-- the addons it replaced (quest helpers, bags, the old error frame...), ones not made for a gamepad
local ADDONS_OFF = {}
for _, name in ipairs({
	"ControllerForever", "Ding", "OpenMap", "QuestMaster", "TomTom", "!Swatter", "!ImprovedErrorFrame",
	"HorizonSuite", "RXPGuides", "NiceDamage", "Syndicator", "Polestar", "Lorewalker", "Interaction",
	"ImprovedForever_Wheel", "FUI-RestedXP",
	"EllesmereUIActionBars", "EllesmereUIAuraBuffReminders", "EllesmereUIBags", "EllesmereUIBlizzardSkin",
	"EllesmereUIChat", "EllesmereUICooldownManager", "EllesmereUIDamageMeters", "EllesmereUINameplates",
	"EllesmereUIQuestTracker", "EllesmereUIFriends", "EllesmereUIGroupFinder", "EllesmereUIMythicTimer",
}) do ADDONS_OFF[name] = true end

-- Easy Controller: a button (its "trigger:modifier" key) to what it does, unless the character has its own
local EC_MAPPING = { ["TR4:"] = "wheel:consumables", ["TR4:LT"] = "macro:Quêtes" }

local function Print(msg) print("|cff66ccffDeckForever|r : " .. msg) end

------------------------------------------------------------------ the reload
-- Asked on a strip in the look of the game's gamepad legends, top centre: A reloads, B leaves it for
-- later (the next reload applies it). Not a game popup (shown by an addon, it taints the gamepad UI as
-- it closes: SetPreferredGamepadInteractTarget forbidden, seen), not ReloadUI from a timer (blocked:
-- only from a button press), not override bindings on A / B (another addon's, Easy Controller's, came
-- first: A opened the chat). The strip takes the pad's A and B itself while it's shown (its own
-- gamepad input, as Easy Controller's capture does; the other buttons go on to the game), out of
-- combat: hidden in a fight, shown again after.
local M = 8
local reasons, pending = {}, false
local notice

-- the pad's glyph, as Improved Forever draws them (the pad's own style)
local function Glyph(key)
	local IF = rawget(_G, "ImprovedForever")
	local ok, text = pcall(function() return IF and IF.GlyphText and IF.GlyphText(key, 20) end)
	return ok and type(text) == "string" and text ~= "" and text or ("[" .. key .. "]")
end

local function Hide()
	if not notice then return end
	notice:Hide()
	if notice.EnableGamePadButton then pcall(notice.EnableGamePadButton, notice, false) end
end

local OURS = { PAD1 = true, PAD2 = true }
local function Build()
	notice = CreateFrame("Frame", "DeckForeverReloadNotice", UIParent)
	for _, atlas in ipairs({ "gamepad-footer-slot-bg", "gamepad-footer-slot-frameneutral" }) do
		local t = notice:CreateTexture(nil, "BACKGROUND")
		t:SetAtlas(atlas)
		t:SetAllPoints()
	end
	notice:SetFrameStrata("DIALOG")
	notice:SetPoint("TOP", UIParent, "TOP", 0, -120)
	notice.text = notice:CreateFontString(nil, "OVERLAY")
	notice.text:SetFont(GameTooltipText:GetFont(), 14, "")
	notice.text:SetPoint("CENTER")
	notice.text:SetJustifyH("CENTER")
	notice:Hide()
	notice:SetScript("OnGamePadButtonDown", function(self, button)
		-- (A and B stop here, the others go on)
		if not InCombatLockdown() then pcall(self.SetPropagateGamePadInput, self, not OURS[button]) end
		if button == "PAD1" then
			ReloadUI()
		elseif button == "PAD2" then
			Hide()
			print("|cff66ccffDeckForever|r : appliqué au prochain rechargement.")
		end
	end)
end

local function Show()
	if #reasons == 0 then return end
	if InCombatLockdown() then pending = true return end
	pending = false
	if not notice then Build() end
	notice.text:SetText(("|cff66ccffDeckForever|r a remis l'interface du Deck : %s.\n%s Recharger      %s Plus tard")
		:format(table.concat(reasons, ", "), Glyph("A"), Glyph("B")))
	notice:SetSize(notice.text:GetStringWidth() + 4 * M, notice.text:GetStringHeight() + 3 * M)
	notice:Show()
	if notice.EnableGamePadButton then pcall(notice.EnableGamePadButton, notice, true) end
end

-- (several pieces may ask in the same moment: one strip)
local soon
function ns.NeedReload(reason)
	for _, r in ipairs(reasons) do if r == reason then return end end
	reasons[#reasons + 1] = reason
	if not soon then soon = true C_Timer.After(1.5, function() soon = false Show() end) end
end

local fights = CreateFrame("Frame")
fights:RegisterEvent("PLAYER_REGEN_DISABLED")
fights:RegisterEvent("PLAYER_REGEN_ENABLED")
fights:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		if notice and notice:IsShown() then pending = true Hide() end
	elseif pending then
		C_Timer.After(1, Show)
	end
end)

------------------------------------------------------------------ helpers
local function Copy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = Copy(v) end
	return c
end

-- the paths where a and b differ (at most a few), kept in DeckForeverDB.lastDiff to see what changed
local function Diff(a, b, path, out)
	if #out >= 8 then return out end
	if type(a) ~= "table" or type(b) ~= "table" then
		-- (numbers as the files keep them: a float written back a hair off is the same)
		local same = a == b or (type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.001)
		if not same then out[#out + 1] = path .. " " .. tostring(a) .. " -> " .. tostring(b) end
		return out
	end
	for k, v in pairs(a) do Diff(v, b[k], path .. "." .. tostring(k), out) end
	for k, v in pairs(b) do if a[k] == nil then Diff(nil, v, path .. "." .. tostring(k), out) end end
	return out
end

------------------------------------------------------------------ AishUI's setup, quiet
-- (AishCore loads before us: its per-character table is there, its setup runs at PLAYER_LOGIN, after)
local function QuietAishSetup()
	if type(AishUISetupCharDB) ~= "table" then AishUISetupCharDB = {} end
	local done = AishUISetupCharDB
	done.editMode, done.ellesmere, done.ellesmereVerified = true, true, true
	done.platynator = true                -- (set below, as Platynator loads)
	done.roleNever, done.roleChoice = true, {}
	-- AishCore's own profile by spec: off (one profile, ours)
	local db = AishaddonDB
	if type(db) == "table" and type(db._specProfiles) == "table" then db._specProfiles.enabled = false end
end

-- Platynator: AishUI's profile and style (AishUISetup's SetupPlatynator), before Platynator reads them
local function PlatynatorProfile()
	local profiles = PLATYNATOR_CONFIG and PLATYNATOR_CONFIG.Profiles
	local prof = profiles and profiles.AishUI
	if not prof then return end
	if prof.designs and prof.designs["AishUI - DPS"] then prof.style = "AishUI - DPS" end
	PLATYNATOR_CURRENT_PROFILE = "AishUI"
end

------------------------------------------------------------------ the account's profiles
local function Profiles()
	local A = AishaddonDB
	if type(A) == "table" and type(A._profiles) == "table" and A._profiles[PROFILE] and A._globalProfile ~= PROFILE then
		A._globalProfile = PROFILE
		ns.NeedReload("profil AishCore")
	end
	local E = EllesmereUI
	if E and E.GetActiveProfileName and E.SwitchProfile and EllesmereUIDB and EllesmereUIDB.profiles
		and EllesmereUIDB.profiles[PROFILE] and E.GetActiveProfileName() ~= PROFILE then
		-- (its own switch: the live anchors and fonts back from the profile)
		local was = E.GetActiveProfileName()
		E.SwitchProfile(PROFILE)
		EllesmereUIDB.lastNonSpecProfile = PROFILE
		Print(("profil EllesmereUI « %s » remis (il était sur « %s »)."):format(PROFILE, tostring(was)))
		ns.NeedReload("profil EllesmereUI")
	end
end

local function Placements()
	local A = AishaddonDB and AishaddonDB._profiles and AishaddonDB._profiles[PROFILE]
	local E = EllesmereUIDB and EllesmereUIDB.profiles and EllesmereUIDB.profiles[PROFILE]
	if not (A and E and DeckPlacements) then return end
	EllesmereUIDB.unlockAnchors = EllesmereUIDB.unlockAnchors or {}
	local live = EllesmereUIDB.unlockAnchors
	local C = CHATTYNATOR_CONFIG and CHATTYNATOR_CONFIG.Profiles and CHATTYNATOR_CONFIG.Profiles.DEFAULT
	local W = rawget(_G, "WaypointDB_Global")
	local before = { Copy(A), Copy(E), Copy(live), Copy(C), Copy(W) }
	local ok, err = pcall(DeckPlacements, A, E, live, C, W)
	if not ok then Print("placements : " .. tostring(err)) return end
	local diff = {}
	for i, now in ipairs({ A, E, live, C or false, W or false }) do
		Diff(before[i] or false, now, ({ "A", "E", "live", "C", "W" })[i], diff)
	end
	DeckForeverDB.lastDiff = #diff > 0 and diff or nil
	if #diff > 0 then ns.NeedReload("placements") end
end

------------------------------------------------------------------ a new character
local function Addons(guid)
	local changed = false
	if not (C_AddOns and C_AddOns.GetNumAddOns) then return end
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		if name then
			local want = not ADDONS_OFF[name]
			local okState, state = pcall(C_AddOns.GetAddOnEnableState, name, guid)
			local on = okState and (state or 0) > 0
			if okState and on ~= want then
				pcall(want and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn, name, guid)
				changed = true
			end
		end
	end
	if changed then ns.NeedReload("addons") end
end

local function Spoken()
	local env = rawget(_G, "SpokenEnv")
	local addon = env and env.Addon
	if not (addon and addon.db and addon.SetPlayerStyle and addon.Profile) then return end
	if addon:Profile("Frame").Style ~= "subtitle" then
		addon:SetPlayerStyle("subtitle")
		ns.NeedReload("sous-titres Spoken")
	end
end

local function EasyController()
	local ec = rawget(_G, "ControllerKeyboard")
	local mapping = ec and ec.db and ec.db.settings and ec.db.settings.mapping
	if type(mapping) ~= "table" then return end
	local changed = false
	for key, action in pairs(EC_MAPPING) do
		-- (the table in use is the character's profile's: changed in place, kept at the logout)
		if mapping[key] == nil then mapping[key] = action changed = true end
	end
	if changed then ns.NeedReload("roues Easy Controller") end
end

local function CharacterSettings()
	local gb = rawget(_G, "GlowingBarsCharDB")
	if type(gb) == "table" and gb.isAfkRainbowOn ~= true then gb.isAfkRainbowOn = true ns.NeedReload("GlowingBars") end
	local lueur = rawget(_G, "LueurCharDB")
	if type(lueur) == "table" then
		lueur.categories = lueur.categories or {}
		if lueur.nodeSwitch ~= true or lueur.categories.other ~= true then
			lueur.nodeSwitch, lueur.categories.other = true, true
			ns.NeedReload("Lueur")
		end
	end
end

local function NewCharacter()
	local guid = UnitGUID("player")
	if not guid then return end
	DeckForeverDB.chars = DeckForeverDB.chars or {}
	if DeckForeverDB.chars[guid] then return end
	for _, step in ipairs({ function() Addons(guid) end, Spoken, EasyController, CharacterSettings }) do
		local ok, err = pcall(step)
		if not ok then Print(tostring(err)) end
	end
	DeckForeverDB.chars[guid] = UnitName("player") or true
	Print("personnage préparé pour le Deck.")
end

------------------------------------------------------------------ events
local function Run()
	if InCombatLockdown() then return false end
	if DeckForeverDB.testStrip then DeckForeverDB.testStrip = nil ns.NeedReload("test") end
	for _, step in ipairs({ Profiles, Placements, NewCharacter }) do
		local ok, err = pcall(step)
		if not ok then Print(tostring(err)) end
	end
	return true
end

local pending
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, a1, a2)
	if event == "ADDON_LOADED" then
		if a1 == "DeckForever" then
			DeckForeverDB = DeckForeverDB or {}
			pcall(QuietAishSetup)
		elseif a1 == "Platynator" then
			pcall(PlatynatorProfile)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if a1 or a2 then       -- (login or reload: after the other addons' own setup, 2 s on)
			C_Timer.After(2, function() pending = not Run() end)
		end
	elseif event == "PLAYER_REGEN_ENABLED" and pending then
		pending = not Run()
	end
end)
