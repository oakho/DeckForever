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
local _, ns = ...
local M = 8                                     -- the gap to the screen's edges and between neighbours
local B = M + 4                 -- from the bottom edge: over the XP bar (XPBar, 4 px)
local HEADER = 260              -- Improved Forever's target header: its line, that far either side of the
                                -- top's centre (ImprovedForever_Immersion HeaderSlot.lua, RULE_W)
local function EnumValue(enum, key, fallback) return enum and enum[key] or fallback end
local AURA_HORIZONTAL = EnumValue(Enum.AuraFrameOrientation, "Horizontal", 0)
local AURA_RIGHT = EnumValue(Enum.AuraFrameIconDirection, "Right", 1)
local AURA_LEFT = EnumValue(Enum.AuraFrameIconDirection, "Left", 0)
local AURA_DOWN = EnumValue(Enum.AuraFrameIconWrap, "Down", 0)
local AURAS_A_ROW = 5           -- icons a row (Edit Mode's value is the count): 170 of the header's
                                -- half, the middle left clear over its diamond
local AURAS_OPACITY = 50 - 50   -- the buffs and debuffs 50 % opaque (Edit Mode's value: steps
                                -- over the slider's least, 50 %)
local BUFFS_BUTTON = 15          -- the buffs' collapse button, at their frame's outer end (hidden: its room kept)
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
	-- hidden (VisibleSetting 2 = Enum.CooldownViewerVisibleSetting.Hidden: they showed all the time,
	-- by the character)
	-- (hidden since AishUI: its centre circle stands there, and its priority bar shows the main spells' cooldowns)
	{ system = "CooldownViewer", index = 1, point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 248,
		settings = { IconLimit = 4, VisibleSetting = 2 } },
	{ system = "CooldownViewer", index = 2, point = "TOP", relativePoint = "BOTTOM", x = 0, y = 244,
		settings = { IconLimit = 6, VisibleSetting = 2 } },
	{ system = "CooldownViewer", index = 3, point = "BOTTOMLEFT", relativePoint = "BOTTOM", x = -340, y = 352,
		settings = { VisibleSetting = 2 } },
	-- (test) bottom-left: the chat, from the left edge to the XP bar M away, as tall as the minimap and
	-- its header (its tabs hidden: HideChatTabs; its clamp taken off: UnclampChat). Top-left: the
	-- gamepad help (Legend.lua), the buff bars under its tallest group
	-- (the line you type in is put over the chat, PlaceChat: 7 left and 19 right of it, its tooltip look
	-- drawn about 3 inside, set from zoomed captures so its box runs from 8 to the XP bar - 8, its top on
	-- the minimap header's visible top. The chat is 10..320 across, 595..792 down: its bottom M from
	-- the screen's)
	-- (its background reaches 6 below it, 2 left of it: that background M from the edges, over the XP bar)
	{ system = "ChatFrame", point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 10, y = B + 6,
		settings = { WidthHundreds = 3, WidthTensAndOnes = 10, HeightHundreds = 2, HeightTensAndOnes = 20 } },
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
	-- the game's buffs and debuffs (the gamepad's "Améliorations", LB / RB / Y, goes through these: not
	-- EllesmereUI's, turned off on the Deck profile) at the top, within Improved Forever's target header's
	-- width (its line, HEADER either side of the top's centre; its diamond and name lower down): the
	-- debuffs from its left end, the buffs from its right end, each growing towards the centre,
	-- AURAS_A_ROW icons a row; more rows under. (Their icons sit 1 above the frame)
	{ system = "AuraFrame", index = 1, point = "TOPRIGHT", relativePoint = "TOP", x = HEADER + BUFFS_BUTTON, y = -(M + 1),
		settings = { Orientation = AURA_HORIZONTAL, IconDirection = AURA_LEFT, IconWrap = AURA_DOWN, IconLimitBuffFrame = AURAS_A_ROW,
			Opacity = AURAS_OPACITY } },
	{ system = "AuraFrame", index = 2, point = "TOPLEFT", relativePoint = "TOP", x = -HEADER, y = -(M + 1),
		settings = { Orientation = AURA_HORIZONTAL, IconDirection = AURA_RIGHT, IconWrap = AURA_DOWN, IconLimitDebuffFrame = AURAS_A_ROW,
			Opacity = AURAS_OPACITY } },
	-- the game's menu and bags (hidden by the gamepad UI) out of the way, bottom-right
	{ system = "MicroMenu", point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", x = -M, y = B },
}

-- Easy Controller's supplies (bag space, reagents): set through its own saved position, out of the
-- HUD in the bottom-right corner, left of the minimap, growing left. Its old position is kept in DeckForeverDB.easyController
local EC_SUPPLIES = { pos = { point = "BOTTOMRIGHT", x = -(M + 273 + M), y = B }, layout = "left" }

-- AishUI's EllesmereUI has a minimap of its own (placed by its "Steam Deck" profile,
-- tools/deckprofile): then the game's minimap isn't ours to square or move, and Easy Controller's
-- supplies go left of that one (203 wide; /df go)
local function EllesmereMap()
	return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("EllesmereUIMinimap")
end

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
local classPlaced = setmetatable({}, { __mode = "k" })   -- button -> where we put it (kept here, not on it)
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
		classPlaced[button] = { x, y }
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
	-- pressing it, Blizzard's pressed look (ApplyPressedStyle > ApplyExtraButtonStyles) anchors it again at its
	-- own place, written in its code (-138, -50; 2 lower while held). Put back right after, in the same frame
	-- (never seen moving), the press's offset kept. A post-hook on this one method (nothing replaced; the
	-- hooked method calls no other hooked one). Out of combat only: pressed in combat, it shows at Blizzard's
	-- place until the fight ends (PLAYER_REGEN_ENABLED places it back)
	for _, button in ipairs({ unit.LeftClassAction, unit.RightClassAction }) do
		if button.ApplyPressedStyle then
			hooksecurefunc(button, "ApplyPressedStyle", function(self)
				if InCombatLockdown() or self:IsForbidden() then return end
				local _, relative, _, _, y = self:GetPoint(1)
				local at = classPlaced[self]
				if not (at and relative == unit.BottomCenteredAnchor and y) then return end
				local press = y - BLIZZARD_ACTION_Y               -- (-2 while held, 0 after)
				self:ClearAllPoints()
				self:SetPoint("CENTER", unit.BottomCenteredAnchor, "CENTER", at[1], at[2] + press)
			end)
		end
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
	if not map or map:IsForbidden() or EllesmereMap() then return end
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
	if EllesmereMap() then
		-- EllesmereUI takes the map and shows the coordinates on it: the game's coordinates and day / night
		-- icon, left in its empty container, are hidden (display only)
		if container.PlayerCoords then container.PlayerCoords:SetAlpha(0) end
		if cluster.DielFrame then cluster.DielFrame:SetAlpha(0) end
		return
	end
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
-- bar), and what's only needed for a fight fades out of it (CalmDriver); the gamepad help shows only
-- while LB or RB is held, or in menus. Alpha only,
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
	-- (Improved Forever's quest tracker, shown in the game's one's place: the same)
	IFObjectiveTrackerFrame = function()
		return math.min(Fighting() and IN_COMBAT_ALPHA or 1, TipOverQuests() and QUESTS_UNDER_TIP or 1)
	end,
	-- the gamepad help: hidden at rest (its moves are known by heart); shown while LB or RB is held (their
	-- groups) and in menus
	DeckForeverLegend = function(legend)
		local resting = legend.group == nil or legend.group == "GAMEPLAY"
		return resting and 0 or 1
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
	-- Chattynator's windows (their parent), the same
	ChattynatorHyperlinkHandler = function(frame)
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

-- The player frame and the gamepad bars (Easy Controller's paddles follow the bar's alpha): by a secure
-- state driver, the game's own way to change protected frames (the alpha is set in its restricted
-- environment, never from DeckForever's code). Set up once, out of combat; at once, no fade.
--   * the player frame: faded out of combat with no target (CALM_ALPHA)
--   * the gamepad bar: full in combat; out of combat hidden, up to BAR_AWAKE while LT, RT or the d-pad
--     is pressed ("awake", set below: our own handler's attribute, which addon code may set out of
--     combat), then AWAKE_TIME after the last press (or the fight's end) faded out, gently. Hidden, it
--     still works: the first press both acts and shows it. Under a subtitle of Spoken's (which stands
--     over it then) CALM_ALPHA at most.
local AWAKE_TIME = 0.5               -- (seconds after the last press, or the fight's end, before it fades)
local BAR_AWAKE = 0.5
local CALM_FRAMES = { { "PlayerFrame", CALM_ALPHA }, { "GamepadMainActionBarFrame", 0, true } }
local calmDriver
local function CalmDriver()
	if calmDriver or InCombatLockdown() or not RegisterStateDriver then return end
	calmDriver = CreateFrame("Frame", "DeckForeverCalmDriver", UIParent, "SecureHandlerStateTemplate")
	local n = 0
	for _, entry in ipairs(CALM_FRAMES) do
		local frame = _G[entry[1]]
		if frame and not frame:IsForbidden() then
			n = n + 1
			calmDriver:SetFrameRef("calm" .. n, frame)
			calmDriver:SetAttribute("calmAlpha" .. n, entry[2])
			calmDriver:SetAttribute("wakes" .. n, entry[3] and true or false)
		end
	end
	calmDriver:SetAttribute("calmCount", n)
	-- fight: in combat; target: a target, out of combat; calm: neither
	-- "awake": the bar's alpha out of combat, stepped by the fade below
	calmDriver:SetAttribute("apply", [[
		local fight = self:GetAttribute("state-calm")
		local awake = tonumber(self:GetAttribute("state-awake")) or 0
		for i = 1, self:GetAttribute("calmCount") do
			local frame = self:GetFrameRef("calm" .. i)
			if frame then
				if self:GetAttribute("wakes" .. i) then
					frame:SetAlpha(fight == "fight" and 1 or awake)
				else
					frame:SetAlpha(fight ~= "calm" and 1 or self:GetAttribute("calmAlpha" .. i))
				end
			end
		end
	]])
	calmDriver:SetAttribute("_onstate-calm", [[ self:RunAttribute("apply") ]])
	calmDriver:SetAttribute("_onstate-awake", [[ self:RunAttribute("apply") ]])
	calmDriver:SetAttribute("state-awake", "0")
	RegisterStateDriver(calmDriver, "calm", "[combat] fight; [@target,exists] target; calm")
end

-- What wakes the bar. This client's gamepad bar takes the gamepad's buttons itself (no key bindings: the
-- d-pad and A / B / X / Y are bound to nothing), so the bar's own state is read, measured on it:
--   * LT / RT held: it shows its left / right page (…LeftCenteredAnchorLeftBar, …RightCenteredAnchorRightBar),
--     both its bottom one; and the triggers are read themselves (TriggerHeld)
--   * the d-pad: its main page's buttons 1 to 4 show pushed (5 to 8 are A / B / X / Y: they don't wake it,
--     nor does LB, the allies' targeting page)
-- None of it while a window, a menu or a text box has the focus (ElsewhereFocus).
-- Read 10 times a second, out of combat: only getters, nothing hooked, nothing set on Blizzard's frames.
local PAGE = "GamepadMainActionBarFramePageUnit"
local WAKE_PAGES = { PAGE .. "LeftCenteredAnchorLeftBar", PAGE .. "RightCenteredAnchorRightBar",
	PAGE .. "BottomCenteredAnchorBottomBar" }
-- The triggers themselves, read too: a trigger that's a modifier (Easy Controller makes RT one, Alt or
-- Ctrl, for its paddle layers) may not turn the bar's page, and LT + RT shows the bottom page
local TRIGGERS = { "PADLTRIGGER", "PADRTRIGGER" }
local EMULATED = { GamePadEmulateShift = IsShiftKeyDown, GamePadEmulateCtrl = IsControlKeyDown,
	GamePadEmulateAlt = IsAltKeyDown }
local function TriggerHeld()
	for _, key in ipairs(TRIGGERS) do
		if IsKeyDown and IsKeyDown(key) then return true end
		for cvar, down in pairs(EMULATED) do
			if down and GetCVar(cvar) == key and down() then return true end
		end
	end
	return false
end
local DPAD_BUTTON = PAGE .. "TopCenteredAnchorTopBarActionButton"
-- Not while the game's own focus is elsewhere: a window or menu open (the gamepad then drives a cursor:
-- freelook off), the chat's line or any text box taking the keys, the game menu
local PANELS = { "left", "center", "right", "doublewide", "fullscreen" }
local function ElsewhereFocus()
	if IsGamePadFreelookEnabled and not IsGamePadFreelookEnabled() then return true end
	if GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus() then return true end
	if GameMenuFrame and GameMenuFrame:IsShown() then return true end
	if GetUIPanel then
		for _, slot in ipairs(PANELS) do if GetUIPanel(slot) then return true end end
	end
	return false
end
local padTick = 0
local function Pressed(elapsed)
	padTick = padTick + elapsed
	if padTick < 0.1 then return false end
	padTick = 0
	if ElsewhereFocus() then return false end
	if TriggerHeld() then return true end
	for _, name in ipairs(WAKE_PAGES) do
		local bar = _G[name]
		if bar and bar:IsShown() then return true end
	end
	for i = 1, 4 do
		local button = _G[DPAD_BUTTON .. i]
		if button and button:GetButtonState() == "PUSHED" then return true end
	end
	return false
end
local AWAKE_IN, AWAKE_OUT = 0.2, 0.8     -- (up quick, as it's pressed; down gently)
local awakeUntil = 0
local level, fromLevel, fadeStart, fadeGoal = 0, 0, 0, 0
local function EaseOut(p) return p >= 1 and 1 or 1 - (1 - p) ^ 3 end
local function Smooth(p)                  -- (cubic, slow at both ends)
	if p >= 1 then return 1 end
	return p < 0.5 and 4 * p ^ 3 or 1 - (-2 * p + 2) ^ 3 / 2
end
local function SetLevel(value)
	level = value
	if calmDriver and not InCombatLockdown() then
		local text = ("%.3f"):format(value)
		if calmDriver:GetAttribute("state-awake") ~= text then calmDriver:SetAttribute("state-awake", text) end
	end
end
local function Wake() awakeUntil = GetTime() + AWAKE_TIME end
do
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
	watcher:SetScript("OnEvent", function()          -- (full through the fight: faded from AWAKE_TIME on)
		Wake()
		fadeGoal, fromLevel, fadeStart = 1, 1, GetTime()
		SetLevel(1)
	end)
	watcher:SetScript("OnUpdate", function(_, elapsed)
		if not calmDriver or InCombatLockdown() then return end
		if Pressed(elapsed) then Wake() end
		local now = GetTime()
		-- (the fight's end: fading from full; a press out of one: up to BAR_AWAKE)
		local goal = now < awakeUntil and (fadeGoal == 1 and 1 or BAR_AWAKE) or 0
		-- (quieter under a subtitle of Spoken's, which stands under the character then: Readability.lua)
		if goal > CALM_ALPHA and ns.SpokenSubtitleShown and ns.SpokenSubtitleShown() then goal = CALM_ALPHA end
		if goal ~= fadeGoal then fadeGoal, fromLevel, fadeStart = goal, level, now end
		if level == goal then return end
		local up = goal > fromLevel
		local p = (now - fadeStart) / (up and AWAKE_IN or AWAKE_OUT)
		SetLevel(fromLevel + (goal - fromLevel) * (up and EaseOut(p) or Smooth(p)))
	end)
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
-- AishUI's Chattynator draws the chat itself (its window placed by its profile, tools/deckprofile): the
-- game's chat frame is hidden, and Chattynator styles and places the line you type in
local function Chattynator()
	return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Chattynator")
end

-- Chattynator's tabs: only while you type (so the channel can be picked) or under the mouse; never over
-- an empty chat otherwise. Its "hover" mode hides them only as it builds them, so a rebuilt tab bar stays
-- shown: they are held to that here, hidden 2 s after the last reason to show them (Chattynator's own
-- delay). The line's focus is read each frame (no hook on the game's edit box).
do
	local HOLD = 2
	local watcher = CreateFrame("Frame")
	local since = {}
	watcher:SetScript("OnUpdate", function(_, elapsed)
		if not Chattynator() then return end
		local box = _G.ChatFrame1EditBox
		local typing = box and box:HasFocus() or false
		local parent = _G.ChattynatorHyperlinkHandler
		for _, window in ipairs(parent and { parent:GetChildren() } or {}) do
			local tabs = window.TabsBar
			if tabs and not tabs.lockActive then        -- (lockActive: tabs set to always show)
				if typing or tabs:IsMouseOver() then
					since[tabs] = 0
					if tabs:GetAlpha() < 1 then tabs:SetAlpha(1) end
					tabs.active = true
				else
					since[tabs] = (since[tabs] or 0) + elapsed
					if since[tabs] >= HOLD and tabs:GetAlpha() > 0 then
						tabs:SetAlpha(0)
						tabs.active = false
					end
				end
			end
		end
	end)
end

local function SkinEditBox()
	local box = _G.ChatFrame1EditBox
	if editSkinned or not box or box:IsForbidden() or Chattynator() then return end
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
local EC_LABELS = 13
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
	-- the coordinates under the minimap (font strings of no name, on the container's PlayerCoords)
	local container = MinimapCluster and MinimapCluster.MinimapContainer
	local coords = container and container.PlayerCoords
	for _, r in ipairs(coords and { coords:GetRegions() } or {}) do
		if r:GetObjectType() == "FontString" then Enlarge(r, 2) end
	end
	-- the names Easy Controller writes by the minimap's dots: its own setting (7..16, its 10 read as 8
	-- at the minimap's zoom), set once
	local ec = _G.ControllerKeyboard
	local labels = ec and ec.db and ec.db.settings and ec.db.settings.minimapLabels
	if type(labels) == "table" and not DeckForeverDB.ecLabelsSet then
		DeckForeverDB.ecLabelsSet = true
		if (labels.size or 10) < EC_LABELS then labels.size = EC_LABELS end
	end
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
-- Improved Forever's quest tracker (ImprovedForever_QuestTracker), a fork of the game's shown instead of
-- it, is held by the game's tracker's top edge (both corners): as wide, its contents narrowed the same way
local TRACKERS = { "ObjectiveTrackerFrame", "IFObjectiveTrackerFrame" }
local function NarrowTracker(tracker, width)
	if not tracker or tracker:IsForbidden() then return end
	tracker:SetClampedToScreen(false)
	NarrowHeader(tracker.Header, width, 52)
	for _, module in ipairs(tracker.modules or {}) do
		if not module:IsForbidden() then
			module:SetWidth(width)
			NarrowHeader(module.Header, width, 60)
		end
	end
end
local function NarrowQuests()
	if not oursActive then return end
	local width = QuestsWidth()
	for _, name in ipairs(TRACKERS) do NarrowTracker(_G[name], width) end
end
local questsHooked = {}
local function HookQuests()
	for _, name in ipairs(TRACKERS) do
		local tracker = _G[name]
		if not questsHooked[name] and tracker and tracker.AddModule then
			questsHooked[name] = true
			hooksecurefunc(tracker, "AddModule", function() NarrowQuests() end)
		end
	end
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
	if DeckForeverDB.back then DeckForeverDB.back[UnitGUID("player") or ""] = nil end
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
		if EllesmereMap() then supplies.pos.x = -(M + 203 + M) end
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
	if not chat or chat:IsForbidden() or InCombatLockdown() or Chattynator() then return end
	local layouts, active = Layouts()
	local layout = layouts[active]
	if not layout or layout.layoutName ~= TARGET_LAYOUT or layout.layoutType == Enum.EditModeLayoutType.Preset then return end
	for _, entry in ipairs(LAYOUT) do
		if entry.system == "ChatFrame" then
			UnclampChat()
			chat:ClearAllPoints()
			chat:SetPoint(entry.point, UIParent, entry.relativePoint, entry.x, entry.y)
			-- the line you type in over the chat's top lines while you type (its box on the chat's background
			-- edges), above the chat's text (a higher strata)
			local box = _G.ChatFrame1EditBox
			if box and not box:IsForbidden() then
				box:ClearAllPoints()
				box:SetPoint("TOPLEFT", chat, "TOPLEFT", -7, 5)
				box:SetPoint("TOPRIGHT", chat, "TOPRIGHT", 19, 5)
				box:SetFrameStrata("MEDIUM")
			end
		end
	end
end

local function Back()
	if not EditModeReady() then return end
	-- (this character stays off ours: not put back at its next login, Detect)
	DeckForeverDB.back = DeckForeverDB.back or {}
	DeckForeverDB.back[UnitGUID("player") or ""] = true
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
	elseif msg == "test" then
		-- (the reload strip, Characters.lua, at the next login or reload: as it shows for real, the chat
		-- and Easy Controller's keyboard closed)
		DeckForeverDB.testStrip = true
		Print("bandeau de rechargement au prochain /reload.")
	elseif msg == "camera" or msg == "vue" then
		ns.CameraProfile(Print)
	else
		Print("/df go : disposition « " .. TARGET_LAYOUT .. " » · /df back : retour à « " .. (DeckForeverDB.previous or SOURCE_LAYOUT) .. " » · /df fx : aperçu combat · /df camera : profil caméra DynamicCam.")
	end
end

-- Edit Mode lays the chat out again (with its clamp) as it closes: put back after it
if EventRegistry and EventRegistry.RegisterCallback then
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		C_Timer.After(0, function() pcall(PlaceChat) PlaceMinimap() NarrowQuests() end)
	end, "DeckForever")
end

-- What's only done with our layout in use, once it is (each piece guards itself: safe to run again)
local function SetupOurs()
	CalmDriver()
	SkinEditBox()
	BiggerText()
	XPBar()
	StatusText()
	HookQuests()
	NarrowQuests()
	pcall(PlaceChat)
	-- (Edit Mode may lay the chat out again, its clamp with it, after this: placed once more a moment later)
	C_Timer.After(1, function() pcall(PlaceChat) end)
end

-- Is our layout the one in use? At login Edit Mode may not have its layouts yet as the world loads
-- (more addons, later): asked again every second until it has them, and whenever they change
local DETECT_TRIES = 15
local checked                   -- the layout checked once, at the first login of the session
local autoPlaced                -- ours put in use by Detect, once a session
local tries = 0
local function Detect()
	if not (C_EditMode and EditModePresetLayoutManager) then return end
	local ok, layouts, active, _, saved = pcall(Layouts)
	local ready = ok and active and saved and saved.layouts and #saved.layouts > 0 and layouts[active]
	if not ready then
		tries = tries + 1
		if tries <= DETECT_TRIES then C_Timer.After(1, Detect) end
		return
	end
	local layout = layouts[active]
	local was = oursActive
	oursActive = layout.layoutName == TARGET_LAYOUT and layout.layoutType ~= Enum.EditModeLayoutType.Preset
	if oursActive and not InCombatLockdown() then SetupOurs() end
	-- Ours on every character (Characters.lua): a character on another layout (a new one: the game's
	-- gamepad preset) is put on ours, saved first when the account has none, unless it went back with
	-- /df back. Once a session; a reload asked
	if not oursActive and not autoPlaced and not InCombatLockdown()
		and not (DeckForeverDB.back and DeckForeverDB.back[UnitGUID("player") or ""]) then
		autoPlaced = true
		checked = true
		local index = FindLayout(layouts, TARGET_LAYOUT)
		if index then C_EditMode.SetActiveLayout(index) else Apply() end
		if ns.NeedReload then ns.NeedReload("disposition") end
		return
	end
	-- (once a session, the layouts known: a game bug drops elements from saved layouts at launch)
	if not checked then
		checked = true
		local fine, holds = pcall(Holds)
		if fine and not holds and not InCombatLockdown() then
			Print("la disposition avait perdu des éléments (bug du jeu) : réparée.")
			Apply()
		end
	end
	if was and not oursActive then
		Print("disposition DeckForever quittée : /reload pour revenir à l'interface de Blizzard.")
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")      -- (a class action shown or hidden in combat: placed after)
pcall(f.RegisterEvent, f, "EDIT_MODE_LAYOUTS_UPDATED")
f:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name == "DeckForever" then
			DeckForeverDB = DeckForeverDB or {}
			UnclampChat()                    -- (before Edit Mode places the chat, as the layout loads)
		end
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then PlaceClassAction() return end
	if event == "EDIT_MODE_LAYOUTS_UPDATED" then Detect() return end
	HookClassAction()
	PlaceClassAction()
	HideChatTabs()
	HookTooltip()
	Detect()
	SquareMinimap()
	PlaceMinimap()
	if C_EditMode and EditModePresetLayoutManager then pcall(PlaceChat) end
end)
