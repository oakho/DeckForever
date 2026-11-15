--------------------------------------------------------------------------------
-- DeckForever's options, in the game's own settings (Options > AddOns > DeckForever: its list, so the gamepad
-- moves through it as through the game's), /df options opens it. Each control is a setting on DeckForeverDB,
-- applied as it changes.
--   * the horizontal skill bar (SkillBar.lua): on (with the round, with a gap) or off; its look (the game's, flat);
--     what shows round its two groups (ns.SKILL_PARTS): hidden, only our picture goes, the buttons still work
--------------------------------------------------------------------------------

local _, ns = ...

local category

local function Register()
	if category or not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then return end
	DeckForeverDB = DeckForeverDB or {}
	local db = DeckForeverDB
	db.skillShow = db.skillShow or {}
	-- (the wheel slot's option was made on, its first default: off, once; the player may turn it on again)
	if not db.recentOffOnce then db.recentOffOnce = true db.skillShow.recent = false end
	-- (the skill bar's two choices: off is kept as "off", never nil, so the list shows it)
	if db.skillBar ~= "round" and db.skillBar ~= "gap" then db.skillBar = "off" end
	if db.skillStyle ~= "flat" then db.skillStyle = "blizzard" end

	category = Settings.RegisterVerticalLayoutCategory("DeckForever")
	local layout = SettingsPanel and Settings.GetLayout and Settings.GetLayout(category)
	local function Header(text)
		if layout and CreateSettingsListSectionHeaderInitializer then
			pcall(function() layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text)) end)
		end
	end
	local function Changed() if ns.SkillBarChanged then ns.SkillBarChanged() end end
	local function Choice(variable, key, name, default, choices, tooltip)
		local setting = Settings.RegisterAddOnSetting(category, "DeckForever_" .. variable, key, db,
			Settings.VarType.String, name, default)
		setting:SetValueChangedCallback(Changed)
		local function Options()
			local container = Settings.CreateControlTextContainer()
			for _, c in ipairs(choices) do container:Add(c[1], c[2]) end
			return container:GetData()
		end
		Settings.CreateDropdown(category, setting, Options, tooltip)
	end

	Header("Barre d'action horizontale (expérimental)")
	Choice("skillBar", "skillBar", "Barre horizontale", "off",
		{ { "round", "Avec le rond de vie" }, { "gap", "Avec un espace" }, { "off", "Désactivée (barre du jeu)" } },
		"Les boutons de la manette sur une ligne, en bas, comme la barre de Guild Wars 2. La barre du jeu reste active dessous.")
	Choice("skillStyle", "skillStyle", "Style", "blizzard",
		{ { "blizzard", "Celui du jeu" }, { "flat", "Plat" } },
		"Celui du jeu : les cases recopiées de la barre manette d'origine.")
	for _, part in ipairs(ns.SKILL_PARTS or {}) do
		local setting = Settings.RegisterAddOnSetting(category, "DeckForever_skillShow_" .. part.key, part.key,
			db.skillShow, Settings.VarType.Boolean, part.label, part.key ~= "recent")
		setting:SetValueChangedCallback(Changed)
		Settings.CreateCheckbox(category, setting, "Masqué, il ne disparaît que de l'écran : son bouton marche toujours.")
	end

	Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
	Register()
	if not category then return print("DeckForever : options indisponibles sur ce client.") end
	if InCombatLockdown() then return print("DeckForever : options après le combat.") end
	Settings.OpenToCategory(category:GetID())
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	local ok, err = pcall(Register)
	if not ok then print("DeckForever options : " .. tostring(err)) end
end)
