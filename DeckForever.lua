--------------------------------------------------------------------------------
-- DeckForever: an interface made for the Steam Deck's screen (1280x800), on top of Blizzard's
-- gamepad UI and the addons that build on it (Easy Controller's back paddles hang off the
-- gamepad bars, so they follow wherever the bars go). It only moves and scales frames: no
-- Blizzard method is replaced and no binding is touched.
--   * the gamepad help redrawn for the Deck, bottom-left (Legend.lua)
--   * the class action (a paladin's aura) under the middle of the compact bar
--   * /df go: the Edit Mode layout "DeckForever", a copy of the one in use with the systems
--     below moved, saved through C_EditMode and made active. The other layouts are left as
--     they are; the layouts as they were first found are kept in DeckForeverDB.backup.
--   * /df back: the layout it was copied from active again. /df fx: a look at the combat fades.
-- Positions are in UIParent units, which on the Deck (scale 0.96) are its screen pixels.
--------------------------------------------------------------------------------

-- (the gamepad help: Legend.lua)

-- the layout DeckForever's is copied from: one named so if there is one, else the one in use (unless it's
-- ours), else the game's Gamepad layout; /df back goes back to it
local SOURCE_LAYOUT = "SteamDeck"
local TARGET_LAYOUT = "DeckForever"
local OLD_LAYOUTS = { ["SteamDeck B"] = true }  -- earlier names of ours, removed as it's saved

-- Each system of the layout that DeckForever sets: where (an anchor on UIParent) and, by their names in
-- Enum.EditMode<System>Setting, its settings. The bars at the bottom, compact; player and target either
-- side of the main bar, focus above the target; the cooldowns in the free corners beside the main bar
-- (nothing over it: the character stands there); chat top-left; the buff bars under it; the swing timer
-- just above the bars
local M = 8                                     -- the gap to the screen's edges and between neighbours
local B = M + 4                 -- from the bottom edge: over the XP bar (XPBar, 4 px)
local LAYOUT = {
	-- bottom up: the XP bar on the edge; Easy Controller's L3 / R3 (they hang 54 under the main bar)
	-- just above it; the main bar (compact) with L5 / R5 either side
	{ system = "GamepadMainActionBar", point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 77,
		settings = { Compact = 1 } },
	-- above the bars, either side of the character: player and target, the cast bar under the player,
	-- the focus above the target; the swing timer between them and the bars, in combat only
	{ system = "UnitFrame", index = 1, point = "BOTTOMRIGHT", relativePoint = "BOTTOM", x = -108, y = 248 },
	{ system = "UnitFrame", index = 2, point = "BOTTOMLEFT", relativePoint = "BOTTOM", x = 108, y = 248 },
	{ system = "UnitFrame", index = 3, point = "BOTTOMLEFT", relativePoint = "BOTTOM", x = 108, y = 356 },
	{ system = "CastBar", point = "TOP", relativePoint = "BOTTOM", x = -224, y = 248,
		settings = { LockToPlayerFrame = 1 } },
	-- (under the player frame, its width: 19 = 232 px, 213 + the setting)
	{ system = "SwingTimer", index = 1, point = "TOPLEFT", relativePoint = "BOTTOM", x = -340, y = 244,
		settings = { Visibility = 1, Width = 19 } },
	-- the off-hand and ranged timers hidden (they sat over the main bar)
	{ system = "SwingTimer", index = 2, point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 205,
		settings = { Visibility = 2 } },
	{ system = "SwingTimer", index = 3, point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 205,
		settings = { Visibility = 2 } },
	-- the cooldowns between the player and target frames (216 px between them): the essential ones
	-- level with their bottom (4 a row), the utility ones right under them; the tracked buff icons
	-- above the player frame
	{ system = "CooldownViewer", index = 1, point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 248,
		settings = { IconLimit = 4 } },
	{ system = "CooldownViewer", index = 2, point = "TOP", relativePoint = "BOTTOM", x = 0, y = 244,
		settings = { IconLimit = 6 } },
	{ system = "CooldownViewer", index = 3, point = "BOTTOMLEFT", relativePoint = "BOTTOM", x = -340, y = 352 },
	-- (test) bottom-left: the chat, from the left edge to the XP bar M away, as tall as the minimap and
	-- its header (its tabs hidden: HideChatTabs; its clamp taken off: UnclampChat). Top-left: the
	-- gamepad help (Legend.lua), the buff bars under its tallest group
	-- (the line you type in is put over the chat, PlaceChat: 7 left and 19 right of it, its tooltip look
	-- drawn about 3 inside, set from zoomed captures so its box runs from 8 to the XP bar - 8, its top on
	-- the minimap header's visible top. The chat is 10..320 across, 595..792 down: its bottom M from
	-- the screen's)
	{ system = "ChatFrame", point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 10, y = B,
		settings = { WidthHundreds = 3, WidthTensAndOnes = 10, HeightHundreds = 1, HeightTensAndOnes = 97 } },
	{ system = "CooldownViewer", index = 4, point = "TOPLEFT", relativePoint = "TOPLEFT", x = M, y = -(M + 150 + M) },
	-- (test: the minimap and the game's tooltip swapped) bottom-right: the minimap M from the corner
	-- (273 wide, 284 tall with its zone header). Top-right: the tooltip's corner (it grows down over
	-- the quests while it shows); the quests M from the top, at the tracker's least height (400: taller,
	-- it runs off the screen and the game pulls it back up); the buffs and debuffs M left of them.
	-- (the tracker sits 1 px right of its anchor, the debuffs 1 px right of the buffs: set against that,
	-- so each edge lands on M)
	{ system = "Minimap", point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -M, y = B },
	-- (the tooltip itself is put M from the corner by PlaceTooltip: Edit Mode keeps its corner lower)
	{ system = "HudTooltip", point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -M, y = -M },
	-- (the tracker's contents narrowed to the minimap's width, NarrowQuests: moved right by what's taken off)
	{ system = "ObjectiveTracker", point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -(M + 1) + (261 - 202), y = -M,
		settings = { Height = 0 } },
	{ system = "AuraFrame", index = 1, point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -(M + 261 + M), y = -(M + 1) },   -- (its icons sit 1 above it)
	-- (the buffs take up to three rows when there are many: the debuffs under them)
	{ system = "AuraFrame", index = 2, point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -(M + 261 + M + 1), y = -150 },
	-- the game's menu and bags (hidden by the gamepad UI) out of the way, bottom-right
	{ system = "MicroMenu", point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -M, y = B },
}

-- Easy Controller's supplies (bag space, reagents): set through its own saved position, out of the
-- HUD in the bottom-right corner, left of the minimap, growing left. Its old position is kept in DeckForeverDB.easyController
local EC_SUPPLIES = { pos = { point = "BOTTOMRIGHT", x = -(M + 273 + M), y = B }, layout = "left" }

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffDeckForever|r " .. msg)
end


-- The chat's clamp keeps room round it for buttons the gamepad UI doesn't show (60 from the top, 32
-- from the left): taken off, and the chat put where the layout says again, while our layout is the
-- one in use (a plain frame: not protected)
local function UnclampChat()
	local chat = _G.ChatFrame1
	if chat and not chat:IsForbidden() and chat.SetClampRectInsets then chat:SetClampRectInsets(0, 0, 0, 0) end
end

-- The class action (a paladin's aura, LB + LT): Blizzard puts it 138 left of the bottom bar's centre,
-- under its left end, with its prompt under it. With the compact bar that's off to the side: put
-- under the middle of the bar, between L3 and R3. Only out of combat (the button is protected), only
-- when it's alone (with the right-hand one too, both stay where Blizzard puts them)
-- From the bottom bar's centre: the button clear of the bar (its face buttons end 43 under that centre),
-- its prompt under it at 75 % (the 58 px between the bar and the XP bar hold both then)
local CLASS_ACTION_Y, CLASS_PROMPT_Y, CLASS_PROMPT_SCALE = -64, -92, 0.75
local BLIZZARD_ACTION_Y, BLIZZARD_PROMPT_Y = -50, -80
local function PlaceClassAction()
	local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
	if not unit or InCombatLockdown() then return end
	local anchor = unit.BottomCenteredAnchor
	local left, right = unit.LeftClassAction, unit.RightClassAction
	if not (anchor and left and right) or left:IsForbidden() or right:IsForbidden() then return end
	local alone = left:IsShown() ~= right:IsShown()
	local function Put(button, prompt, x)
		local y, py, scale = CLASS_ACTION_Y, CLASS_PROMPT_Y, CLASS_PROMPT_SCALE
		if not alone then y, py, scale = BLIZZARD_ACTION_Y, BLIZZARD_PROMPT_Y, 1 end
		button:ClearAllPoints()
		button:SetPoint("CENTER", anchor, "CENTER", x, y)
		if prompt and not prompt:IsForbidden() then
			prompt:SetScale(scale)
			prompt:ClearAllPoints()
			prompt:SetPoint("CENTER", anchor, "CENTER", x / scale, py / scale)
		end
	end
	Put(left, unit.LeftInputPrompt, alone and 0 or -138)
	Put(right, unit.RightInputPrompt, alone and 0 or 138)
end
local classHooked
local function HookClassAction()
	local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
	if classHooked or not (unit and unit.LeftClassAction and unit.RightClassAction) then return end
	classHooked = true
	for _, button in ipairs({ unit.LeftClassAction, unit.RightClassAction }) do
		button:HookScript("OnShow", PlaceClassAction)
		button:HookScript("OnHide", PlaceClassAction)
	end
end

-- The chat's tabs (General, Combat Log ...): not used with the gamepad, made invisible and left alone
-- otherwise (the chat fades them in and out itself: their alpha is set back to 0 by the fader, below;
-- a hook on their Show broke the chat's own fades). Plain frames: not protected
local CHAT_TABS = { "GeneralDockManager" }
for i = 1, (NUM_CHAT_WINDOWS or 10) do CHAT_TABS[#CHAT_TABS + 1] = "ChatFrame" .. i .. "Tab" end
local function HideChatTabs()
	for _, name in ipairs(CHAT_TABS) do
		local tab = _G[name]
		if tab and not tab:IsForbidden() then tab:EnableMouse(false) end
	end
end

-- The minimap made square: its round mask swapped for a square one, the round frame round it hidden, a
-- border with the game's tooltip look instead (as the gamepad help). Addons that put buttons on the
-- minimap's edge ask its shape: square. Display only (the minimap isn't protected)
local PlaceMinimap
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
local mapBorder
local function SquareMinimap()
	local map = _G.Minimap
	if not map or map:IsForbidden() then return end
	map:SetMaskTexture(SQUARE_MASK)
	if _G.MinimapCompassTexture then MinimapCompassTexture:SetAlpha(0) end
	if _G.MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:SetAlpha(0) end
	if not mapBorder then
		-- (the tooltip border is drawn 2 inside its frame, 3 thick: 1 over the map's edge)
		mapBorder = CreateFrame("Frame", nil, map, "TooltipBackdropTemplate")
		mapBorder:SetPoint("TOPLEFT", map, "TOPLEFT", -4, 4)
		mapBorder:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", 4, -4)
		mapBorder:SetFrameLevel(map:GetFrameLevel() + 1)
		if mapBorder.NineSlice and mapBorder.NineSlice.Center then mapBorder.NineSlice.Center:SetAlpha(0) end
		-- (Blizzard sets its round mask again when the rotate option changes)
		hooksecurefunc(map, "SetMaskTexture", function(self, mask)
			if mask ~= SQUARE_MASK then self:SetMaskTexture(SQUARE_MASK) end
		end)
		for _, method in ipairs({ "SetHeaderUnderneath", "SetEditModeScale" }) do
			if MinimapCluster and MinimapCluster[method] then
				hooksecurefunc(MinimapCluster, method, function() PlaceMinimap() end)
			end
		end
	end
end
function GetMinimapShape() return "SQUARE" end

-- The square in the bottom-right corner, its border M from the edges (drawn 2 outside the map): the
-- map's container moved there; the header over it, 4 above the border and as wide as it (every piece of
-- it hangs off the zone's button: the tracking 16 left of it, the clock in it, the calendar 18 past its
-- right edge; the zone's name stretched to the clock); the addons' list under the calendar hidden (it
-- would sit on the map; not used with the gamepad); the player's coordinates on the map's bottom edge
-- (under it, they'd be off the screen); the day / night icon in the map's bottom-right corner. Blizzard
-- puts these back as the layout loads (MinimapClusterMixin:SetHeaderUnderneath, SetEditModeScale):
-- placed again after it
function PlaceMinimap()
	local cluster = _G.MinimapCluster
	local map = _G.Minimap
	local container = cluster and cluster.MinimapContainer
	if not (container and map) or map:IsForbidden() then return end
	local scale = container:GetScale()
	local half = map:GetWidth() / 2
	container:ClearAllPoints()
	container:SetPoint("CENTER", UIParent, "BOTTOMRIGHT", (-(M + 2) - half * scale) / scale, (B + 2 + half * scale) / scale)
	local zone = cluster.ZoneTextButton
	if zone then
		zone:ClearAllPoints()
		zone:SetPoint("BOTTOMLEFT", map, "TOPLEFT", -2 + 16, 6)
		zone:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", 2 - 18 + 1, 6)   -- (+1: the calendar is drawn 1 inside its frame)
		local name = _G.MinimapZoneText
		local clock = _G.TimeManagerClockButton
		if name then
			name:SetWidth(map:GetWidth() + 4 - 16 - 18 - 8 - (clock and clock:GetWidth() + 6 or 0))
		end
	end
	local diel = cluster.DielFrame
	if diel then
		diel:ClearAllPoints()
		diel:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -3, 3)
	end
	local addons = _G.AddonCompartmentFrame
	if addons and not addons:IsForbidden() then addons:EnableMouse(false) end      -- (invisible: the fader)
	if container.PlayerCoords then
		container.PlayerCoords:ClearAllPoints()
		container.PlayerCoords:SetPoint("BOTTOM", map, "BOTTOM", 0, 4)
	end
end

-- The game's tooltip at its default place: its border M from the top-right corner (drawn 2 inside it).
-- Edit Mode keeps the default place's frame on the screen with room round it, so the tooltip is put
-- there after the game anchors it (a plain frame: not protected). The game keeps 25 above the tooltip
-- on the screen (room for a comparison's "Equipped" header): none while it's at its default place, the
-- 25 back as it hides. While it's there, over the top of the quests, the quests fade (Fader)
-- the tooltip shows at its default place, over the quests (read, not hooked: a hook on its SetOwner,
-- which GameTooltip_SetDefaultAnchor calls, errored)
local function TipOverQuests()
	local tip = GameTooltip
	if not tip or tip:IsForbidden() or not tip:IsShown() or tip:GetNumPoints() ~= 1 then return false end
	local point, relative, _, x, y = tip:GetPoint(1)
	return point == "TOPRIGHT" and relative == UIParent and math.abs(x + (M - 2)) < 0.5 and math.abs(y + (M - 2)) < 0.5
end
local oursActive                 -- our layout is the one in use (seen as the world loads)
local function PlaceTooltip(tooltip)
	if not oursActive or tooltip ~= GameTooltip or tooltip:IsForbidden() then return end
	tooltip:ClearAllPoints()
	tooltip:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -(M - 2), -(M - 2))
	tooltip:SetClampRectInsets(0, 0, 0, 0)
end
local tooltipHooked
local function HookTooltip()
	if tooltipHooked or not GameTooltip_SetDefaultAnchor then return end
	tooltipHooked = true
	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip) pcall(PlaceTooltip, tooltip) end)
	GameTooltip:HookScript("OnHide", function(self)
		self:SetClampRectInsets(0, 0, 25, 0)
	end)
end

-- The XP bar, thin, along the whole bottom edge: ours (Blizzard's has a fixed width, its art is made for
-- its height, and its Edit Mode width and height settings do nothing in this client), the XP and the
-- rested XP as Blizzard's shows them. Blizzard's is faded out while ours shows (combat mode: FADED); at
-- the top level, or with XP turned off, ours hides and Blizzard's (reputation...) is back
local XP_HEIGHT = 4                   -- screen pixels
local xpBar
local function UpdateXP()
	if not xpBar then return end
	local max = UnitXPMax("player")
	local done = UnitLevel("player") >= GetMaxPlayerLevel() or (IsXPUserDisabled and IsXPUserDisabled())
	if done or not max or max <= 0 then xpBar:Hide() return end
	local xp = UnitXP("player")
	xpBar.fill:SetMinMaxValues(0, max)
	xpBar.fill:SetValue(xp)
	-- (Blizzard's art: blue while rested, purple else)
	local atlas = GetRestState() == 1 and "UI-HUD-ExperienceBar-Fill-Rested" or "UI-HUD-ExperienceBar-Fill-Experience"
	if xpBar.atlas ~= atlas then xpBar.atlas = atlas xpBar.fill:SetStatusBarTexture(atlas) end
	xpBar.rested:SetMinMaxValues(0, max)
	xpBar.rested:SetValue(math.min(max, xp + (GetXPExhaustion() or 0)))
	xpBar:Show()
end
local function XPBar()
	if xpBar then UpdateXP() return end
	local pixel = 768 / 800 / UIParent:GetScale()   -- (a screen pixel, in UIParent's units)
	-- one frame (faded as one: FADED) with a grey background, so the bar's empty part shows against the
	-- screen's edge; in it the rested XP (Blizzard's band past the XP), and the XP over it
	xpBar = CreateFrame("Frame", "DeckForeverXPBar", UIParent)
	xpBar:SetFrameStrata("LOW")
	xpBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
	xpBar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
	xpBar:SetHeight(XP_HEIGHT * pixel)
	local back = xpBar:CreateTexture(nil, "BACKGROUND")
	back:SetAllPoints()
	back:SetColorTexture(0.6, 0.6, 0.6, 1)
	for i, key in ipairs({ "rested", "fill" }) do
		local bar = CreateFrame("StatusBar", nil, xpBar)
		bar:SetAllPoints()
		bar:SetFrameLevel(xpBar:GetFrameLevel() + i)
		xpBar[key] = bar
	end
	xpBar.rested:SetStatusBarTexture("UI-HUD-ExperienceBar-Fill-Prediction")
	local events = CreateFrame("Frame", nil, UIParent)
	for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN" }) do
		pcall(events.RegisterEvent, events, e)
	end
	events:SetScript("OnEvent", function() C_Timer.After(0, UpdateXP) end)
	UpdateXP()
end

--------------------------------------------------------------------------------
-- Combat mode: what isn't needed in a fight fades while in combat (the minimap, the quests, the XP
-- bar, the gamepad help at rest: holding LB or RB brings it back, its targeting actions are of use
-- then), and what's only needed for a fight fades out of it with no target (CalmDriver). Alpha only,
-- eased over FADE_TIME; nothing is hidden or moved, so a faded frame works as ever
--------------------------------------------------------------------------------
local FADE_TIME = 0.25
local IN_COMBAT_ALPHA = 0.3           -- the non-essentials, in combat
local CALM_ALPHA = 0.35               -- the fight's frames, out of combat
local QUESTS_UNDER_TIP = 0.25         -- the quests, under the tooltip at its default place
local CHAT_ALPHA = 0.65               -- the chat's messages
local XP_ALPHA = 0.5                  -- the XP bar (Blizzard's colours, bright beside the rest)

local forceFight                -- /df combat: shown as in combat, to see the fades (display only)
local function Fighting() return forceFight or InCombatLockdown() or UnitAffectingCombat("player") end

-- frame (by its name) -> the alpha it should have now
local FADED = {
	MinimapCluster = function() return Fighting() and IN_COMBAT_ALPHA or 1 end,
	StatusTrackingBarManager = function()
		if xpBar and xpBar:IsShown() then return 0 end
		return Fighting() and IN_COMBAT_ALPHA or 1
	end,
	DeckForeverXPBar = function() return Fighting() and IN_COMBAT_ALPHA or XP_ALPHA end,
	ObjectiveTrackerFrame = function()
		return math.min(Fighting() and IN_COMBAT_ALPHA or 1, TipOverQuests() and QUESTS_UNDER_TIP or 1)
	end,
	DeckForeverLegend = function(legend)
		local resting = legend.group == nil or legend.group == "GAMEPLAY"
		return (Fighting() and resting) and IN_COMBAT_ALPHA or 1
	end,
	-- the cooldown rows between the unit frames, with the player frame and the bars (as CalmDriver's
	-- rule: in combat or with a target; these aren't protected, so faded from here, eased)
	-- the chat's tabs and the minimap's addons list: never (HideChatTabs, PlaceMinimap)
	AddonCompartmentFrame = function() return 0 end,
	-- the chat's messages, as quiet as the quests; fully while you type (the line you type in is its child)
	ChatFrame1 = function(frame)
		local box = _G.ChatFrame1EditBox
		return box and box:HasFocus() and 1 or CHAT_ALPHA
	end,
	-- the line you type in: only while you type (the gamepad UI keeps it shown, at 35 %, all the time)
	ChatFrame1EditBox = function(box) return box:HasFocus() and 1 or 0 end,
	EssentialCooldownViewer = function() return (Fighting() or UnitExists("target")) and 1 or CALM_ALPHA end,
	UtilityCooldownViewer = function() return (Fighting() or UnitExists("target")) and 1 or CALM_ALPHA end,
}
-- (the player frame and the gamepad bars aren't faded from here: setting their alpha from an addon's
-- code made the gamepad UI block SetPreferredGamepadInteractTarget, over and over. CalmDriver does it)

-- The player frame and the gamepad bars (Easy Controller's paddles follow the bar's alpha), faded out of
-- combat with no target: by a secure state driver, the game's own way to change protected frames (the
-- alpha is set in its restricted environment, from a macro condition, never from DeckForever's code).
-- Set up once, out of combat; at once, no fade (the driver only switches states)
local CALM_FRAMES = { "PlayerFrame", "GamepadMainActionBarFrame" }
local calmDriver
local function CalmDriver()
	if calmDriver or InCombatLockdown() or not RegisterStateDriver then return end
	calmDriver = CreateFrame("Frame", "DeckForeverCalmDriver", UIParent, "SecureHandlerStateTemplate")
	local n = 0
	for _, name in ipairs(CALM_FRAMES) do
		local frame = _G[name]
		if frame and not frame:IsForbidden() then
			n = n + 1
			calmDriver:SetFrameRef("calm" .. n, frame)
		end
	end
	calmDriver:SetAttribute("calmCount", n)
	calmDriver:SetAttribute("calmAlpha", CALM_ALPHA)
	calmDriver:SetAttribute("_onstate-calm", [[
		local alpha = newstate == "on" and self:GetAttribute("calmAlpha") or 1
		for i = 1, self:GetAttribute("calmCount") do
			local frame = self:GetFrameRef("calm" .. i)
			if frame then frame:SetAlpha(alpha) end
		end
	]])
	RegisterStateDriver(calmDriver, "calm", "[combat][@target,exists] off; on")
end
for _, name in ipairs(CHAT_TABS) do FADED[name] = function() return 0 end end
local current = {}
local fader = CreateFrame("Frame")
fader:SetScript("OnUpdate", function(_, elapsed)
	if not oursActive then return end
	local step = elapsed / FADE_TIME
	for name, want in pairs(FADED) do
		local frame = _G[name]
		if frame and not frame:IsForbidden() then
			local target = want(frame)
			local now = current[frame] or frame:GetAlpha()
			if now ~= target then
				now = now < target and math.min(target, now + step) or math.max(target, now - step)
				current[frame] = now
				frame:SetAlpha(now)
			elseif frame:GetAlpha() ~= target then
				frame:SetAlpha(target)               -- (something else set it meanwhile)
			end
		end
	end
end)

-- The cooldown rows between the unit frames, centred on the icons they show: a row keeps room for
-- every cooldown it tracks, icons laid from its left, and hides the ones not in use (Hide When
-- Inactive), so its icons sit left of its middle. Each row is moved by the difference, a few times a
-- second (rows aren't protected)
local CENTRED = { { viewer = "EssentialCooldownViewer", index = 1 }, { viewer = "UtilityCooldownViewer", index = 2 } }
local centreWait = 0
local function CentreCooldowns()
	if not oursActive then return end
	for _, row in ipairs(CENTRED) do
		local viewer = _G[row.viewer]
		local entry
		for _, e in ipairs(LAYOUT) do
			if e.system == "CooldownViewer" and e.index == row.index then entry = e end
		end
		if viewer and entry and viewer:IsVisible() and not viewer:IsForbidden() then
			local left, right
			for _, item in ipairs({ viewer:GetChildren() }) do
				if item:IsShown() and item.layoutIndex then
					local l, r = item:GetLeft(), item:GetRight()
					if l then left, right = math.min(left or l, l), math.max(right or r, r) end
				end
			end
			if left then
				local shift = UIParent:GetWidth() / 2 - (left + right) / 2
				if math.abs(shift) > 0.5 then
					-- (from where it is now: Edit Mode may have put it back on its anchor meanwhile)
					local _, _, _, x = viewer:GetPoint(1)
					viewer:ClearAllPoints()
					viewer:SetPoint(entry.point, UIParent, entry.relativePoint, (x or entry.x) + shift, entry.y)
				end
			end
		end
	end
end
local centreFrame = CreateFrame("Frame")
centreFrame:SetScript("OnUpdate", function(_, elapsed)
	centreWait = centreWait - elapsed
	if centreWait > 0 then return end
	centreWait = 0.2
	CentreCooldowns()
end)

-- The line you type in, with the game's tooltip look (as the gamepad help and the minimap): its own
-- art made invisible (alpha only: Blizzard shows and hides its pieces as it gets and loses the focus),
-- a tooltip backdrop behind it (a plain frame: not protected)
local EDIT_ART = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
local editSkinned
local function SkinEditBox()
	local box = _G.ChatFrame1EditBox
	if editSkinned or not box or box:IsForbidden() then return end
	editSkinned = true
	for _, piece in ipairs(EDIT_ART) do
		local tex = _G["ChatFrame1EditBox" .. piece]
		if tex then tex:SetAlpha(0) end
	end
	local back = CreateFrame("Frame", nil, box, "TooltipBackdropTemplate")
	back:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
	back:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
	back:SetFrameLevel(math.max(0, box:GetFrameLevel() - 1))
end

-- The HUD's text a size up, nearer the chat's: the quests' and the unit bars' font objects (theirs
-- only), the names on the unit frames and the minimap's header (their font strings). The unit bars' a
-- point less: their bars are barely taller. Fonts aren't protected
local FONT_OBJECTS = { ObjectiveTrackerLineFont = 2, ObjectiveTrackerHeaderFont = 2, TextStatusBarText = 1 }
local FONT_STRINGS = { PlayerName = 2, MinimapZoneText = 2, TimeManagerClockTicker = 2 }
local enlarged = {}
local function Enlarge(object, bigger)
	if not object or enlarged[object] or (object.IsForbidden and object:IsForbidden()) then return end
	local font, size, flags = object:GetFont()
	if not font then return end
	enlarged[object] = true
	object:SetFont(font, size + bigger, flags or "")
end
local function BiggerText()
	for name, bigger in pairs(FONT_OBJECTS) do Enlarge(_G[name], bigger) end
	for name, bigger in pairs(FONT_STRINGS) do Enlarge(_G[name], bigger) end
	local target = _G.TargetFrame
	local main = target and target.TargetFrameContent and target.TargetFrameContent.TargetFrameContentMain
	Enlarge(main and main.Name, 2)
end

-- The unit frames' health and power shown as numbers (the game's own option, Status Text): set once,
-- with the layout, if it's off; turned back on the Options page as any other setting
local function StatusText()
	if DeckForeverDB.statusTextSet or InCombatLockdown() then return end
	DeckForeverDB.statusTextSet = true
	if GetCVar("statusTextDisplay") == "NONE" then
		SetCVar("statusTextDisplay", "NUMERIC")
		SetCVar("statusText", "1")
	end
end

-- The quests as wide as the minimap (its border: the map + 4). Blizzard's tracker is 260 wide: its
-- container stays so (resizing it would have the tracker lay itself out from DeckForever's code), and
-- what's drawn in it is narrowed: each module, its header, the header's art and text (the quest blocks,
-- held by both edges of their module, follow), every module the tracker gets (AddModule) too. The
-- container is moved right by the difference, so the narrowed contents end M from the screen's edge;
-- the tracker isn't kept on the screen any more for that (its empty right part is off it)
local TRACKER_WIDTH = 260
local function QuestsWidth()
	local map = _G.Minimap
	return map and math.floor(map:GetWidth() + 4 + 0.5) or TRACKER_WIDTH
end
-- (the headers' art has clear ends, 9 % of its width: stretched past the header by that, so its line
-- runs from the minimap's left edge to its right one)
local HEADER_ART_SPAN = 202 / 184
local function NarrowHeader(header, width, textMargin)
	if not header or header:IsForbidden() then return end
	header:SetWidth(width)
	if header.Background then
		header.Background:SetWidth(width * HEADER_ART_SPAN)
		header.Background:ClearAllPoints()
		header.Background:SetPoint("CENTER", header, "CENTER", 2, 0)
	end
	if header.Text then header.Text:SetWidth(width - textMargin) end
end
local function NarrowQuests()
	local tracker = _G.ObjectiveTrackerFrame
	if not oursActive or not tracker or tracker:IsForbidden() then return end
	local width = QuestsWidth()
	tracker:SetClampedToScreen(false)
	NarrowHeader(tracker.Header, width, 52)
	for _, module in ipairs(tracker.modules or {}) do
		if not module:IsForbidden() then
			module:SetWidth(width)
			NarrowHeader(module.Header, width, 60)
		end
	end
end
local questsHooked
local function HookQuests()
	local tracker = _G.ObjectiveTrackerFrame
	if questsHooked or not tracker or not tracker.AddModule then return end
	questsHooked = true
	hooksecurefunc(tracker, "AddModule", function() NarrowQuests() end)
end

local function FindLayout(layouts, name)
	for i, layout in ipairs(layouts) do
		if layout.layoutType ~= Enum.EditModeLayoutType.Preset and layout.layoutName == name then return i, layout end
	end
end

-- The layouts as Edit Mode keeps them: the game's presets first, then the saved ones; the active
-- layout is an index in that list. Saved back with the game's own functions, never Edit Mode's
-- frame or methods (their taint would spread to the bars); the layout is applied as the game loads it
local function Layouts()
	local saved = C_EditMode.GetLayouts()
	local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
	local layouts = {}
	for _, layout in ipairs(presets) do layouts[#layouts + 1] = layout end
	for _, layout in ipairs(saved.layouts or {}) do layouts[#layouts + 1] = layout end
	local gamepadPreset
	for _, layout in ipairs(presets) do
		if layout.interfaceStyle == Enum.InputDeviceInterfaceType.Gamepad then gamepadPreset = layout end
	end
	return layouts, saved.activeLayout, gamepadPreset, saved
end

local function SetSetting(sys, id, value)
	for _, st in ipairs(sys.settings) do
		if st.setting == id then st.value = value return end
	end
	sys.settings[#sys.settings + 1] = { setting = id, value = value }
end

-- the system in the layout; the gamepad bar is put back from the Gamepad preset when missing (a game
-- bug drops it from saved layouts at the next launch)
local function FindSystem(layout, systemID, index, gamepadPreset)
	for _, sys in ipairs(layout.systems) do
		if sys.system == systemID and (index == nil or sys.systemIndex == index) then return sys end
	end
	for _, sys in ipairs(gamepadPreset and gamepadPreset.systems or {}) do
		if sys.system == systemID and (index == nil or sys.systemIndex == index) then
			local copy = CopyTable(sys)
			layout.systems[#layout.systems + 1] = copy
			return copy
		end
	end
end

local function Activate(index, name)
	if C_EditMode.SetActiveLayout then
		C_EditMode.SetActiveLayout(index)
		Print(("« %s » active. Tape /reload."):format(name))
	else
		Print(("choisis « %s » dans le Mode Édition, puis /reload."):format(name))
	end
end

local function EditModeReady()
	if InCombatLockdown() then Print("pas en combat.") return end
	if not (C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and EditModePresetLayoutManager) then
		Print("Mode Édition introuvable.")
		return
	end
	return true
end

local function Apply()
	if not EditModeReady() then return end
	local layouts, active, gamepadPreset, saved = Layouts()
	local _, source = FindLayout(layouts, SOURCE_LAYOUT)
	if not source then
		local current = layouts[active]
		if current and current.layoutName ~= TARGET_LAYOUT then source = current else source = gamepadPreset end
	end
	if not source then Print("aucune disposition de départ trouvée.") return end
	DeckForeverDB.backup = DeckForeverDB.backup or CopyTable(saved)
	DeckForeverDB.previous = source.layoutName

	local layout = CopyTable(source)
	if layout.layoutType == Enum.EditModeLayoutType.Preset then layout.layoutType = Enum.EditModeLayoutType.Account end
	layout.layoutName = TARGET_LAYOUT
	local moved, missing = 0, {}
	for _, entry in ipairs(LAYOUT) do
		local systemID = Enum.EditModeSystem[entry.system]
		local sys = systemID and FindSystem(layout, systemID, entry.index, gamepadPreset)
		if sys then
			sys.anchorInfo = { point = entry.point, relativeTo = "UIParent", relativePoint = entry.relativePoint,
				offsetX = entry.x, offsetY = entry.y }
			sys.isInDefaultPosition = false
			local enum = Enum["EditMode" .. entry.system .. "Setting"]
			for name, value in pairs(entry.settings or {}) do
				if enum and enum[name] then SetSetting(sys, enum[name], value) else missing[#missing + 1] = entry.system .. "." .. name end
			end
			moved = moved + 1
		else
			missing[#missing + 1] = entry.system
		end
	end

	for i = #layouts, 1, -1 do
		if layouts[i].layoutType ~= Enum.EditModeLayoutType.Preset and OLD_LAYOUTS[layouts[i].layoutName] then
			if i < active then active = active - 1 end
			table.remove(layouts, i)
		end
	end
	local index, isNew = FindLayout(layouts, TARGET_LAYOUT), false
	if index then
		layouts[index] = layout
	else
		layouts[#layouts + 1] = layout
		index, isNew = #layouts, true
	end
	C_EditMode.SaveLayouts({ layouts = layouts, activeLayout = active })

	local ec = _G.ControllerKeyboard
	local supplies = ec and ec.db and ec.db.settings and ec.db.settings.supplies
	if type(supplies) == "table" then
		DeckForeverDB.easyController = DeckForeverDB.easyController
			or { pos = supplies.pos and CopyTable(supplies.pos), layout = supplies.layout }
		supplies.pos = CopyTable(EC_SUPPLIES.pos)
		supplies.layout = EC_SUPPLIES.layout
	end
	Print(("« %s » enregistrée (%d éléments)."):format(TARGET_LAYOUT, moved))
	if #missing > 0 then Print("introuvable sur ce client : " .. table.concat(missing, ", ")) end
	if isNew and C_EditMode.OnLayoutAdded then
		C_EditMode.OnLayoutAdded(index, true, false)
		Print("Tape /reload.")
	else
		Activate(index, TARGET_LAYOUT)
	end
end

-- whether the active layout is ours and still holds every system as set (a game bug drops the gamepad
-- bar from saved layouts at the next launch): false then, and it's saved again
local function Holds()
	local layouts, active = Layouts()
	local layout = layouts[active]
	if not layout or layout.layoutType == Enum.EditModeLayoutType.Preset or layout.layoutName ~= TARGET_LAYOUT then return true end
	for _, entry in ipairs(LAYOUT) do
		local systemID = Enum.EditModeSystem[entry.system]
		local found
		for _, sys in ipairs(layout.systems) do
			if sys.system == systemID and (entry.index == nil or sys.systemIndex == entry.index) then found = sys end
		end
		local a = found and found.anchorInfo
		if systemID and not (a and a.point == entry.point and a.relativePoint == entry.relativePoint
			and math.abs((a.offsetX or 0) - entry.x) < 0.5 and math.abs((a.offsetY or 0) - entry.y) < 0.5) then
			return false
		end
	end
	return true
end

local function PlaceChat()
	local chat = _G.ChatFrame1
	if not chat or chat:IsForbidden() or InCombatLockdown() then return end
	local layouts, active = Layouts()
	local layout = layouts[active]
	if not layout or layout.layoutName ~= TARGET_LAYOUT or layout.layoutType == Enum.EditModeLayoutType.Preset then return end
	for _, entry in ipairs(LAYOUT) do
		if entry.system == "ChatFrame" then
			UnclampChat()
			chat:ClearAllPoints()
			chat:SetPoint(entry.point, UIParent, entry.relativePoint, entry.x, entry.y)
			-- the line you type in over the chat, not under it (its box from 8 to the XP bar - 8, its top on the
			-- minimap header's)
			local box = _G.ChatFrame1EditBox
			if box and not box:IsForbidden() then
				box:ClearAllPoints()
				box:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", -7, 3)
				box:SetPoint("BOTTOMRIGHT", chat, "TOPRIGHT", 19, 3)
			end
		end
	end
end

local function Back()
	if not EditModeReady() then return end
	local layouts, _, gamepadPreset = Layouts()
	local name = DeckForeverDB.previous or SOURCE_LAYOUT
	local index = FindLayout(layouts, name)
	if not index and gamepadPreset then
		for i, layout in ipairs(layouts) do
			if layout == gamepadPreset then index, name = i, layout.layoutName end
		end
	end
	if not index then Print(("disposition « %s » introuvable."):format(name)) return end
	Activate(index, name)
end

SLASH_DECKFOREVER1, SLASH_DECKFOREVER2 = "/df", "/deckforever"
SlashCmdList.DECKFOREVER = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "go" or msg == "apply" then
		Apply()
	elseif msg == "combat" or msg == "fx" then
		forceFight = not forceFight
		Print(forceFight and "aperçu combat : on (affichage seulement)." or "aperçu combat : off.")
	elseif msg == "back" then
		Back()
	else
		Print("/df go : disposition « " .. TARGET_LAYOUT .. " » · /df back : retour à « " .. (DeckForeverDB.previous or SOURCE_LAYOUT) .. " » · /df fx : aperçu combat.")
	end
end

-- Edit Mode lays the chat out again (with its clamp) as it closes: put back after it
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		C_Timer.After(0, function() pcall(PlaceChat) PlaceMinimap() NarrowQuests() end)
	end, "DeckForever")
end

local checked                   -- the layout checked once, at the first login of the session
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")      -- (a class action shown or hidden in combat: placed after)
f:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name == "DeckForever" then
			DeckForeverDB = DeckForeverDB or {}
			UnclampChat()                    -- (before Edit Mode places the chat, as the layout loads)
		end
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then PlaceClassAction() return end
	HookClassAction()
	PlaceClassAction()
	HideChatTabs()
	if C_EditMode and EditModePresetLayoutManager then
		local ok, layouts, active = pcall(Layouts)
		local layout = ok and layouts[active]
		oursActive = layout and layout.layoutName == TARGET_LAYOUT
			and layout.layoutType ~= Enum.EditModeLayoutType.Preset or false
	end
	HookTooltip()
	-- (Edit Mode may lay the chat out again, its clamp with it, after this: placed once more a moment later)
	if oursActive then C_Timer.After(1, function() pcall(PlaceChat) end) end
	if oursActive then
		CalmDriver()
		SkinEditBox()
		BiggerText()
		XPBar()
		StatusText()
		HookQuests()
		NarrowQuests()
	end
	SquareMinimap()
	PlaceMinimap()
	if C_EditMode and EditModePresetLayoutManager then pcall(PlaceChat) end
	if not checked then
		checked = true
		local ok, holds = pcall(Holds)
		if ok and not holds and not InCombatLockdown() then
			Print("la disposition avait perdu des éléments (bug du jeu) : réparée.")
			Apply()
		end
	end
end)
