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
-- Read a few dozen times a second: only getters on the game's frames, nothing set, nothing hooked. Its other parts
-- too (LB / RB's targeting marks, the class actions' prompts, its dark ground), and Easy Controller's L3 / R3 beside
-- the strip's ends.
-- Shown as the game's bar would be (CalmDriver's state: full in a fight, out of one only while woken).
-- /df skill: off -> round -> gap -> off (DeckForeverDB.skillBar).
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
-- What's shown round the two groups (DeckForeverDB.skillShow, the options panel: Options.lua): every part
-- on unless turned off. Hidden, it's only our picture that goes: the game's buttons and Easy Controller's
-- still take their presses.
ns.SKILL_PARTS = {
	{ key = "shoulders", label = "Marques de ciblage LB / RB" },
	{ key = "class", label = "Actions de classe" },
	{ key = "prompts", label = "Glyphes des actions de classe" },
	{ key = "sticks", label = "L3 / R3 (Easy Controller)" },
	{ key = "extras", label = "Palettes et pavé tactile (Easy Controller)" },
	{ key = "pips", label = "Repères de page (LT / RT)" },
	{ key = "recent", label = "Dernière action de roue (Improved Forever)" },
	{ key = "ground", label = "Fond sombre" },
}
-- (off unless turned on: the wheel slot, whose "R3 twice" doesn't reach it on the Deck)
local OFF_BY_DEFAULT = { recent = true }
local function Show(key)
	local show = DeckForeverDB and DeckForeverDB.skillShow
	if OFF_BY_DEFAULT[key] then return show and show[key] == true or false end
	return not (show and show[key] == false)
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

-- Two looks (DeckForeverDB.skillStyle, /df style): "flat" (a dark square, a thin edge) or "blizzard" (the
-- game's own gamepad bar slots: its square slot for the d-pad, its round one for the face buttons and the
-- class actions; background, border, pressed border, the icon cut by the slot's mask, as Improved Forever
-- draws its pad from them)
local SLOT_BORDER = 64 / 46 / 1.2       -- (the slot's border art round its visible side: Improved Forever's
                                        -- sizes, its tile's visible side 1.2 of its size)
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local Canvas
local function Tile(size, shape)
	local t = CreateFrame("Frame", nil, strip, "BackdropTemplate")
	t:SetSize(size, size)
	t.shape = shape                     -- ("square" or "circle": its slot in the game's look)
	t.slotBg = t:CreateTexture(nil, "BACKGROUND")
	t.slotBg:SetPoint("CENTER")
	t.slotBg:SetSize(size, size)
	t.icon = t:CreateTexture(nil, "ARTWORK")
	-- (behind one of the game's symbols, dark on the dark slot: a soft light, so it reads)
	t.halo = t:CreateTexture(nil, "ARTWORK", nil, -1)
	t.halo:SetPoint("CENTER")
	t.halo:SetTexture(ROUND_MASK)
	t.halo:SetVertexColor(0.85, 0.8, 0.7, 0.55)
	t.halo:Hide()
	t.mask = t:CreateMaskTexture()
	t.mask:SetPoint("CENTER")
	t.mask:SetSize(size * 0.94, size * 0.94)
	t.cooldown = CreateFrame("Cooldown", nil, t, "CooldownFrameTemplate")
	t.cooldown:SetDrawEdge(false)
	t.cooldown:SetHideCountdownNumbers(false)
	-- (lit: toggled on, casting from it)
	t.lit = t:CreateTexture(nil, "ARTWORK", nil, 2)
	t.lit:SetColorTexture(1, 0.85, 0.4, 1)
	t.lit:SetBlendMode("ADD")
	t.lit:SetAlpha(0)
	local over = CreateFrame("Frame", nil, t)
	over:SetAllPoints()
	over:SetFrameLevel(t.cooldown:GetFrameLevel() + 2)
	t.slotBorder = over:CreateTexture(nil, "OVERLAY")
	t.slotBorder:SetPoint("CENTER")
	t.slotBorder:SetSize(size * SLOT_BORDER, size * SLOT_BORDER)
	-- (a proc: a gold edge (flat), the slot's selected border (blizzard))
	t.edge = CreateFrame("Frame", nil, t, "BackdropTemplate")
	t.edge:SetPoint("TOPLEFT", -1, 1)
	t.edge:SetPoint("BOTTOMRIGHT", 1, -1)
	t.edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
	t.edge:SetBackdropBorderColor(1, 0.82, 0.2, 1)
	t.edge:SetFrameLevel(over:GetFrameLevel() + 1)
	t.edge:Hide()
	t.count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	t.count:SetPoint("BOTTOMRIGHT", -2, 2)
	Canvas(t)
	return t
end
-- (the game's look: copies of a game's frame's layers, at its scale; Clone)
function Canvas(t)
	t.canvas = CreateFrame("Frame", nil, t)
	t.canvas:SetSize(1, 1)
	t.canvas:SetPoint("CENTER")
	t.canvas:Hide()
	t.ccd = CreateFrame("Cooldown", nil, t.canvas, "CooldownFrameTemplate")
	t.ccd:SetPoint("CENTER")
	t.ccd:SetDrawEdge(false)
	t.ccd:SetSwipeColor(0, 0, 0, 0.7)
	t.canvasTop = CreateFrame("Frame", nil, t)
	t.canvasTop:SetSize(1, 1)
	t.canvasTop:SetPoint("CENTER")
	t.canvasTop:SetFrameLevel(t.ccd:GetFrameLevel() + 3)
	t.canvasTop:Hide()
	t.clones, t.masks = {}, {}
end

local function Blizzard() return DeckForeverDB and DeckForeverDB.skillStyle == "blizzard" end

-- A tile in the look in use
local function Restyle(t)
	local size = t:GetWidth()
	if Blizzard() then
		-- (the game's look: all drawn by the copies, Clone; ours hidden)
		t.atlas = nil
		t:SetBackdrop(nil)
		for _, part in ipairs({ t.slotBg, t.slotBorder, t.icon, t.halo, t.lit, t.count }) do part:Hide() end
		t.edge:Hide()
		t.cooldown:Clear()
		t.cooldown:Hide()
		if t.glyph then t.glyph:Hide() end
		t.pressedLook, t.iconSymbol, t.mirrored, t.nativeNow, t.seen = nil, nil, nil, nil, nil
		return
	else
		t.canvas:Hide()
		t.canvasTop:Hide()
		for _, part in ipairs({ t.icon, t.lit, t.count }) do part:Show() end
		t.cooldown:Show()
		if t.glyph then t.glyph:Show() end
		t.atlas = nil
		t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		t:SetBackdropColor(0, 0, 0, 0.55)
		t:SetBackdropBorderColor(0, 0, 0, 1)
		t.slotBg:Hide()
		t.slotBorder:Hide()
		if t.masked then t.icon:RemoveMaskTexture(t.mask) t.lit:RemoveMaskTexture(t.mask) t.masked = nil end
		t.icon:ClearAllPoints()
		t.icon:SetPoint("TOPLEFT", 1, -1)
		t.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		t.cooldown:ClearAllPoints()
		t.cooldown:SetAllPoints(t.icon)
		t.cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8x8")
		if t.cooldown.SetUseCircularEdge then t.cooldown:SetUseCircularEdge(false) end
		t.cooldown:SetSwipeColor(0, 0, 0, 0.7)
	end
	t.lit:ClearAllPoints()
	t.lit:SetAllPoints(t.icon)
	t.pressedLook, t.iconSymbol = nil, nil
end

-- pressed and proc shown in the look in use
local function Pressed(t, pressed, proc)
	if t.atlas then
		local want = pressed and t.atlas.pressed or proc and t.atlas.proc or t.atlas.normal
		if t.pressedLook ~= want then t.pressedLook = want t.slotBorder:SetAtlas(want) end
		t.edge:Hide()
	else
		t:SetBackdropBorderColor(pressed and 1 or 0, pressed and 0.82 or 0, pressed and 0.2 or 0, 1)
		t.edge:SetShown(proc)
	end
end

for _, side in ipairs({ "left", "right" }) do
	for slot = 1, 4 do
		local t = Tile(TILE, side == "left" and "square" or "circle")
		t.native = ORDER[slot]
		t.glyph = Glyph(strip)
		t.key = KEYS[side][ORDER[slot]]
		t.glyph:SetPoint("TOP", t, "BOTTOM", 0, -GLYPH_GAP)
		tiles[side][slot] = t
	end
end
local class = { left = Tile(CLASS, "circle"), right = Tile(CLASS, "circle") }

-- The game's bar's other parts, copied as they are (the game's look in either style):
-- * the class actions' glyph prompts (L1 + L2, RB + RT...), over their tile
local prompts = {}
for _, side in ipairs({ "left", "right" }) do
	local f = CreateFrame("Frame", nil, strip)
	f:SetSize(1, 1)
	Canvas(f)
	f.deep = true
	prompts[side] = f
end
-- * LB / RB's ally / enemy targeting marks (their background, icon, pressed light), over the strip's ends
local SHOULDERS = {
	left = { "LeftShoulderBackground", "LeftShoulderIcon", "LeftShoulderHighlight" },
	right = { "RightShoulderBackground", "RightShoulderIcon", "RightShoulderHighlight" },
}
local shoulders = {}
for _, side in ipairs({ "left", "right" }) do
	local f = CreateFrame("Frame", nil, strip)
	f:SetSize(1, 1)
	f.layers = {}
	for i, key in ipairs(SHOULDERS[side]) do
		f.layers[i] = f:CreateTexture(nil, "ARTWORK", nil, i)
		f.layers[i]:SetPoint("CENTER")
		f.layers[i].key = key
	end
	shoulders[side] = f
end
-- * the soft dark ground behind the buttons (the active bar's BackgroundFocus), the strip's width
local ground = strip:CreateTexture(nil, "BACKGROUND", nil, -8)
ground:SetPoint("CENTER")

-- One of the game's textures, copied onto ours (shown, art, size times k, colour)
local function CopyTexture(o, r, k, w, h)
	if not (r and r:IsVisible()) then o:Hide() return end
	o:Show()
	local atlas = r:GetAtlas()
	if atlas then
		if o.art ~= atlas then o.art = atlas o:SetAtlas(atlas) end
	else
		local file = r:GetTexture()
		if o.art ~= file then o.art = file o:SetTexture(file) end
		o:SetTexCoord(r:GetTexCoord())
	end
	local rw, rh = r:GetSize()
	o:SetSize((w or rw) * k, (h or rh) * k)
	o:SetVertexColor(r:GetVertexColor())
	o:SetAlpha(r:GetAlpha())
	o:SetBlendMode(r:GetBlendMode())
end

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
	-- (the class actions over the middle, as the game has them between its two groups; their prompts over them)
	local both = class.left:IsShown() and class.right:IsShown()
	for side, sign in pairs({ left = -1, right = 1 }) do
		local x = both and sign * (CLASS / 2 + 6) or 0
		class[side]:ClearAllPoints()
		class[side]:SetPoint("CENTER", strip, "CENTER", x, TILE / 2 + CLASS / 2 + 14)
		prompts[side]:ClearAllPoints()
		prompts[side]:SetPoint("CENTER", class[side], "CENTER", 0, CLASS / 2 + 12)
	end
	shoulders.left:ClearAllPoints()
	shoulders.left:SetPoint("CENTER", tiles.left[1], "CENTER", 0, TILE / 2 + 26)
	shoulders.right:ClearAllPoints()
	shoulders.right:SetPoint("CENTER", tiles.right[4], "CENTER", 0, TILE / 2 + 26)
	strip.both = both
	round:SetShown(mode == "round")
	for i, p in ipairs(pips) do
		p:ClearAllPoints()
		p:SetPoint("CENTER", strip, "CENTER", (i - 2.5) * (PIP + 5), -TILE / 2 - GLYPH_GAP - GLYPH / 2)
	end
	strip.width = 2 * group + room
end

------------------------------------------------------------------ mirroring the game's buttons
-- The interact button (the top bar's face cluster's first, X): the game draws on it the cursor of what you'd
-- interact with (SetUnitCursorTexture: a herb's, an NPC's), a picture it can't hand on; ours draws the same,
-- for the unit the game's would (Improved Forever's way: the soft interact target in reach, else the target)
local function InteractButton()
	local pu = PageUnit()
	local top = pu and pu.actionBars and pu.actionBars.topBar
	return top and top.Right and top.Right.ActionButton1
end
local function Yes(fn, unit)
	if not fn then return false end
	local ok, v = pcall(fn, unit)
	return ok and not Secret(v) and v and true or false
end
local function CursorUnit()
	if (Yes(UnitExists, "softinteract") or Yes(UnitIsGameObject, "softinteract")) then
		if Yes(UnitIsInInteractRange, "softinteract") then return "softinteract" end
	end
	if Yes(UnitExists, "target") and Yes(UnitIsInteractable, "target") then return "target" end
end
local INTERACT = "Interface\\Cursor\\Interact"     -- (nothing in reach: the game's interact cursor, dimmed)

-- The icon as a spell's or item's (cropped, the tile's size) or as one of the game's symbols (the face
-- buttons' own: a magnifier, a jump; a cursor): upright, smaller, its own colour
local function IconAs(t, symbol)
	if t.iconSymbol == symbol then return end
	t.iconSymbol = symbol
	t.halo:SetSize(t:GetWidth() * 0.78, t:GetWidth() * 0.78)
	t.halo:SetShown(symbol and true or false)
	if not t.atlas then return end              -- (flat: the icon fills the tile either way)
	local size = t:GetWidth() * (symbol and 0.62 or 0.94)
	t.icon:SetSize(size, size)
end

------------------------------------------------------------------ the game's look, copied (style "blizzard")
-- A tile in the game's look is a copy of the button it mirrors, layer by layer: every texture of the game's
-- button (its shadow, its slot art with the button's symbol in it while empty, its icon and the mask that
-- cuts it, its normal / pushed / checked borders, its flash, the small glyph in its corner), its count, read
-- as they are each time (shown, atlas or file, size, place from the button's centre, layer, colour, blend),
-- drawn on a canvas at the game's button's scale: the same picture, whatever state the game puts it in.
-- Its cooldown: ours, the game's size, swept in the slot's shape. Left out: the mouse's highlights.
local CLONE_SKIP = { HighlightTexture = true, QuickKeybindHighlightTexture = true, NewActionTexture = true,
	LevelLinkLockIcon = true, Arrow = true, BorderShadow = true }
local parts = setmetatable({}, { __mode = "k" })
local function Parts(native, deep)
	local list = parts[native]
	if list then return list end
	list = {}
	local function take(frame, prefix, top)
		for i, r in ipairs({ frame:GetRegions() }) do
			local kind = r:GetObjectType()
			local key = r.GetParentKey and r:GetParentKey()
			if (kind == "Texture" or kind == "FontString") and not CLONE_SKIP[key or ""] then
				list[#list + 1] = { region = r, id = prefix .. (key or ("#" .. i)), kind = kind, top = top }
			end
		end
		-- (a whole frame's, as a glyph prompt's: its children's too)
		if deep then
			for i, c in ipairs({ frame:GetChildren() }) do
				take(c, prefix .. ((c.GetParentKey and c:GetParentKey()) or ("#" .. i)) .. ".", top)
			end
		end
	end
	take(native, "", false)
	-- (the corner glyph and the count stand over the cooldown, as the game's do)
	if native.ButtonIcon then take(native.ButtonIcon, "ButtonIcon.", true) end
	if native.TextOverlayContainer then take(native.TextOverlayContainer, "Text.", true) end
	parts[native] = list
	return list
end

local function CloneOf(t, part)
	local o = t.clones[part.id]
	if o then return o end
	local layer, sub = part.region:GetDrawLayer()
	local host = part.top and t.canvasTop or t.canvas
	if part.kind == "FontString" then
		o = host:CreateFontString(nil, layer)
	else
		o = host:CreateTexture(nil, layer, nil, sub)
	end
	t.clones[part.id] = o
	return o
end

-- the mask the game's region shows with (its visible one), ours of the same art and size
local function MaskOf(t, r)
	if not r.GetNumMaskTextures then return nil end
	for i = 1, r:GetNumMaskTextures() do
		local m = r:GetMaskTexture(i)
		local w = m and m:GetWidth()
		if m and m:IsShown() and w and w > 0 then
			local art = m:GetAtlas() or m:GetTexture()
			local key = tostring(art)
			local ours = t.masks[key]
			if not ours then
				ours = t.canvas:CreateMaskTexture()
				if m:GetAtlas() then ours:SetAtlas(m:GetAtlas()) else ours:SetTexture(m:GetTexture(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
				t.masks[key] = ours
			end
			return ours, m, key
		end
	end
end

local function SyncPart(t, part, nx, ny)
	local r = part.region
	local o = CloneOf(t, part)
	if not r:IsVisible() then
		if o:IsShown() then o:Hide() end
		return
	end
	o:Show()
	local cx, cy = r:GetCenter()
	local w, h = r:GetSize()
	local place = cx and ("%.1f:%.1f:%.1f:%.1f"):format(cx - nx, cy - ny, w, h) or "c"
	if o.place ~= place then
		o.place = place
		o:ClearAllPoints()
		o:SetPoint("CENTER", t.canvas, "CENTER", cx and cx - nx or 0, cy and cy - ny or 0)
		o:SetSize(w, h)
	end
	if part.kind == "FontString" then
		o:SetFont(r:GetFont())
		o:SetTextColor(r:GetTextColor())
		o:SetShadowOffset(r:GetShadowOffset())
		o:SetText(r:GetText())
		return
	end
	local atlas = r:GetAtlas()
	if atlas then
		if o.art ~= atlas then o.art = atlas o:SetAtlas(atlas) o:SetSize(w, h) end
	else
		local file = r:GetTexture()
		if o.art ~= file then o.art = file o:SetTexture(file) end
		o:SetTexCoord(r:GetTexCoord())
	end
	o:SetVertexColor(r:GetVertexColor())
	o:SetAlpha(r:GetAlpha())
	o:SetBlendMode(r:GetBlendMode())
	o:SetDesaturated(r:IsDesaturated())
	if r.GetRotation then o:SetRotation(r:GetRotation()) end
	-- its mask
	local mask, theirs, key = MaskOf(t, r)
	if o.maskKey ~= key then
		if o.mask then o:RemoveMaskTexture(o.mask) end
		o.mask, o.maskKey = mask, key
		if mask then o:AddMaskTexture(mask) end
	end
	if mask then
		local mx, my = theirs:GetCenter()
		mask:ClearAllPoints()
		mask:SetPoint("CENTER", t.canvas, "CENTER", mx and mx - nx or 0, my and my - ny or 0)
		mask:SetSize(theirs:GetSize())
		if part.id == "icon" or part.id == "SpecialActionIcon" then t.round = key:find("Circle") ~= nil end
	end
end

local function CooldownOf(cd, t, native)
	local action = native.action
	if not action then return end
	local start, duration
	if C_ActionBar and C_ActionBar.GetActionCooldown then
		local ok, info = pcall(C_ActionBar.GetActionCooldown, action)
		if ok and type(info) == "table" then start, duration = info.startTime, info.duration end
	elseif GetActionCooldown then
		local ok, s, d = pcall(GetActionCooldown, action)
		if ok then start, duration = s, d end
	end
	if Secret(start) or Secret(duration) then
		pcall(cd.SetCooldown, cd, start, duration)
		t.cdKey = nil
	elseif type(start) == "number" and type(duration) == "number" and duration > 1.5 then
		local key = start .. ":" .. duration
		if t.cdKey ~= key then t.cdKey = key cd:SetCooldown(start, duration) end
	elseif t.cdKey then
		t.cdKey = nil
		cd:Clear()
	end
end

local function Clone(t, native)
	local shown = native and native:IsShown()
	t.canvas:SetShown(shown and true or false)
	t.canvasTop:SetShown(shown and true or false)
	if not shown then return end
	if t.mirrored ~= native then
		-- (another button: every copy laid out again)
		t.mirrored, t.nativeNow = native, native
		for _, o in pairs(t.clones) do o:Hide() o.place, o.art = nil, nil end
		t.cdKey = nil
		t.ccd:Clear()
	end
	local k = native:GetEffectiveScale() / t:GetEffectiveScale()
	if math.abs(t.canvas:GetScale() - k) > 0.001 then t.canvas:SetScale(k) t.canvasTop:SetScale(k) end
	local nx, ny = native:GetCenter()
	if not nx then return end
	for _, part in ipairs(Parts(native, t.deep)) do pcall(SyncPart, t, part, nx, ny) end
	-- (ours drawn for the game's: the copies it made for the button ours mirrored before, hidden)
	if t.nativeNow ~= t.seen then
		t.seen = t.nativeNow
		local live = {}
		for _, part in ipairs(Parts(native, t.deep)) do live[part.id] = true end
		for id, o in pairs(t.clones) do if not live[id] then o:Hide() end end
	end
	local cd = native.cooldown
	if cd then
		local w, h = cd:GetSize()
		t.ccd:SetSize(w, h)
		local shape = t.round and "round" or "square"
		if t.ccdShape ~= shape then
			t.ccdShape = shape
			t.ccd:SetSwipeTexture(t.round and ROUND_MASK or "Interface\\Buttons\\WHITE8x8")
			if t.ccd.SetUseCircularEdge then t.ccd:SetUseCircularEdge(t.round) end
		end
	end
	CooldownOf(t.ccd, t, native)
end

local function Mirror(t, native)
	if Blizzard() then Clone(t, native) t.mirrored = native return end
	local shown = native and native:IsShown()
	local icon = shown and native.icon
	local texture = icon and icon:IsShown() and icon:GetTexture()
	local symbol
	local special = shown and native.SpecialActionIcon
	if special and special:IsShown() then
		local atlas = special.GetAtlas and special:GetAtlas()
		if Secret(atlas) or (type(atlas) == "string" and atlas ~= "") then
			t.icon:SetAtlas(atlas)
			texture = true
		else
			texture = special:GetTexture()
			if texture then t.icon:SetTexture(texture) t.icon:SetTexCoord(special:GetTexCoord()) texture = true end
		end
		symbol, icon = true, special
	end
	if shown and native == InteractButton() then
		local unit = CursorUnit()
		local ok, drawn = unit and pcall(SetUnitCursorTexture, t.icon, unit, nil, nil, false)
		if ok and drawn and not Secret(drawn) then
			t.icon:SetTexCoord(0, 1, 0, 1)
			texture, symbol, icon = true, true, nil
			t.icon:SetVertexColor(1, 1, 1)
			t.icon:SetDesaturated(false)
		elseif not texture then
			t.icon:SetTexture(INTERACT)
			t.icon:SetTexCoord(0, 1, 0, 1)
			t.icon:SetVertexColor(0.7, 0.7, 0.7)
			texture, symbol, icon = true, true, nil
		end
	end
	if not texture then
		t.icon:SetTexture(nil)
		IconAs(t, nil)
		t.count:SetText("")
		t.cooldown:Clear()
		t.lit:SetAlpha(0)
		Pressed(t, false, false)
		t.cdKey = nil
		return
	end
	IconAs(t, symbol)
	if texture ~= true then
		t.icon:SetTexture(texture)
		t.icon:SetTexCoord(unpack(ICON_CROP))
	end
	-- the game's tint (unusable: grey; out of mana: blue; out of range: red); a symbol's, its own
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
	local ok, pressed = pcall(function() return native:GetButtonState() == "PUSHED" end)
	Pressed(t, ok and pressed or false, alert and alert:IsShown() or false)
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
	if DeckForeverDB and DeckForeverDB.skillDev then return 1 end                  -- (dev mode: always shown)
	if InCombatLockdown() or UnitAffectingCombat("player") then return 1 end
	local driver = _G.DeckForeverCalmDriver
	return driver and tonumber(driver:GetAttribute("state-awake")) or 0
end

------------------------------------------------------------------ Easy Controller's extra buttons
-- L3 / R3 and its paddles' and touchpad's buttons with something on them, which it draws round the game's bar
-- (its Paddles.lua: plain frames, at the bar's alpha): beside the strip's two ends while it's on, at the
-- strip's alpha (set right after its own, in the same frame: no flicker), each side's outwards in its order.
-- Put back where Easy Controller places them once the strip is off; left alone while being placed in its options.
local EC_SIDES = { left = { "L3", "L4", "L5", "TL1", "TL2", "TL3", "TL4" },
	right = { "R3", "R4", "R5", "TR1", "TR2", "TR3", "TR4" } }
local PlaceRecent
local STICK = { L3 = true, R3 = true }
-- Improved Forever's wheel slot (its Wheel module's RecentSlot: the last action used from the R3 combo's wheel
-- held, shown while that combo's trigger is held): it stands beside the game's bar, hidden under ours. Put
-- beside the strip's left end (L3's place, which isn't shown), at the strip's alpha. Improved Forever sets its
-- place again only when its own choice changes (it remembers it): ours stays. Hidden if turned off.
local recentHooked
PlaceRecent = function()
	local slot = _G.ImprovedForeverRecentSlot
	if not slot or slot.editing then return end
	-- (off: hidden as it shows, with the strip or without; a plain frame of Improved Forever's)
	if not recentHooked then
		recentHooked = true
		slot:HookScript("OnShow", function(self) if not Show("recent") and not self.editing then self:Hide() end end)
		if not Show("recent") then slot:Hide() end
	end
	if not Show("recent") then slot:Hide() return end
	local ratio = strip:GetEffectiveScale() / slot:GetEffectiveScale()
	local _, relative, _, x = slot:GetPoint(1)
	local want = -(TILE + GAP + 6) * ratio
	if relative ~= tiles.left[1] or not x or math.abs(x - want) > 0.5 then
		slot:ClearAllPoints()
		slot:SetPoint("CENTER", tiles.left[1], "CENTER", want, 0)
	end
	slot:SetAlpha(strip:GetAlpha())
end
local ecHooked, ecMoved
local function PlaceExtras()
	local P = rawget(_G, "ControllerKeyboard") and ControllerKeyboard.Paddles
	local f = P and P.frame
	if not (f and f.buttons) then return end
	if not ecHooked then
		ecHooked = true
		f:HookScript("OnUpdate", function()
			if not strip:IsShown() or P.placing then return end
			f:SetAlpha(strip:GetAlpha())
			-- (those turned off in our options: not drawn, the input still theirs; right after Easy
			-- Controller's own Refresh, which shows them again)
			for _, ids in pairs(EC_SIDES) do
				for _, id in ipairs(ids) do
					local b = f.buttons[id]
					-- (and one showing Easy Controller's "Nothing": a no-entry sign, no use on the bar)
					if b and (not Show(STICK[id] and "sticks" or "extras") or b.action == "none:none") then
						b:SetAlpha(0) b:EnableMouse(false)
					end
				end
			end
		end)
	end
	if not strip:IsShown() then
		if ecMoved then ecMoved = nil pcall(P.Layout, P) end
		return
	end
	if P.placing then return end
	ecMoved = true
	PlaceRecent()
	for side, ids in pairs(EC_SIDES) do
		local sign = side == "left" and -1 or 1
		local edge = side == "left" and tiles.left[1] or tiles.right[4]
		local n = 0
		for _, id in ipairs(ids) do
			local b = f.buttons[id]
			if b and b:IsShown() and b:GetAlpha() > 0 and b.action ~= "none:none" and Show(STICK[id] and "sticks" or "extras") then
				n = n + 1
				local ratio = strip:GetEffectiveScale() / b:GetEffectiveScale()
				b:ClearAllPoints()
				b:SetPoint("CENTER", edge, "CENTER", sign * n * (TILE + GAP + 4) * ratio, 0)
			end
		end
	end
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
		local on = native ~= nil and native:IsShown() and Show("class")
		class[side]:SetShown(on)
		if on then Mirror(class[side], native) end
		local prompt = pu and (side == "left" and pu.LeftInputPrompt or pu.RightInputPrompt)
		local promptOn = on and Show("prompts")
		prompts[side]:SetShown(promptOn)
		if promptOn and prompt then Clone(prompts[side], prompt) end
		shoulders[side]:SetShown(Show("shoulders"))
		if Show("shoulders") then
			local k = pu and pu:GetEffectiveScale() / strip:GetEffectiveScale() or 1
			for _, o in ipairs(shoulders[side].layers) do CopyTexture(o, pu and pu[o.key], k) end
		end
	end
	if (class.left:IsShown() and class.right:IsShown()) ~= strip.both then Layout() end
	local focus = Show("ground") and bar and bar.BackgroundFocus
	if focus then
		local k = focus:GetEffectiveScale() / strip:GetEffectiveScale()
		local _, h = focus:GetSize()
		CopyTexture(ground, focus, k, (strip.width + 246) / k, h)
	else
		ground:Hide()
	end
	for _, p in ipairs(pips) do p:SetShown(Show("pips")) end
	if pu then Pips(pu, bar) end
	if round:IsShown() then Health() end
	pcall(PlaceRecent)
	strip.extrasWait = (strip.extrasWait or 0) - 1
	if strip.extrasWait <= 0 then strip.extrasWait = 15 PlaceExtras() end
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
	for _, side in ipairs({ "left", "right" }) do
		for _, t in ipairs(tiles[side]) do Restyle(t) end
		Restyle(class[side])
	end
	Layout()
	SetGlyphs()
	strip:SetShown(mode ~= nil)
	PlaceExtras()
end
ns.ApplySkillBar = Apply
-- (a setting changed in the options: laid out again, seen a moment)
function ns.SkillBarChanged()
	strip.previewUntil = GetTime() + 4
	Apply()
end

local NEXT = { [""] = "round", round = "gap", gap = "off", off = "round" }
function ns.CycleSkillBar()
	DeckForeverDB = DeckForeverDB or {}
	DeckForeverDB.skillBar = NEXT[DeckForeverDB.skillBar or ""] or "round"
	strip.previewUntil = GetTime() + 6
	Apply()
	print(("DeckForever : barre horizontale %s."):format(({ round = "avec le rond", gap = "avec un espace",
		off = "désactivée" })[DeckForeverDB.skillBar]))
end

-- Dev mode: the strip always fully shown (out of a fight too), to look at it without pressing anything
function ns.ToggleSkillDev()
	DeckForeverDB = DeckForeverDB or {}
	DeckForeverDB.skillDev = not DeckForeverDB.skillDev or nil
	print(("DeckForever : barre horizontale, mode dev %s."):format(DeckForeverDB.skillDev and "on" or "off"))
end

function ns.ToggleSkillStyle()
	DeckForeverDB = DeckForeverDB or {}
	DeckForeverDB.skillStyle = Blizzard() and "flat" or "blizzard"
	strip.previewUntil = GetTime() + 6
	Apply()
	print(("DeckForever : barre horizontale, style %s."):format(Blizzard() and "Blizzard (carrés, ronds)" or "plat"))
end

-- (the wheel slot hidden from the login, the strip on or not)
local recentWatch = CreateFrame("Frame")
recentWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
recentWatch:SetScript("OnEvent", function() C_Timer.After(1, function() pcall(PlaceRecent) end) end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" and not strip.pending then return end
	-- (a frame later: CalmDriver is set up at the world's entry too)
	C_Timer.After(0.5, Apply)
end)
