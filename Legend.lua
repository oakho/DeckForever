--------------------------------------------------------------------------------
-- The gamepad help, made for the Deck. Blizzard's legend (GamepadPersistentInputLegend) keeps working
-- (it decides which group shows: at rest, LB, RB, LB + RB, menus, HUD), turned invisible; each time it
-- shows a group, ours draws that group again from its entries (their buttons, as the options' swaps set
-- them, and whether each is usable), with short labels, in columns that fit the text, in a panel with
-- the game's tooltip look, in the bottom-left corner. Nothing of Blizzard's is replaced: its ShowGroup
-- and HideAllGroups are hooked and its entries only read.
--------------------------------------------------------------------------------

local M = 8                                     -- from the screen's edges
local FONT_SIZE, HEADER_SIZE = 12, 13
local ICON, ROW, GAP, PAD, COL_GAP = 18, 20, 5, 10, 12
local DISABLED_ALPHA = 0.4
local REFRESH = 0.25                            -- seconds between looks at the shown group (labels, usable)

-- the short labels, by the game's own strings (read as the file loads, so in the game's language);
-- a label not listed loses what's in brackets ("(Appuyer/Maintenir)")
local SHORT = {
	PROMPT_FRIENDLY_TARGETING = "Alliés",
	PROMPT_HOSTILE_TARGETING = "Ennemis",
	PROMPT_PING = "Ping",
	PROMPT_AUTO_RUN = "Course auto",
	PROMPT_FRIENDLY_TARGETING_ACTIONS = "Ciblage allié",
	PROMPT_HOSTILE_TARGETING_ACTIONS = "Ciblage ennemi",
	PROMPT_TARGET_GROUP_UP = "Membre haut",
	PROMPT_TARGET_GROUP_DOWN = "Membre bas",
	PROMPT_TARGET_GROUP_LEFT = "Membre gauche",
	PROMPT_TARGET_GROUP_RIGHT = "Membre droite",
	PROMPT_APPLY_TARGET_MARKER = "Marquer",
	PROMPT_CLEAR_TARGET_MARKER = "Démarquer",
	PROMPT_TARGET_SELF = "Moi",
	PROMPT_TARGET_PET = "Familier",
	BINDING_NAME_ASSISTTARGET = "Assister",
	PROMPT_SHORTCUTS = "Raccourcis",
	BINDING_NAME_TARGETLASTHOSTILE = "Dernier ennemi",
	RANGED_ATTACK = "Tir",
	PROMPT_SHORTCUT_ACTIONS = "Raccourcis",
	PROMPT_NEXT_ACTION_PAGE = "Page suivante",
	PROMPT_PREVIOUS_ACTION_PAGE = "Page précédente",
	PROMPT_VIEW_QUEST_TRACKER = "Quêtes",
	PROMPT_VIEW_CHAT = "Chat",
	PROMPT_VIEW_BUFFS = "Améliorations",
	BINDING_NAME_TOGGLESHEATH = "Dégainer",
	PROMPT_OPEN_BAGS = "Sacs",
	PROMPT_FLIP_CAMERA = "Demi-tour caméra",
	PROMPT_CENTER_CAMERA = "Centrer caméra",
	PROMPT_ZOOM_IN_CAMERA = "Zoom +",
	PROMPT_ZOOM_OUT_CAMERA = "Zoom -",
	PROMPT_FOCUS_UI = "Interface",
	PROMPT_PREVIOUS_FRAME = "Fenêtre précédente",
	PROMPT_NEXT_FRAME = "Fenêtre suivante",
	PROMPT_TOGGLE_TOOLTIPS = "Infobulles",
	PROMPT_INSPECT_HUD = "Inspecter l'interface",
	SELECT = "Choisir",
	PROMPT_EXIT = "Quitter",
}
local byText = {}
for name, short in pairs(SHORT) do
	local text = _G[name]
	if type(text) == "string" then byText[text] = short end
end

local function Plain(text)
	return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function Short(text)
	text = Plain(text)
	if byText[text] then return byText[text] end
	text = text:gsub("%s*%b()%s*", " "):gsub("^%s+", ""):gsub("%s+$", "")
	return text
end

local panel, font
local rows, icons, used = {}, {}, {}
local shownGroup, wait = nil, 0

local function Build()
	-- the look of the game's tooltips: their backdrop, their fonts
	panel = CreateFrame("Frame", "DeckForeverLegend", UIParent, "TooltipBackdropTemplate")
	panel:SetFrameStrata("LOW")
	-- (the tooltip border is drawn 2 inside the frame: that border M from the edges)
	panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", M - 2, M - 2)
	panel:Hide()
	panel.line = panel:CreateTexture(nil, "ARTWORK")
	panel.line:SetHeight(1)
	panel.line:SetColorTexture(1, 1, 1, 0.15)
	font = GameTooltipText:GetFont()
end

local function Icon(i)
	local t = icons[i]
	if not t then
		t = panel:CreateTexture(nil, "ARTWORK")
		t:SetSize(ICON, ICON)
		icons[i] = t
	end
	return t
end

local function Row(i)
	local fs = rows[i]
	if not fs then
		fs = panel:CreateFontString(nil, "ARTWORK")
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		rows[i] = fs
	end
	return fs
end

-- the entries of a group of Blizzard's legend: { icons = {atlas...}, text, usable, marker, x, y }
local function Entries(legend, group)
	local list = {}
	for _, f in ipairs(legend.groups and legend.groups[group] or {}) do
		if f.InputIcon1 and f.ControlDescText then
			local atlases = {}
			for _, key in ipairs({ "InputIcon1", "InputIcon2" }) do
				local icon = f[key]
				local tex = icon and icon.NormalTexture
				local atlas = tex and tex:GetAtlas()
				if atlas then atlases[#atlases + 1] = atlas end
			end
			local _, _, _, x, y = f:GetPoint(1)
			local marker = f.MarkerDisplayTexture
			list[#list + 1] = {
				icons = atlases,
				text = f.ControlDescText.FontString and f.ControlDescText.FontString:GetText(),
				usable = f.InputIcon1.usableState ~= 3,          -- (InputIconUsableState.Disabled)
				marker = marker and marker:IsShown() and { marker:GetTexCoord() } or nil,
				x = math.floor((x or 0) + 0.5), y = math.floor((y or 0) + 0.5),
			}
		end
	end
	return list
end

local function Render()
	local legend = _G.GamepadPersistentInputLegend
	if not (legend and shownGroup) then panel:Hide() return end
	local list = Entries(legend, shownGroup)
	if #list == 0 then panel:Hide() return end

	-- the header (row 0 of a group that has one), then the columns by Blizzard's x, rows by its y
	local header
	if legend.headers and legend.headers[shownGroup] then
		local top
		for i, e in ipairs(list) do if not top or e.y > list[top].y then top = i end end
		header = table.remove(list, top)
	end
	local xs, columns = {}, {}
	for _, e in ipairs(list) do
		if not columns[e.x] then columns[e.x] = {} xs[#xs + 1] = e.x end
		table.insert(columns[e.x], e)
	end
	table.sort(xs)
	for _, x in ipairs(xs) do table.sort(columns[x], function(a, b) return a.y > b.y end) end

	for _, t in ipairs(icons) do t:Hide() end
	for _, fs in ipairs(rows) do fs:Hide() end
	local nIcon, nRow = 0, 0
	local function Line(e, left, top, size, color)
		local x = left
		for _, atlas in ipairs(e.icons) do
			nIcon = nIcon + 1
			local t = Icon(nIcon)
			t:SetAtlas(atlas)
			t:ClearAllPoints()
			local info = C_Texture.GetAtlasInfo(atlas)
			if info and info.width == 76 and info.height == 75 then
				-- the newer prompt art has padding round it: cut, as Blizzard's own prompts do
				-- (InputIconTextureMixin:ApplyTextureLayout)
				t:SetTexCoord(0.015, 0.96, 0.015, 0.94)
				t:SetSize(ICON * 1.375, ICON * 1.33)
				t:SetPoint("CENTER", panel, "TOPLEFT", x + ICON / 2, -top - ROW / 2)
			else
				t:SetTexCoord(0, 1, 0, 1)
				t:SetSize(ICON, ICON)
				t:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -top - (ROW - ICON) / 2)
			end
			t:SetAlpha(e.usable and 1 or DISABLED_ALPHA)
			t:Show()
			x = x + ICON + 1
		end
		nRow = nRow + 1
		local fs = Row(nRow)
		fs:SetFont(font, size, "")
		fs:SetText(Short(e.text))
		fs:SetTextColor(color[1], color[2], color[3], e.usable and 1 or DISABLED_ALPHA)
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", panel, "TOPLEFT", x - 1 + GAP, -top - ROW / 2)
		fs:Show()
		local width = x - 1 + GAP + fs:GetStringWidth() - left
		if e.marker then
			nIcon = nIcon + 1
			local t = Icon(nIcon)
			t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
			t:SetSize(ICON, ICON)
			t:SetTexCoord(unpack(e.marker))
			t:ClearAllPoints()
			t:SetPoint("LEFT", fs, "RIGHT", GAP, 0)
			t:SetAlpha(1)
			t:Show()
			width = width + GAP + ICON
		end
		return width
	end
	local top = PAD
	local headerWidth = 0
	if header then
		headerWidth = Line(header, PAD, top, HEADER_SIZE, { NORMAL_FONT_COLOR:GetRGB() })
		top = top + ROW + 3
		panel.line:ClearAllPoints()
		panel.line:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(top - 2))
		panel.line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -(top - 2))
		panel.line:Show()
		top = top + 2
	else
		panel.line:Hide()
	end
	local left, tallest = PAD, 0
	for _, x in ipairs(xs) do
		local widest = 0
		for i, e in ipairs(columns[x]) do
			widest = math.max(widest, Line(e, left, top + (i - 1) * ROW, FONT_SIZE, { 1, 1, 1 }))
		end
		tallest = math.max(tallest, #columns[x])
		left = left + widest + COL_GAP
	end
	local width = math.max(left - COL_GAP, PAD + headerWidth) + PAD
	panel:SetSize(math.floor(width + 0.5), top + tallest * ROW + PAD - 2)
	panel:Show()
end

local function OnShowGroup(_, group)
	shownGroup = group
	panel.group = group                          -- (combat mode: DeckForever.lua)
	Render()
end

local function OnHideAll()
	shownGroup = nil
	panel.group = nil
	panel:Hide()
end

local function Setup()
	local legend = _G.GamepadPersistentInputLegend
	if panel or not legend or legend:IsForbidden() then return end
	Build()
	legend:SetAlpha(0)
	hooksecurefunc(legend, "ShowGroup", OnShowGroup)
	hooksecurefunc(legend, "HideAllGroups", OnHideAll)
	panel:SetScript("OnUpdate", function(_, elapsed)
		wait = wait - elapsed
		if wait > 0 then return end
		wait = REFRESH
		Render()
	end)
	-- the group showing now
	for group, frames in pairs(legend.groups or {}) do
		for _, f in ipairs(frames) do
			if f.InputIcon1 and f:IsShown() then shownGroup = group end
		end
	end
	Render()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() Setup() end)
