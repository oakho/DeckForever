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
	for _, n in ipairs({ "chatStyle", "statusText", "statusTextDisplay", "chatMouseScroll", "wholeChatWindowClickable" }) do
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
					fonts[#fonts + 1] = key .. "|" .. tostring(flags) .. "|" .. (r:GetName() or "?") .. "|" .. (pcall(function() return (r:GetText() or ""):sub(1, 30) end) and select(2, pcall(function() return (r:GetText() or ""):sub(1, 30) end)) or "secret")
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
