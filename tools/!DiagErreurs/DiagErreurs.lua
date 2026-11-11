-- Temporary diagnostics: every Lua error (with its stack) and every blocked action of this session,
-- kept in DiagErreursDB, which the game writes to disk on /reload or logout.
local db = { errors = {}, blocked = {}, started = date("%H:%M:%S") }
local seen = {}

local previous = geterrorhandler()
seterrorhandler(function(msg, ...)
	local key = tostring(msg)
	if not seen[key] then
		seen[key] = true
		db.errors[#db.errors + 1] = { msg = key, stack = debugstack(3, 12, 0), at = date("%H:%M:%S") }
	end
	return previous(msg, ...)
end)

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("ADDON_ACTION_BLOCKED")
f:RegisterEvent("ADDON_ACTION_FORBIDDEN")
f:SetScript("OnEvent", function(_, event, addon, func)
	if event == "ADDON_LOADED" then
		-- (the saved table of the last session is loaded by now: this session's replaces it)
		if addon == "!DiagErreurs" then DiagErreursDB = db end
		return
	end
	local key = event .. " " .. tostring(addon) .. " " .. tostring(func)
	db.blocked[key] = (db.blocked[key] or 0) + 1
end)

-- Layout survey: every shown frame under UIParent (two levels down, and the gamepad bars' own
-- pieces), with its rectangle in screen pixels, a few seconds after entering the world.
local function Rect(f)
	local ok, l, b, w, h = pcall(f.GetRect, f)
	if not ok or not l then return end
	local es = f:GetEffectiveScale()
	return math.floor(l * es + 0.5), math.floor(b * es + 0.5), math.floor(w * es + 0.5), math.floor(h * es + 0.5)
end
local function Survey()
	local out = {}
	local sw, sh = GetPhysicalScreenSize()
	out.screen = { sw, sh, UIParent:GetEffectiveScale() }
	local function Add(f, depth, path)
		if f:IsForbidden() or not f:IsShown() then return end
		local l, b, w, h = Rect(f)
		local name = f:GetName() or (path .. "#" .. (f:GetObjectType() or "?"))
		if l and w > 2 and h > 2 then
			out[#out + 1] = string.format("%d|%s|%d,%d,%d,%d|%s|%d|%s|%.2f", depth, name, l, b, w, h,
				f:GetFrameStrata() or "?", f:GetFrameLevel() or 0, f:IsProtected() and "P" or "-", f:GetEffectiveAlpha() or 1)
		end
		if depth < 2 then
			for i, c in ipairs({ f:GetChildren() }) do Add(c, depth + 1, name .. "." .. i) end
		end
	end
	for i, f in ipairs({ UIParent:GetChildren() }) do Add(f, 0, "UIParent." .. i) end
	local gp = _G.GamepadMainActionBarFrame
	if gp and gp.PageUnit and gp.PageUnit.actionBars then
		for _, key in ipairs({ "LeftShoulderIcon", "RightShoulderIcon", "LeftClassAction", "RightClassAction", "LeftInputPrompt", "RightInputPrompt" }) do
			local t = gp.PageUnit[key]
			if t and t.IsShown and t:IsShown() then
				local l, b, w, h = Rect(t)
				if l then out[#out + 1] = string.format("9|GamepadIcon.%s|%d,%d,%d,%d|-|0|-", key, l, b, w, h) end
			end
		end
		for key, bar in pairs(gp.PageUnit.actionBars) do
			if bar.IsShown and bar:IsShown() then
				local l, b, w, h = Rect(bar)
				if l then out[#out + 1] = string.format("9|GamepadBar.%s|%d,%d,%d,%d|-|0|-", key, l, b, w, h) end
			end
		end
	end
	db.layout = out
	-- the minimap cluster's pieces: name, rect, anchors
	local mm = {}
	local function Dump(f, label)
		if not f or f:IsForbidden() then return end
		local pts = {}
		for i = 1, f:GetNumPoints() do
			local p, rel, rp, x, y = f:GetPoint(i)
			pts[#pts + 1] = string.format("%s>%s:%s(%.0f,%.0f)", p, rel and (rel:GetName() or rel:GetDebugName()) or "nil", rp, x, y)
		end
		local l, b, w, h = Rect(f)
		mm[#mm + 1] = string.format("%s | %s | %s | %s", label, f:GetDebugName() or "?", l and string.format("%d,%d,%d,%d", l, b, w, h) or "-", table.concat(pts, " "))
	end
	if MinimapCluster then
		for k, v in pairs(MinimapCluster) do
			if type(v) == "table" and v.GetObjectType and v.GetNumPoints then Dump(v, "key:" .. tostring(k)) end
		end
		for _, n in ipairs({ "TimeManagerClockButton", "GameTimeFrame", "AddonCompartmentFrame", "MinimapZoneText" }) do Dump(_G[n], n) end
	end
	db.minimap = mm
	local cv = {}
	for _, n in ipairs({ "chatStyle", "statusText", "statusTextDisplay", "chatMouseScroll", "wholeChatWindowClickable", "test_cameraOverShoulder", "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement", "test_cameraDynamicPitch", "cameraDistanceMaxZoomFactor" }) do
		cv[#cv + 1] = n .. "=" .. tostring(GetCVar(n))
	end
	local eb = ChatFrame1EditBox
	if eb then
		cv[#cv + 1] = "editbox shown=" .. tostring(eb:IsShown()) .. " alpha=" .. tostring(eb:GetAlpha())
		local kids = {}
		for _, r in ipairs({ eb:GetRegions() }) do
			if r.GetName and r:GetName() then kids[#kids + 1] = r:GetName() .. (r:IsShown() and "+" or "-") end
		end
		cv[#cv + 1] = "regions " .. table.concat(kids, " ")
	end
	db.cvars = cv
	-- the fonts shown in the HUD: frame > fontstring | font object | size | text
	local fonts, seen = {}, {}
	local function Walk(frame, root, depth)
		if not frame or depth > 8 or frame:IsForbidden() or not frame:IsVisible() then return end
		for _, r in ipairs({ frame:GetRegions() }) do
			if r:GetObjectType() == "FontString" and r:IsVisible() then
				local fo = r:GetFontObject()
				local file, size, flags = r:GetFont()
				local key = root .. "|" .. (fo and fo:GetName() or "-") .. "|" .. string.format("%.1f", size or 0)
				if not seen[key] then
					seen[key] = true
					fonts[#fonts + 1] = key .. "|" .. tostring(flags) .. "|" .. (r:GetName() or ((r:GetParent() and r:GetParent():GetDebugName() or "") .. ">?")) .. "|" .. (pcall(function() return (r:GetText() or ""):sub(1, 30) end) and select(2, pcall(function() return (r:GetText() or ""):sub(1, 30) end)) or "secret")
				end
			end
		end
		for _, c in ipairs({ frame:GetChildren() }) do Walk(c, root, depth + 1) end
	end
	for _, n in ipairs({ "ObjectiveTrackerFrame", "PlayerFrame", "TargetFrame", "MinimapCluster", "ChatFrame1", "DeckForeverLegend", "StatusTrackingBarManager", "EssentialCooldownViewer", "BuffFrame", "GamepadMainActionBarFrame" }) do
		Walk(_G[n], n, 0)
	end
	local cf = ChatFrame1 and { ChatFrame1:GetFont() }
	fonts[#fonts + 1] = "ChatFrame1 font " .. tostring(cf and cf[2])
	db.fonts = fonts
	-- Edit Mode: the layouts as the game has them (read only)
	if C_EditMode and C_EditMode.GetLayouts then
		local ok, info = pcall(C_EditMode.GetLayouts)
		if ok and info then
			local em = { active = info.activeLayout, layouts = {} }
			for i, layout in ipairs(info.layouts or {}) do
				local systems = {}
				for _, sys in ipairs(layout.systems or {}) do
					local a = sys.anchorInfo or {}
					local settings = {}
					for _, st in ipairs(sys.settings or {}) do settings[#settings + 1] = st.setting .. "=" .. tostring(st.value) end
					systems[#systems + 1] = string.format("%s|%s|%s|%s|%s|%s|%.1f|%.1f|%s|%s", tostring(sys.system), tostring(sys.systemIndex),
						tostring(sys.isInDefaultPosition), tostring(a.point), tostring(a.relativeTo), tostring(a.relativePoint),
						a.offsetX or 0, a.offsetY or 0, table.concat(settings, ","), "")
				end
				em.layouts[i] = { name = layout.layoutName, type = layout.layoutType, systems = systems }
			end
			db.editmode = em
		end
		local names = {}
		for k, v in pairs(Enum.EditModeSystem or {}) do names[#names + 1] = k .. "=" .. v end
		db.editmodeSystems = names
		local det = {}
		local ok, presets = pcall(function() return EditModePresetLayoutManager:GetCopyOfPresetLayouts() end)
		det[#det + 1] = "presets ok=" .. tostring(ok) .. " n=" .. tostring(ok and #presets)
		for i, l in ipairs(ok and presets or {}) do det[#det + 1] = "  preset " .. i .. " " .. tostring(l.layoutName) .. " type=" .. tostring(l.layoutType) end
		local saved = C_EditMode.GetLayouts()
		det[#det + 1] = "saved n=" .. #(saved.layouts or {}) .. " active=" .. tostring(saved.activeLayout)
		for i, l in ipairs(saved.layouts or {}) do det[#det + 1] = "  saved " .. i .. " " .. tostring(l.layoutName) .. " type=" .. tostring(l.layoutType) end
		det[#det + 1] = "DeckForever loaded=" .. tostring(C_AddOns and C_AddOns.IsAddOnLoaded("DeckForever")) .. " xpbar=" .. tostring(_G.DeckForeverXPBar ~= nil) .. " legend=" .. tostring(_G.DeckForeverLegend ~= nil)
		det[#det + 1] = "project=" .. tostring(WOW_PROJECT_ID) .. " mainline=" .. tostring(WOW_PROJECT_MAINLINE) .. " classic=" .. tostring(WOW_PROJECT_CLASSIC)
		local arrow = _G.TomTomCrazyArrow
		det[#det + 1] = "arrow=" .. tostring(arrow ~= nil) .. " shown=" .. tostring(arrow and arrow:IsShown()) .. " poiapi=" .. tostring(C_QuestLog and C_QuestLog.GetQuestsOnMap ~= nil) .. " supertrack=" .. tostring(C_SuperTrack ~= nil)
		db.detect = det
		local st = {}
		for k, v in pairs(Enum.EditModeStatusTrackingBarSetting or {}) do st[#st + 1] = k .. "=" .. v end
		db.statusSettings = st
		local bar = MainStatusTrackingBarContainer
		local kids = {}
		for _, c in ipairs(bar and { bar:GetChildren() } or {}) do
			kids[#kids + 1] = string.format("%s %s %.0fx%.0f prot=%s", c:GetName() or "?", c:GetObjectType(), c:GetWidth(), c:GetHeight(), tostring(c:IsProtected()))
			for _, g in ipairs({ c:GetChildren() }) do
				kids[#kids + 1] = string.format("  %s %s %.0fx%.0f prot=%s", g:GetName() or (g.GetDebugName and g:GetDebugName()) or "?", g:GetObjectType(), g:GetWidth(), g:GetHeight(), tostring(g:IsProtected()))
			end
		end
		local function Pts(f)
			local t = {}
			for i = 1, f:GetNumPoints() do
				local pt, rel, rp, x, y = f:GetPoint(i)
				t[#t + 1] = string.format("%s>%s:%s(%.1f,%.1f)", pt, rel and (rel:GetName() or (rel.GetDebugName and rel:GetDebugName()) or "?") or "nil", rp, x, y)
			end
			return table.concat(t, " ")
		end
		local function Regs(f, pre)
			for _, r in ipairs({ f:GetRegions() }) do
				local tex = r.GetAtlas and (r:GetAtlas() or tostring(r:GetTexture())) or (r.GetText and "text") or ""
				kids[#kids + 1] = string.format("%sR %s %s %.0fx%.0f %s shown=%s | %s", pre, r:GetDebugName() or "?", r:GetObjectType(), r:GetWidth(), r:GetHeight(), tostring(tex), tostring(r:IsShown()), Pts(r))
			end
		end
		if bar then
			kids[#kids + 1] = "CONTAINER " .. Pts(bar)
			Regs(bar, "")
			for _, c in ipairs({ bar:GetChildren() }) do
				kids[#kids + 1] = "C " .. (c:GetDebugName() or "?") .. " shown=" .. tostring(c:IsShown()) .. " | " .. Pts(c)
				if c:GetWidth() > 100 then
					Regs(c, "  ")
					for _, g in ipairs({ c:GetChildren() }) do
						kids[#kids + 1] = "  G " .. (g:GetDebugName() or "?") .. " | " .. Pts(g)
						Regs(g, "    ")
					end
				end
			end
		end
		kids[#kids + 1] = "mgr prot=" .. tostring(StatusTrackingBarManager and StatusTrackingBarManager:IsProtected()) .. " bar prot=" .. tostring(bar and bar:IsProtected())
		db.statusBar = kids
		local cr = {}
		local function Dump(f, pre)
			for _, r in ipairs({ f:GetRegions() }) do
				local l, b, w, h = r:GetRect()
				if l then
					local es = r:GetEffectiveScale() * 800 / 768
					cr[#cr + 1] = string.format("%s%s %s shown=%s a=%.2f | %.0f,%.0f %.0fx%.0f", pre, r:GetDebugName() or "?", r:GetObjectType(), tostring(r:IsShown()), r:GetAlpha(), l * es, b * es, w * es, h * es)
				end
			end
		end
		if ChatFrame1 then
			Dump(ChatFrame1, "")
			for _, c in ipairs({ ChatFrame1:GetChildren() }) do if c ~= ChatFrame1EditBox then Dump(c, "  ") end end
		end
		db.chatRegions = cr
	end
end
local surveyFrame = CreateFrame("Frame")
surveyFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
surveyFrame:SetScript("OnEvent", function() C_Timer.After(5, Survey) end)

-- /dgp X Y : every shown frame under the screen pixel (X, Y from the top-left), kept in db.probe
SLASH_DIAGPROBE1 = "/dgp"
SlashCmdList.DIAGPROBE = function(msg)
	local px, py = msg:match("(%d+)%s+(%d+)")
	px, py = tonumber(px), tonumber(py)
	if not px then return end
	local x, y = px * 768 / 800, (800 - py) * 768 / 800
	local hits = {}
	local f = EnumerateFrames()
	while f do
		if not f:IsForbidden() and f:IsVisible() then
			local ok, l, b, w, h = pcall(f.GetRect, f)
			if ok and l then
				local es = f:GetEffectiveScale()
				l, b, w, h = l * es, b * es, w * es, h * es
				if x >= l and x <= l + w and y >= b and y <= b + h and w < 400 then
					local parent = f:GetParent()
					local path = f:GetName() or "?"
					local p, depth = parent, 0
					while p and depth < 4 do path = (p:GetName() or "?") .. ">" .. path p = p:GetParent() depth = depth + 1 end
					hits[#hits + 1] = string.format("%s | %s | %.0fx%.0f | %s", path, f:GetObjectType(), w * 800 / 768, h * 800 / 768, (f.GetDebugName and f:GetDebugName()) or "")
				end
			end
		end
		f = EnumerateFrames(f)
	end
	db.probe = db.probe or {}
	db.probe[px .. "," .. py] = hits
	print("dgp", #hits)
end

-- /dgt : shows a tooltip at the game's default place for 3 s, its rect kept in db.tooltip
SLASH_DIAGTIP1 = "/dgt"
SlashCmdList.DIAGTIP = function()
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	GameTooltip:SetText("Infobulle de test")
	GameTooltip:AddLine("Deuxième ligne, un peu plus longue", 1, 1, 1)
	GameTooltip:Show()
	C_Timer.After(0.2, function()
		local l, b, w, h = GameTooltip:GetRect()
		local es = GameTooltip:GetEffectiveScale()
		local pts = {}
		for i = 1, GameTooltip:GetNumPoints() do
			local p, rel, rp, x, y = GameTooltip:GetPoint(i)
			pts[#pts + 1] = string.format("%s>%s:%s(%.1f,%.1f)", p, rel and (rel:GetName() or "?") or "nil", rp, x, y)
		end
		local il, ir, it, ib = GameTooltip:GetClampRectInsets()
		db.tooltip = string.format("%d,%d,%d,%d | %s | clamp %s %s,%s,%s,%s | scale %.2f", l * es, b * es, w * es, h * es,
			table.concat(pts, " "), tostring(GameTooltip:IsClampedToScreen()), il, ir, it, ib, GameTooltip:GetScale())
	end)
	C_Timer.After(3, function() GameTooltip:Hide() end)
end

-- /dgx WORD : runs a dev snippet by name (typed commands can't carry Lua: the AZERTY keyboard under
-- xdotool mangles brackets and quotes). Edit the table, /reload, then /dgx WORD.
local X = {}

-- pv: AishCore unit bars preview (its settings panel, shown invisible, forces every bar on); again to stop
X.pv = function()
  local p = _G.AishCoreSettingsPanel
  if not p and SlashCmdList.AISHCORE then SlashCmdList.AISHCORE(""); p = _G.AishCoreSettingsPanel end
  if not p then print("dgx pv: no AishCore panel") return end
  if p:IsShown() and p:GetScale() < 0.1 then p:Hide(); p:SetScale(1) else p:Show(); p:SetScale(0.01) end
end

-- deck: the Deck placements (DeckForever's Placements.lua, as loaded)
-- on the live "Steam Deck" profiles; WoW keeps them at the /reload
X.deck = function()
  local A = AishaddonDB and AishaddonDB._profiles and AishaddonDB._profiles["Steam Deck"]
  local E = EllesmereUIDB and EllesmereUIDB.profiles and EllesmereUIDB.profiles["Steam Deck"]
  if not (A and E and DeckPlacements) then print("dgx deck: a Steam Deck profile is missing (tools/deckprofile/build.lua)") return end
  EllesmereUIDB.unlockAnchors = EllesmereUIDB.unlockAnchors or {}
  local C = CHATTYNATOR_CONFIG and CHATTYNATOR_CONFIG.Profiles and CHATTYNATOR_CONFIG.Profiles.DEFAULT
  DeckPlacements(A, E, EllesmereUIDB.unlockAnchors, C, WaypointDB_Global)
  ReloadUI()
end

-- cd: DeckForever's CalmDriver state and the gamepad bar's alpha, kept in db.calm (read at the reload)
X.cd = function()
  local d = _G.DeckForeverCalmDriver
  local bar = _G.GamepadMainActionBarFrame
  db.calm = {
    driver = d and true or false,
    calm = d and tostring(d:GetAttribute("state-calm")),
    awake = d and tostring(d:GetAttribute("state-awake")),
    count = d and tostring(d:GetAttribute("calmCount")),
    alpha1 = d and tostring(d:GetAttribute("calmAlpha1")), alpha2 = d and tostring(d:GetAttribute("calmAlpha2")),
    wakes2 = d and tostring(d:GetAttribute("wakes2")),
    barAlpha = bar and bar:GetAlpha(), barEffective = bar and bar:GetEffectiveAlpha(),
    barShown = bar and bar:IsShown(),
  }
  print("dgx cd: saved")
end

-- hz: HorizonSuite off for this character (the game's quest tracker instead: made for the gamepad), reload
X.hz = function()
  local disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
  disable("HorizonSuite", UnitName("player"))
  ReloadUI()
end

-- wp: WaypointUI readable on the Deck (bigger, fully opaque text), TomTom off for this character, reload
X.wp = function()
  -- (TomTom stays: WaypointUI shows its waypoint; Waypoint.lua hides its arrow)
  if WaypointDB_Global then
    for k, v in pairs({ WaypointScale = 1, PinpointScale = 1, PinpointInfoExtended = false, WaypointSystemType = 2, WaypointDistanceTextType = 1, NavigatorScale = 1.3, WaypointDistanceTextScale = 1.3,
    WaypointDistanceTextAlpha = 1, NavigatorAlpha = 1, fontPath = "Fonts\\FRIZQT__.TTF" }) do WaypointDB_Global[k] = v end
  end
  ReloadUI()
end

-- gp: how this client's gamepad bar is built and bound, kept in db.gamepad (read at the reload)
X.gp = function()
  local out = {}
  for _, cv in ipairs({ "GamePadEnable", "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt" }) do
    out[#out + 1] = cv .. "=" .. tostring(GetCVar(cv))
  end
  for _, key in ipairs({ "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD1", "PAD2", "PADLTRIGGER", "PADRTRIGGER",
                         "SHIFT-PADDUP", "ALT-PADDUP", "CTRL-PADDUP", "SHIFT-PAD1" }) do
    out[#out + 1] = key .. " -> " .. tostring(GetBindingAction(key, true))
  end
  local d = _G.DeckForeverCalmDriver
  out[#out + 1] = "state-pad=" .. tostring(d and d:GetAttribute("state-pad"))
  local function scan(f, depth, path)
    if depth > 5 or not f or f:IsForbidden() then return end
    local n = f:GetName() or "?"
    local info = path .. ">" .. n .. " [" .. f:GetObjectType() .. "]"
    for _, k in ipairs({ "commandName", "bindingAction", "action", "buttonType", "keyBinding", "binding" }) do
      local ok, v = pcall(function() return f[k] end)
      if ok and v ~= nil and type(v) ~= "table" and type(v) ~= "function" then info = info .. " " .. k .. "=" .. tostring(v) end
    end
    if f.GetAttribute then
      for _, a in ipairs({ "action", "type", "binding" }) do
        local ok, v = pcall(f.GetAttribute, f, a)
        if ok and v ~= nil then info = info .. " @" .. a .. "=" .. tostring(v) end
      end
    end
    if f.GetButtonState then info = info .. " state=" .. tostring(f:GetButtonState()) end
    out[#out + 1] = info
    for _, c in ipairs({ f:GetChildren() }) do scan(c, depth + 1, path .. ">" .. n) end
  end
  scan(_G.GamepadMainActionBarFrame, 0, "")
  db.gamepad = out
  print("dgx gp: " .. #out)
end

-- sn: one snapshot of the gamepad bar (modifiers, the shown sub-bars of its page unit, pushed buttons),
-- appended to db.snaps (F5, pressed repeatedly while the player holds a gamepad button)
X.sn = function()
  db.snaps = db.snaps or {}
  local parts = { date("%H:%M:%S"),
    "shift=" .. tostring(IsShiftKeyDown()), "ctrl=" .. tostring(IsControlKeyDown()), "alt=" .. tostring(IsAltKeyDown()) }
  local d = _G.DeckForeverCalmDriver
  parts[#parts + 1] = "pad=" .. tostring(d and d:GetAttribute("state-pad"))
  local pu = _G.GamepadMainActionBarFramePageUnit
  if pu then
    for _, a in ipairs({ "state-page", "actionpage", "page", "state-layer" }) do
      local ok, v = pcall(pu.GetAttribute, pu, a)
      if ok and v ~= nil then parts[#parts + 1] = a .. "=" .. tostring(v) end
    end
  end
  local function scan(f, depth)
    if depth > 6 or not f or f:IsForbidden() then return end
    local n = f:GetName()
    if n and f:IsShown() and n:find("Bar$") then parts[#parts + 1] = "shown:" .. n:gsub("GamepadMainActionBarFramePageUnit", "") end
    if f.GetButtonState and f:GetButtonState() == "PUSHED" then parts[#parts + 1] = "PUSHED:" .. tostring(n) end
    for _, c in ipairs({ f:GetChildren() }) do scan(c, depth + 1) end
  end
  scan(_G.GamepadMainActionBarFrame, 0)
  db.snaps[#db.snaps + 1] = table.concat(parts, " ")
end

-- tt: TomTom on again (every character), reload
X.tt = function()
  local enable = (C_AddOns and C_AddOns.EnableAddOn) or EnableAddOn
  pcall(enable, "TomTom")
  ReloadUI()
end

-- wu: WaypointUI's waypoint frame tree (names, sizes, texts), kept in db.wui
X.wu = function()
  local out = {}
  local root = _G.WUIWaypointFrame
  out[#out + 1] = "root=" .. tostring(root) .. " named footer=" .. tostring(_G["WUIWaypointFrame.Footer"])
  local function scan(f, depth, path)
    if depth > 4 or not f then return end
    local okW, w = pcall(f.GetWidth, f)
    out[#out + 1] = path .. " " .. tostring(f.GetName and f:GetName()) .. " " .. f:GetObjectType() .. " w=" .. tostring(okW and w)
    if f.GetRegions then
      for _, r in ipairs({ f:GetRegions() }) do
        if r:GetObjectType() == "FontString" then
          local ok, t = pcall(r.GetText, r)
          out[#out + 1] = path .. "  FS w=" .. tostring(r:GetWidth()) .. " text=" .. tostring(ok and t)
        end
      end
    end
    if f.GetChildren then for i, c in ipairs({ f:GetChildren() }) do scan(c, depth + 1, path .. "." .. i) end end
  end
  if root then scan(root, 0, "R") end
  db.wui = out
end

-- ca: the gamepad page unit's methods and scripts (what lays the class action out), kept in db.ca
X.ca = function()
  local out = {}
  local unit = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit
  local function methods(obj, label)
    local seen = {}
    local t = obj
    for depth = 1, 3 do
      if type(t) ~= "table" then break end
      for k, v in pairs(t) do
        if type(v) == "function" and not seen[k] then seen[k] = true out[#out + 1] = label .. depth .. ":" .. tostring(k) end
      end
      local mt = getmetatable(t)
      t = mt and type(mt.__index) == "table" and mt.__index or nil
    end
  end
  if unit then
    methods(unit, "unit")
    for _, s in ipairs({ "OnEvent", "OnUpdate", "OnShow", "OnSizeChanged" }) do
      out[#out + 1] = "script " .. s .. "=" .. tostring(unit:GetScript(s) ~= nil)
    end
    local b = unit.LeftClassAction
    if b then
      methods(b, "btn")
      local p = { b:GetPoint(1) }
      out[#out + 1] = "btn point " .. tostring(p[1]) .. " " .. tostring(p[2] and p[2].GetName and p[2]:GetName()) .. " " .. tostring(p[3]) .. " " .. tostring(p[4]) .. " " .. tostring(p[5])
      out[#out + 1] = "btn OnUpdate=" .. tostring(b:GetScript("OnUpdate") ~= nil)
    end
  end
  for _, side in ipairs({ "LeftClassAction", "RightClassAction" }) do
    local b = unit and unit[side]
    if b then
      local icon = b.icon or b.Icon
      local ok, act = pcall(b.GetAttribute, b, "action")
      out[#out + 1] = side .. " shown=" .. tostring(b:IsShown()) .. " visible=" .. tostring(b:IsVisible()) .. " alpha=" .. tostring(b:GetAlpha())
        .. " action=" .. tostring(ok and act) .. " field=" .. tostring(b.action) .. " has=" .. tostring(b.action and HasAction(b.action))
        .. " icon=" .. tostring(icon and icon:IsShown() and icon:GetTexture())
    end
  end
  table.sort(out)
  db.ca = out
end

-- mv: logs who moves the class action (diagnostics only: a post-hook on its SetPoint), kept in db.mv
local mvHooked
X.mv = function()
  local b = GamepadMainActionBarFrame and GamepadMainActionBarFrame.PageUnit and GamepadMainActionBarFrame.PageUnit.LeftClassAction
  if not b or mvHooked then return end
  mvHooked = true
  db.mv = {}
  hooksecurefunc(b, "SetPoint", function(_, point, rel, relPoint, x, y)
    if #db.mv >= 20 then return end
    local stack = debugstack(3, 4, 0) or ""
    db.mv[#db.mv + 1] = date("%H:%M:%S") .. " " .. tostring(x) .. "," .. tostring(y) .. " | " .. stack:gsub("\n", " || ")
  end)
  print("dgx mv: hooked")
end

-- r1: Improved Forever's RB + R3 wheel back to the game's own R3 (RB isn't a modifier key: that wheel
-- made it take every R3, the ping with it), reload
X.r1 = function()
  local IF = ImprovedForever
  if IF and IF.SetComboRing then IF.SetComboRing("R1", "consumables") end
  ReloadUI()
end

-- kl: logs the keyboard keys the game gets for 30 s (a paddle mapped to a key in Steam Input), in db.keys;
-- the keys go on to the game as ever (propagated)
X.kl = function()
  if InCombatLockdown() then return end
  db.keys = {}
  local f = _G.DiagKeyLogger or CreateFrame("Frame", "DiagKeyLogger", UIParent)
  f:EnableKeyboard(true)
  f:SetPropagateKeyboardInput(true)
  f:SetScript("OnKeyDown", function(_, key)
    if #db.keys < 40 then db.keys[#db.keys + 1] = date("%H:%M:%S") .. " " .. tostring(key) .. " -> " .. tostring(GetBindingAction(key, true)) end
  end)
  f:Show()
  C_Timer.After(30, function() if not InCombatLockdown() then f:EnableKeyboard(false) f:Hide() end end)
  print("dgx kl: 30 s")
end

-- pd: one snapshot of the gamepad (buttons held, by name; the paddles' key state and bindings), in db.pads
X.pd = function()
  db.pads = db.pads or {}
  local parts = { date("%H:%M:%S") }
  local pad = C_GamePad
  local id = pad and pad.GetActiveDeviceID and pad.GetActiveDeviceID()
  local state = id and pad.GetDeviceMappedState and pad.GetDeviceMappedState(id)
  for i, down in ipairs(state and state.buttons or {}) do
    if down then parts[#parts + 1] = "btn:" .. tostring(pad.ButtonIndexToBinding and pad.ButtonIndexToBinding(i - 1) or i) end
  end
  for n = 1, 4 do
    local key = "PADPADDLE" .. n
    if IsKeyDown and IsKeyDown(key) then parts[#parts + 1] = "down:" .. key end
  end
  if #db.pads == 0 then
    for n = 1, 4 do parts[#parts + 1] = "PADPADDLE" .. n .. "=" .. tostring(GetBindingAction("PADPADDLE" .. n, true)) end
    parts[#parts + 1] = "wheel=" .. tostring(C_AddOns.IsAddOnLoaded("ImprovedForever_Wheel"))
    parts[#parts + 1] = "device=" .. tostring(id) .. " buttons=" .. tostring(state and #state.buttons)
  end
  db.pads[#db.pads + 1] = table.concat(parts, " ")
end

-- nw: Improved Forever's wheels off (every character), reload
X.nw = function()
  local disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
  pcall(disable, "ImprovedForever_Wheel")
  ReloadUI()
end

-- sc: prints UIParent's scale and Ellesmere's saved one
X.sc = function()
  print("UIParent", UIParent:GetScale(), "EUI", EllesmereUIDB and EllesmereUIDB.ppUIScale, "phys", GetPhysicalScreenSize())
end

SLASH_DIAGDEV1 = "/dgx"
SlashCmdList.DIAGDEV = function(msg)
  local f = X[(msg or ""):match("^%s*(%S+)") or ""]
  if f then local ok, err = pcall(f) if not ok then print("dgx:", err) end
  else local k = {} for n in pairs(X) do k[#k + 1] = n end table.sort(k) print("dgx: " .. table.concat(k, " ")) end
end

-- Dev keys, CTRL-SHIFT-Fn (no typing: the AZERTY keyboard under xdotool turns letters into game shortcuts when the
-- chat line isn't open yet): F9 = /dgx pv, F10 = /dgx deck, F11 = /reload. Override bindings, out of combat.
do
  local keys = { F9 = function() X.pv() end, F11 = function() ReloadUI() end, F8 = function() X.nw() end, F7 = function() X.wp() end, F6 = function() X.gp() end, F5 = function() X.sn() end, F4 = function() X.tt() end, F3 = function() X.wu() end, F2 = function() X.ca() end, F1 = function() X.rd() end, F12 = function() X.pd() end, F10 = function() X.deck() end }
  local owner = CreateFrame("Frame")
  owner:RegisterEvent("PLAYER_ENTERING_WORLD")
  owner:SetScript("OnEvent", function()
    if InCombatLockdown() then return end
    for key, fn in pairs(keys) do
      local name = "DiagDevKey" .. key
      local b = _G[name] or CreateFrame("Button", name, UIParent)
      b:SetScript("OnClick", function() local ok, err = pcall(fn) if not ok then print("dgx key:", err) end end)
      SetOverrideBindingClick(owner, true, "CTRL-SHIFT-" .. key, name)   -- (plain F9-F12: Easy Controller's trackpad)
    end
  end)
end
