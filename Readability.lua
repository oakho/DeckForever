--------------------------------------------------------------------------------
-- Other addons' text made readable on the Deck's screen, without changing them.
--   * Improved Forever's target header (ImprovedForever_Immersion, TargetHeader.lua): its name is in
--     Morpheus at 30, drawn at 60 % (SetTextScale) with no outline, its lines in the game's small font:
--     blurry and small at 1280 x 800. Set once to a plain font with an outline, bigger; its own code only
--     scales and moves them afterwards (it never sets their font again).
--------------------------------------------------------------------------------

local FONT = "Fonts\\FRIZQT__.TTF"
local NAME_SIZE = 40                   -- (shown at 60 % by Improved Forever: about 24)
local LINE_SIZE = 14

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

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TARGET_CHANGED")       -- (lines may be made as the header first shows)
f:SetScript("OnEvent", function() pcall(TargetHeader) end)
