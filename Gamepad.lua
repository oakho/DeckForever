--------------------------------------------------------------------------------
-- Other addons' windows that the gamepad can't drive, set back to the game's own on the Deck.
--   * Plumber's loot window (its "LootUI" module): it takes the game's loot window's place, and the
--     gamepad's cursor doesn't reach it. Kept off (PlumberDB.LootUI), set as Plumber loads, before it
--     reads it: the game's loot window, which the gamepad drives, comes back. Plumber's fast looting
--     (its "FastLoot" module) is left as it is.
--   * Improved Forever's "Destroy" prompt (ImprovedForever_Junk, Destroy.lua), joined to the loot window's
--     gamepad legend once the bags are full: set just past the legend's box, not in it (resizing the
--     game's box from an addon taints the loot window), it hangs over nothing. Given a box of its own in
--     the legend's look (its very art), M right of the game's (the game's box never touched: ours, round its prompt, a
--     frame of Improved Forever's)
--------------------------------------------------------------------------------

local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_LOADED")
watch:SetScript("OnEvent", function(self, _, name)
	if name ~= "Plumber" then return end
	self:UnregisterEvent("ADDON_LOADED")
	PlumberDB = PlumberDB or {}
	PlumberDB.LootUI = false
end)

-- Improved Forever's Destroy prompt in a box of its own (see the top)
local M = 8
local LEGEND_PAD = 10                  -- (the game's legend: its prompts that far in from its box's edge)
local holder, pill
local function Box()
	if not holder then
		for _, frame in ipairs({ UIParent:GetChildren() }) do
			if frame.prompt and frame.prompt.SetPromptText and frame:GetFrameStrata() == "FULLSCREEN_DIALOG" then
				holder = frame
				break
			end
		end
		if not holder then return end
	end
	local box = holder.box
	-- (hidden, Improved Forever puts its prompt back at its own place when it shows it again: ours after)
	if not (holder:IsShown() and box) then
		if pill then pill.box = nil end
		return
	end
	if not pill then
		-- (the legend box's own art, measured on it: its slot and its frame, stretched to its size)
		pill = CreateFrame("Frame", nil, holder)
		pill:SetFrameLevel(math.max(0, holder.prompt:GetFrameLevel() - 1))
		for _, atlas in ipairs({ "gamepad-footer-slot-bg", "gamepad-footer-slot-frameneutral" }) do
			local t = pill:CreateTexture(nil, "ARTWORK")
			t:SetAtlas(atlas)
			t:SetAllPoints()
		end
	end
	if pill.box ~= box then
		pill.box = box
		holder.prompt:ClearAllPoints()
		holder.prompt:SetPoint("TOPLEFT", box, "TOPRIGHT", M + LEGEND_PAD, -LEGEND_PAD)
		pill:ClearAllPoints()
		pill:SetPoint("TOPLEFT", box, "TOPRIGHT", M, 0)
		pill:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", M, 0)
		pill:SetPoint("RIGHT", holder.prompt, "RIGHT", LEGEND_PAD, 0)
	end
end
local boxWatch = CreateFrame("Frame")
local boxTick = 0
boxWatch:SetScript("OnUpdate", function(_, elapsed)
	boxTick = boxTick + elapsed
	if boxTick < 0.1 then return end
	boxTick = 0
	if holder or (_G.LootFrame and _G.LootFrame:IsShown()) then pcall(Box) end
end)
