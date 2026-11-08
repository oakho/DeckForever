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
--------------------------------------------------------------------------------

local FONT = "Fonts\\FRIZQT__.TTF"
local NAME_SIZE = 40                   -- (shown at 60 % by Improved Forever: about 24)
local LINE_SIZE = 14
local HEADER_Y = 72                    -- (the gold rule's height from the screen's top; Improved Forever: 130)

local done = setmetatable({}, { __mode = "k" })
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
				-- (the name: the big Morpheus line; every other line: the small one)
				if font and font:upper():find("MORPHEUS") then Sharpen(region, NAME_SIZE)
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
f:SetScript("OnEvent", function() pcall(TargetHeader) pcall(MoveHeader) pcall(LevelCorner) pcall(SupplyCounts) pcall(CentreRadial)
	C_Timer.After(2, function() pcall(SupplyCounts) end) end)
