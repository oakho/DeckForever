--------------------------------------------------------------------------------
-- Other addons' text made readable on the Deck's screen, without changing them.
--   * Improved Forever's target header (ImprovedForever_Immersion, TargetHeader.lua): its name is in
--     Morpheus at 30, drawn at 60 % (SetTextScale) with no outline, its lines in the game's small font:
--     blurry and small at 1280 x 800. Set once to a plain font with an outline, bigger; its own code only
--     scales and moves them afterwards (it never sets their font again). Its headers (target, zone, level)
--     hang on one origin, 130 under the screen's top: moved up to HEADER_Y, out of the way of the view
--     (the top's free: AishUI's target bar is off). Its first-time tour moves it and puts it back at 130.
--   * AishUI's level badge (its XP bar), bottom left: its dark brush has clear edges and stops short of
--     the screen's corner. The same brush, drawn under it, fills the corner (ours: nothing of AishUI's
--     moved; the level stays centred on AishUI's brush).
--   * the game's gamepad wheel (GamepadRadial, not protected): 312 right of the screen's centre, put on it
--   * Easy Controller's supplies (bag space, reagents): their counts are in NumberFontNormal, thickly
--     outlined in black; on the orange "low" pill the count is dark brown: a blur. Plain Arial Narrow
--     with a light shadow, readable on the dark pill and the orange one (Easy Controller sets the colour).
--   * Spoken's subtitles (its narrator's captions, UI/Subtitle.lua): their top edge 336 up from the bottom,
--     down over AishCore's fight block and the gamepad bar (up to about 300). Put over the character,
--     centred still, by the camera's two views (Camera.lua): out of a fight under the character (the
--     fight's bars and the gamepad bar are hidden then), their top M under AishCore's resource badge,
--     which hangs a little under its feet; in a fight (it stands higher) over it, M under the game's red
--     error lines (UIErrorsFrame, read where it is). As a fight begins and ends they slide away fading
--     out, slowly, then slide in fading in at their new place. Drawn over the gamepad bar, which is
--     quieter under them (DeckForever.lua, its fade). Only while not dragged: a place of the player's (Spoken's Layout().Subtitle without our mark)
--     is left as it is.
--   * the vendor's items (the game's MerchantFrame, skinned by EllesmereUI): their names in PT Sans Narrow at
--     10 (about 9.6 px on the Deck), a blur. Same font, at MERCHANT_SIZE, with a light shadow, set as the
--     window opens (the interaction's event: MERCHANT_SHOW doesn't come on this client)
--------------------------------------------------------------------------------

local _, ns = ...

local FONT = "Fonts\\FRIZQT__.TTF"
local NAME_SIZE = 40                   -- (shown at 60 % by Improved Forever: about 24)
local LINE_SIZE = 14
local HEADER_Y = 72                    -- (the gold rule's height from the screen's top; Improved Forever: 130)

local done = setmetatable({}, { __mode = "k" })
local morpheus = setmetatable({}, { __mode = "k" })    -- (FontStrings Improved Forever made in Morpheus: Unmorph)
local function Sharpen(fs, size)
	if done[fs] or fs:IsForbidden() then return end
	local ok = fs:SetFont(FONT, size, "OUTLINE")
	if ok ~= false then
		done[fs] = true
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.8)
	end
end

local function TargetHeader()
	local header = _G.ImprovedForeverTargetHeader
	if not header then return false end
	local function walk(frame, depth)
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:GetObjectType() == "FontString" then
				local font, size = region:GetFont()
				-- (the name: the big Morpheus line (made Friz already: see Unmorph); every other line: the small one)
				if morpheus[region] or font and font:upper():find("MORPHEUS") then Sharpen(region, NAME_SIZE)
				else Sharpen(region, math.max(LINE_SIZE, size or 0)) end
			end
		end
		if depth < 4 then
			for _, child in ipairs({ frame:GetChildren() }) do walk(child, depth + 1) end
		end
	end
	walk(header, 0)
	return true
end

local function MoveHeader()
	local header = _G.ImprovedForeverTargetHeader
	if not header then return end
	local _, origin = header:GetPoint(1)
	if not origin or origin == UIParent or origin:IsForbidden() then return end
	origin:ClearAllPoints()
	origin:SetPoint("CENTER", UIParent, "TOP", 0, -HEADER_Y)
end

-- Improved Forever's Morpheus (its headers, cards, tooltip, nameplates, camp, journal, tour...): hard to read
-- on the Deck. Every font Improved Forever's code asks in Morpheus is turned into the target header's (above):
-- Friz Quadrata outlined, at 80 % of the size asked (Friz is bigger at the same size: the cards' title,
-- Morpheus 22, comes out at 18). The journal's parchment (ImprovedForever_Journal, ImprovedForever/Book.lua)
-- gets no outline: black on ink is a smudge. One post-hook on the FontString's and the Font's SetFont (they
-- load after us, so every string is caught as it's made): a call that isn't Morpheus returns at once; the
-- caller is told by the stack (only Improved Forever's files). Our own SetFont is the method from before the
-- hook: a hooked function never runs inside its own hook.
local MORPH_RATIO = 0.8
local function Unmorph(kind)
	local methods = kind and getmetatable(kind) and getmetatable(kind).__index
	if type(methods) ~= "table" or type(methods.SetFont) ~= "function" then return end
	local rawSetFont = methods.SetFont
	hooksecurefunc(methods, "SetFont", function(obj, font, size, flags)
		if type(font) ~= "string" or not font:upper():find("MORPHEUS", 1, true) then return end
		local stack = debugstack(2, 4, 0) or ""
		if not stack:find("ImprovedForever", 1, true) then return end
		local parchment = stack:find("ImprovedForever_Journal", 1, true) or stack:find("ImprovedForever/Book.lua", 1, true)
		morpheus[obj] = true
		rawSetFont(obj, FONT, math.floor((tonumber(size) or 14) * MORPH_RATIO + 0.5), parchment and (flags or "") or "OUTLINE")
	end)
end
Unmorph(UIParent:CreateFontString())
Unmorph(GameFontNormal)

-- Improved Forever's cards (top left: the world tooltip, the quests' cards) are kept under the Fishing module's
-- guide line (Card.Top: ImprovedForever.Fishing.GuideBottom, 70 down), shown or not: the player's own top
-- padding (sidebarTop, 5 %: about 42) did nothing. The guide's room counted only while it shows (fishing);
-- the cards are docked again each frame, so they slide down under it and back up.
local guideWrapped
local function FishingGuide()
	local F = ImprovedForever and ImprovedForever.Fishing
	if guideWrapped or not F or type(F.GuideBottom) ~= "function" then return end
	guideWrapped = true
	local GuideBottom = F.GuideBottom
	F.GuideBottom = function(...)
		local guide = _G.ImprovedForeverFishingGuide
		if guide and not guide:IsShown() then return nil end
		return GuideBottom(...)
	end
end

-- Improved Forever's cards, top left, M from the screen's edges like the quests (top right) and the minimap
-- (bottom right) (Card.lua docks the first at 40 from the left, the player's top padding (5 %: 40) down;
-- the diamond's points are the panel's edges). Not while the Fishing guide shows (the cards keep under it),
-- nor while the pad is on the quests' cards: their legend (QuestPeek.lua) is placed above the cards' default
-- corner, which then has to be free. Card:Dock runs every frame; ours moves the panel only when it's elsewhere.
local CARD_M = 8
local cornerWrapped, peekLegend
local function FindPeekLegend()
	for _, child in ipairs({ UIParent:GetChildren() }) do
		local ok, found = pcall(function()
			return not child:IsForbidden() and child.rings and child.row and child.SetPress
				and child:GetFrameStrata() == "TOOLTIP"
		end)
		if ok and found then return child end
	end
end
local function CardsCorner()
	local IN = ImprovedForever and ImprovedForever.Interface
	local Card = IN and IN.Card
	peekLegend = peekLegend or FindPeekLegend()
	if cornerWrapped or not Card or type(Card.Dock) ~= "function" then return end
	cornerWrapped = true
	local Dock = Card.Dock
	Card.Dock = function(self, ...)
		Dock(self, ...)
		local panel = self.panel
		if not panel or panel:GetNumPoints() ~= 1 then return end
		local _, relative, _, x, y = panel:GetPoint(1)
		if relative ~= UIParent then return end              -- (under another card)
		local scale, h = Card.Scale(), UIParent:GetHeight()
		local guide = _G.ImprovedForeverFishingGuide
		local tx, ty
		if peekLegend and peekLegend:IsShown() then
			tx, ty = (Card.CORNER_X or 40) / scale, -h * Card.Top() / scale
		else
			tx = CARD_M / scale
			ty = -((guide and guide:IsShown()) and h * Card.Top() or CARD_M) / scale
		end
		if math.abs(x - tx) > 0.5 or math.abs(y - ty) > 0.5 then
			panel:ClearAllPoints()
			panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", tx, ty)
		end
	end
end

local BRUSH = "Interface\\AddOns\\AishCore\\Media\\XPBar\\grunge_spot1.png"
local CORNER = { x = -46, y = -34, w = 124, h = 80 }      -- (its dark body over the corner, its top under the badge's)
local corner
local function LevelCorner()
	if corner or not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("AishCore")) then return end
	corner = CreateFrame("Frame", "DeckForeverLevelCorner", UIParent)
	corner:SetFrameStrata("BACKGROUND")
	corner:SetFrameLevel(0)
	corner:SetSize(CORNER.w, CORNER.h)
	corner:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", CORNER.x, CORNER.y)
	corner:EnableMouse(false)
	local tex = corner:CreateTexture(nil, "BACKGROUND")
	tex:SetAllPoints()
	tex:SetTexture(BRUSH)
	tex:SetVertexColor(0, 0, 0, 0.9)
	tex:SetRotation(math.rad(175))
end

local function SupplyCounts()
	local bar = _G.ControllerKeyboardSupplies
	for _, button in ipairs(bar and bar.buttons or {}) do
		local count = button.count
		if count and not done[count] and not count:IsForbidden() then
			if count:SetFont("Fonts\\ARIALN.TTF", 14, "") ~= false then
				done[count] = true
				count:SetShadowOffset(1, -1)
				count:SetShadowColor(0, 0, 0, 0.6)
			end
		end
	end
end

local function CentreRadial()
	local radial = _G.GamepadRadial
	if not radial or radial:IsForbidden() or radial:IsProtected() then return end
	radial:ClearAllPoints()
	radial:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TARGET_CHANGED")       -- (lines may be made as the header first shows)
f:RegisterEvent("BAG_UPDATE_DELAYED")          -- (a supply's button made as it first shows)
f:SetScript("OnEvent", function() pcall(TargetHeader) pcall(MoveHeader) pcall(FishingGuide) pcall(CardsCorner) pcall(LevelCorner) pcall(SupplyCounts) pcall(CentreRadial)
	C_Timer.After(2, function() pcall(SupplyCounts) end) end)

-- Spoken's subtitles by the character (see the top)
local CALM_TOP = 0.236                 -- (out of a fight, up from the bottom: M under the resource badge,
                                       -- 197 up on the Deck's 800: tools/deckprofile/placements.lua)
local function SpokenTop()
	if InCombatLockdown() or UnitAffectingCombat("player") then
		local errors = _G.UIErrorsFrame
		local bottom = errors and errors:GetBottom()
		local scale = errors and errors:GetEffectiveScale() / UIParent:GetEffectiveScale() or 1
		return (bottom and bottom * scale or UIParent:GetHeight() - 182) - 8
	end
	return UIParent:GetHeight() * CALM_TOP
end
-- (out in AWAY seconds, sliding SLIDE the move's way, fading out, slow then quicker (quartic); unseen for
-- GAP, as the camera moves; in in BACK, sliding the last SLIDE, fading in, quick then braking to a stop
-- (quintic))
local AWAY, GAP, BACK, SLIDE = 0.4, 0.1, 0.7, 40   -- (0.8 in all was too quick, 1.9 too slow)
local glide = CreateFrame("Frame")
local function PlaceSpoken(event)
	local env = rawget(_G, "SpokenEnv")
	local addon = env and rawget(env, "Addon")
	if not (addon and addon.Layout and addon.db) then return end
	local layout = addon:Layout()
	local saved = layout.Subtitle
	if type(saved) == "table" and not saved.deckForever then return end   -- (dragged by the player)
	local subtitle = rawget(env, "Subtitle")
	local from = type(saved) == "table" and tonumber(saved.top)
	local to = SpokenTop()
	-- (the place kept is the end one: Spoken placing it meanwhile puts it there)
	layout.Subtitle = { top = to, x = 0, deckForever = true }
	if not (subtitle and subtitle.frame and subtitle.Place) then return end
	local frame = subtitle.frame
	local moving = event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED"
	glide:SetScript("OnUpdate", nil)
	if not (moving and from and frame:IsShown()) or from == to then
		subtitle:Place()
		return
	end
	local way = to > from and 1 or -1
	local start, alpha = GetTime(), frame:GetAlpha()
	local function Alpha(value)            -- (not while Spoken fades it in or out itself)
		if not subtitle.fadeTime then frame:SetAlpha(value) end
	end
	local function Smooth(q) return 0.5 - 0.5 * math.cos(math.pi * q) end
	glide:SetScript("OnUpdate", function(self)
		local t = GetTime() - start
		if t < AWAY then
			local q = t / AWAY
			pcall(subtitle.Place, subtitle, from + way * SLIDE * q ^ 4, 0)
			Alpha(alpha * (1 - Smooth(q)))
		elseif t < AWAY + GAP then
			Alpha(0)
		else
			local q = math.min(1, (t - AWAY - GAP) / BACK)
			pcall(subtitle.Place, subtitle, to - way * SLIDE * (1 - q) ^ 5, 0)
			Alpha(1 - (1 - q) ^ 3)
			if q >= 1 then self:SetScript("OnUpdate", nil) end
		end
	end)
end
-- Is a subtitle shown? (read by the gamepad bar's fade, DeckForever.lua: quieter under one.) Over the gamepad
-- bar, as it's woken out of a fight under the character: Spoken's LOW put up to HIGH
function ns.SpokenSubtitleShown()
	local env = rawget(_G, "SpokenEnv")
	local subtitle = env and rawget(env, "Subtitle")
	local frame = subtitle and subtitle.frame
	if not frame then return false end
	if frame:GetFrameStrata() ~= "HIGH" then frame:SetFrameStrata("HIGH") end
	return frame:IsShown() and frame:GetAlpha() > 0.05
end
local spokenWatch = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
	spokenWatch:RegisterEvent(event)
end
spokenWatch:SetScript("OnEvent", function(_, event) pcall(PlaceSpoken, event) end)

-- The vendor's item names (see the top)
local MERCHANT_SIZE = 13          -- (12: still too small for the user; a long name is cut after its second line, whole in the tooltip)
local function MerchantNames()
	for i = 1, (MERCHANT_ITEMS_PER_PAGE or 12) do
		local fs = _G["MerchantItem" .. i .. "Name"]
		if fs and not fs:IsForbidden() then
			local file, size, flags = fs:GetFont()
			if file and size ~= MERCHANT_SIZE then
				fs:SetFont(file, MERCHANT_SIZE, flags or "")
				fs:SetShadowOffset(1, -1)
				fs:SetShadowColor(0, 0, 0, 0.8)
			end
		end
	end
end
local merchantWatch = CreateFrame("Frame")
merchantWatch:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
merchantWatch:SetScript("OnEvent", function(_, _, kind)
	if kind ~= 5 then return end        -- (Enum.PlayerInteractionType.Merchant)
	for _, delay in ipairs({ 0, 0.3 }) do C_Timer.After(delay, function() pcall(MerchantNames) end) end
end)
