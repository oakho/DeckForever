--------------------------------------------------------------------------------
-- The gamepad bar as one horizontal strip at the screen's bottom, as Guild Wars 2's skill bar (experimental):
-- two groups of 4, the d-pad's (left, up, down, right) and the face buttons' (X, Y, A, B), each button's
-- glyph under its tile, apart by a gap holding either a round in AishCore's look (a ring of your health, as
-- AishCore's resource circle draws its arc) or nothing.
-- Ours only shows. The game's bar (Blizzard_GamepadActionBars) still takes every press and keeps every slot:
-- the Bindings tab and its own editor are as they were. It's drawn at 0 by CalmDriver (DeckForever.lua: the
-- secure state driver, the game's own way; set from addon code, its alpha would taint the gamepad UI) while
-- the strip is on. Ours mirrors the buttons of whichever bar the game has active (its top one, LT's, RT's,
-- LT + RT's, or one standing in: a vehicle's...): the tiles change in place as a trigger is held, four pips
-- under the gap saying which page is up. Its two class actions (L1 + L2, R1 + R2) over the strip's ends.
-- Read a few dozen times a second: only getters on the game's frames, nothing set, nothing hooked.
-- Shown as the game's bar would be (CalmDriver's state: full in a fight, out of one only while woken).
-- /df skill: off -> round -> gap -> off (DeckForeverDB.skillBar). Easy Controller's paddles, which follow the
-- game's bar's alpha, are hidden with it while the strip is on.
--------------------------------------------------------------------------------

local _, ns = ...

local M = 8
local B = M + 4                         -- (from the bottom: over the XP bar)
local TILE, GAP = 44, 4                 -- (a tile's side; between two of a group)
local GLYPH, GLYPH_GAP = 30, 0          -- (each button's glyph, under its tile)
local ROUND = 72                        -- (the round's width; the gap round it: ROUND_ROOM)
local ROUND_ROOM, PLAIN_ROOM = ROUND + 2 * 12, 56
local CLASS = 34                        -- (a class action's tile, over the strip's end)
local PIP = 5
local ROW_Y = B + GLYPH + GLYPH_GAP + TILE / 2      -- (the tiles' middle, up from the screen's bottom)
local ICON_CROP = { 0.07, 0.93, 0.07, 0.93 }

-- the game's buttons in a cluster: 1 left, 2 up, 3 right, 4 down (the face's: X, Y, B, A); shown in that order
local ORDER = { 1, 2, 4, 3 }
local KEYS = {
	left = { "PADDLEFT", "PADDUP", "PADDRIGHT", "PADDDOWN" },
	right = { "PAD3", "PAD4", "PAD2", "PAD1" },
}

local function Secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
local function Mode()
	local mode = DeckForeverDB and DeckForeverDB.skillBar
	return (mode == "round" or mode == "gap") and mode or nil
end
local function PageUnit()
	local main = _G.GamepadMainActionBarFrame
	return main and main.PageUnit
end

------------------------------------------------------------------ the frames
local strip = CreateFrame("Frame", "DeckForeverSkillBar", UIParent)
strip:SetFrameStrata("MEDIUM")
strip:SetSize(1, 1)
strip:SetPoint("CENTER", UIParent, "BOTTOM", 0, ROW_Y)
strip:EnableMouse(false)
strip:Hide()

local tiles = { left = {}, right = {} }
local function Glyph(parent)
	local tex = parent:CreateTexture(nil, "OVERLAY")
	tex:SetSize(GLYPH, GLYPH)
	return tex
end
-- (the glyphs: Improved Forever's (the gamepad's own look: Xbox, PlayStation...), loaded after us)
local function SetGlyphs()
	local find = ImprovedForever and ImprovedForever.GlyphAtlas
	if not find then return end
	for _, side in ipairs({ "left", "right" }) do
		for _, t in ipairs(tiles[side]) do
			local ok, atlas = pcall(find, t.key)
			if ok and atlas then
				t.glyph:SetAtlas(atlas)
				t.glyph:SetSize(GLYPH, GLYPH)          -- (SetAtlas takes the atlas's own, small, size)
			end
		end
	end
end

local function Tile(size)
	local t = CreateFrame("Frame", nil, strip, "BackdropTemplate")
	t:SetSize(size, size)
	t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	t:SetBackdropColor(0, 0, 0, 0.55)
	t:SetBackdropBorderColor(0, 0, 0, 1)
	t.icon = t:CreateTexture(nil, "ARTWORK")
	t.icon:SetPoint("TOPLEFT", 1, -1)
	t.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	t.icon:SetTexCoord(unpack(ICON_CROP))
	t.cooldown = CreateFrame("Cooldown", nil, t, "CooldownFrameTemplate")
	t.cooldown:SetAllPoints(t.icon)
	t.cooldown:SetDrawEdge(false)
	t.cooldown:SetHideCountdownNumbers(false)
	-- (lit: toggled on, casting from it; a proc: gold)
	t.lit = t:CreateTexture(nil, "OVERLAY")
	t.lit:SetAllPoints(t.icon)
	t.lit:SetColorTexture(1, 1, 1, 1)
	t.lit:SetBlendMode("ADD")
	t.lit:SetAlpha(0)
	t.edge = CreateFrame("Frame", nil, t, "BackdropTemplate")
	t.edge:SetPoint("TOPLEFT", -1, 1)
	t.edge:SetPoint("BOTTOMRIGHT", 1, -1)
	t.edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
	t.edge:SetBackdropBorderColor(1, 0.82, 0.2, 1)
	t.edge:SetFrameLevel(t.cooldown:GetFrameLevel() + 2)
	t.edge:Hide()
	t.count = t.edge:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	t.count:SetParent(t)
	t.count:SetPoint("BOTTOMRIGHT", -2, 2)
	return t
end

for _, side in ipairs({ "left", "right" }) do
	for slot = 1, 4 do
		local t = Tile(TILE)
		t.native = ORDER[slot]
		t.glyph = Glyph(strip)
		t.key = KEYS[side][ORDER[slot]]
		t.glyph:SetPoint("TOP", t, "BOTTOM", 0, -GLYPH_GAP)
		tiles[side][slot] = t
	end
end
local class = { left = Tile(CLASS), right = Tile(CLASS) }

-- the round (AishCore's look: a dark disc, its ring an arc; here your health's, full round)
local round = CreateFrame("Frame", nil, strip)
round:SetSize(ROUND, ROUND)
round:SetPoint("CENTER", strip, "CENTER", 0, 0)
local CIRCLE = "Interface\\AddOns\\AishCore\\Media\\Wheel\\circleflat2.tga"
local HOLE = "Interface\\AddOns\\AishCore\\Media\\UI\\CircleHoleMask.tga"
round.disc = round:CreateTexture(nil, "BACKGROUND")
round.disc:SetAllPoints()
round.disc:SetTexture(CIRCLE)
round.disc:SetVertexColor(0, 0, 0, 0.65)
round.ring = CreateFrame("StatusBar", nil, round)
round.ring:SetAllPoints()
round.ring:SetStatusBarTexture(CIRCLE)
round.ring:SetStatusBarColor(0.2, 0.85, 0.3, 1)
if round.ring.SetRenderMode and Enum.StatusBarRenderMode and Enum.StatusBarRenderMode.Radial then
	round.ring:SetRenderMode(Enum.StatusBarRenderMode.Radial)
end
round.hole = round.ring:CreateMaskTexture()
round.hole:SetTexture(HOLE, "CLAMPTOWHITE", "CLAMPTOWHITE")
round.hole:SetPoint("CENTER")
round.hole:SetSize(ROUND * 0.7, ROUND * 0.7)      -- (the ring's hole: AishCore's arc is 0.32 of its width thick)
round.ring:GetStatusBarTexture():AddMaskTexture(round.hole)
round.text = round:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
round.text:SetPoint("CENTER")

local pips = {}
for i = 1, 4 do
	local p = strip:CreateTexture(nil, "OVERLAY")
	p:SetTexture(CIRCLE)
	p:SetSize(PIP, PIP)
	pips[i] = p
end

local function Layout()
	local mode = Mode()
	local room = mode == "round" and ROUND_ROOM or PLAIN_ROOM
	local group = 4 * TILE + 3 * GAP
	for i, t in ipairs(tiles.left) do
		t:ClearAllPoints()
		t:SetPoint("RIGHT", strip, "CENTER", -room / 2 - (4 - i) * (TILE + GAP), 0)
	end
	for i, t in ipairs(tiles.right) do
		t:ClearAllPoints()
		t:SetPoint("LEFT", strip, "CENTER", room / 2 + (i - 1) * (TILE + GAP), 0)
	end
	class.left:ClearAllPoints()
	class.left:SetPoint("BOTTOMLEFT", tiles.left[1], "TOPLEFT", 0, M)
	class.right:ClearAllPoints()
	class.right:SetPoint("BOTTOMRIGHT", tiles.right[4], "TOPRIGHT", 0, M)
	round:SetShown(mode == "round")
	for i, p in ipairs(pips) do
		p:ClearAllPoints()
		p:SetPoint("CENTER", strip, "CENTER", (i - 2.5) * (PIP + 5), -TILE / 2 - GLYPH_GAP - GLYPH / 2)
	end
	strip.width = 2 * group + room
end

------------------------------------------------------------------ mirroring the game's buttons
local function Mirror(t, native)
	local shown = native and native:IsShown()
	local icon = shown and native.icon
	local texture = icon and icon:IsShown() and icon:GetTexture()
	local special = shown and native.SpecialActionIcon
	if special and special:IsShown() then
		local atlas = special.GetAtlas and special:GetAtlas()
		if Secret(atlas) or (type(atlas) == "string" and atlas ~= "") then
			t.icon:SetAtlas(atlas)
			texture = true
		else
			texture = special:GetTexture()
		end
	end
	if not texture then
		t.icon:SetTexture(nil)
		t.count:SetText("")
		t.cooldown:Clear()
		t.lit:SetAlpha(0)
		t.edge:Hide()
		t.cdKey = nil
		return
	end
	if texture ~= true then
		t.icon:SetTexture(texture)
		t.icon:SetTexCoord(unpack(ICON_CROP))
	end
	-- the game's tint (unusable: grey; out of mana: blue; out of range: red)
	if icon then
		pcall(function()
			t.icon:SetVertexColor(icon:GetVertexColor())
			t.icon:SetDesaturated(icon:IsDesaturated())
		end)
	end
	-- its cooldown: its action's, from the game (secret in a fight at times: handed on as it is)
	local action = native.action
	if action then
		local start, duration
		if C_ActionBar and C_ActionBar.GetActionCooldown then
			local ok, info = pcall(C_ActionBar.GetActionCooldown, action)
			if ok and type(info) == "table" then start, duration = info.startTime, info.duration end
		elseif GetActionCooldown then
			local ok, s, d = pcall(GetActionCooldown, action)
			if ok then start, duration = s, d end
		end
		if Secret(start) or Secret(duration) then
			pcall(t.cooldown.SetCooldown, t.cooldown, start, duration)
			t.cdKey = nil
		elseif type(start) == "number" and type(duration) == "number" and duration > 1.5 then
			local key = start .. ":" .. duration
			if t.cdKey ~= key then t.cdKey = key t.cooldown:SetCooldown(start, duration) end
		elseif t.cdKey then
			t.cdKey = nil
			t.cooldown:Clear()
		end
	end
	local count = native.Count
	pcall(function() t.count:SetText(count and count:IsShown() and count:GetText() or "") end)
	local checked = native.GetChecked and native:GetChecked()
	if not pcall(t.lit.SetAlphaFromBoolean, t.lit, checked, 0.25, 0) then t.lit:SetAlpha(0) end
	local alert = native.SpellActivationAlert
	t.edge:SetShown(alert and alert:IsShown() or false)
	local ok, pressed = pcall(function() return native:GetButtonState() == "PUSHED" end)
	t:SetBackdropBorderColor(ok and pressed and 1 or 0, ok and pressed and 0.82 or 0, ok and pressed and 0.2 or 0, 1)
end

local function Pips(pu, bar)
	local bars = pu.actionBars or {}
	local pages = { bars.topBar, bars.leftBar, bars.rightBar, bars.bottomBar }
	for i, p in ipairs(pips) do
		local on = bar ~= nil and pages[i] == bar
		p:SetVertexColor(on and 1 or 0.5, on and 0.82 or 0.5, on and 0.2 or 0.5, on and 1 or 0.6)
		p:SetSize(on and PIP + 2 or PIP, on and PIP + 2 or PIP)
	end
end

local function Health()
	local ok = pcall(function()
		round.ring:SetMinMaxValues(0, UnitHealthMax("player"))
		round.ring:SetValue(UnitHealth("player"))
	end)
	if not ok then round.ring:SetMinMaxValues(0, 1) round.ring:SetValue(1) end
	-- (the percentage: secret in a fight at times; the game's own percent, handed to the text as it is)
	local okText = UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 and pcall(function()
		round.text:SetFormattedText("%.0f%%", UnitHealthPercent("player", true, CurveConstants.ScaleTo100))
	end)
	if not okText then
		okText = pcall(function()
			local max = UnitHealthMax("player")
			round.text:SetFormattedText("%d%%", max > 0 and math.floor(UnitHealth("player") / max * 100 + 0.5) or 0)
		end)
	end
	if not okText then round.text:SetText("") end
end

-- the strip's alpha: the game's bar's, as CalmDriver gives it (in a fight full; out of one, its awake level)
local function Level()
	if strip.previewUntil and GetTime() < strip.previewUntil then return 1 end    -- (just switched: seen a moment)
	if InCombatLockdown() or UnitAffectingCombat("player") then return 1 end
	local driver = _G.DeckForeverCalmDriver
	return driver and tonumber(driver:GetAttribute("state-awake")) or 0
end

local tick = 0
strip:SetScript("OnUpdate", function(_, elapsed)
	tick = tick + elapsed
	if tick < 0.03 then return end
	tick = 0
	strip:SetAlpha(Level())
	local pu = PageUnit()
	local bar = pu and pu.activeBar
	for _, side in ipairs({ "left", "right" }) do
		local cluster = bar and (side == "left" and bar.Left or bar.Right)
		for _, t in ipairs(tiles[side]) do
			Mirror(t, cluster and cluster["ActionButton" .. t.native])
		end
		local native = pu and (side == "left" and pu.LeftClassAction or pu.RightClassAction)
		local on = native ~= nil and native:IsShown()
		class[side]:SetShown(on)
		if on then Mirror(class[side], native) end
	end
	if pu then Pips(pu, bar) end
	if round:IsShown() then Health() end
end)

------------------------------------------------------------------ on / off
-- The game's bar hidden (CalmDriver's "skillBar"), ours shown; out of combat only (a secure attribute)
local function Apply()
	local mode = Mode()
	local driver = _G.DeckForeverCalmDriver
	if InCombatLockdown() then strip.pending = true return end
	strip.pending = nil
	if driver then
		driver:SetAttribute("skillBar", mode ~= nil)
		if driver.Execute then driver:Execute([[ self:RunAttribute("apply") ]]) end
	end
	Layout()
	SetGlyphs()
	strip:SetShown(mode ~= nil)
end
ns.ApplySkillBar = Apply

local NEXT = { [""] = "round", round = "gap", gap = "off", off = "round" }
function ns.CycleSkillBar()
	DeckForeverDB = DeckForeverDB or {}
	DeckForeverDB.skillBar = NEXT[DeckForeverDB.skillBar or ""] or "round"
	strip.previewUntil = GetTime() + 6
	Apply()
	print(("DeckForever : barre horizontale %s."):format(({ round = "avec le rond", gap = "avec un espace",
		off = "désactivée" })[DeckForeverDB.skillBar]))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" and not strip.pending then return end
	-- (a frame later: CalmDriver is set up at the world's entry too)
	C_Timer.After(0.5, Apply)
end)
