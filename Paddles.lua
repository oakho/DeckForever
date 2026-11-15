--------------------------------------------------------------------------------
-- The back paddles with a trigger, for what needs its release too (held: shown while held).
-- The Deck's paddles reach the game as keyboard keys (Steam Input: F9-F12), and LT's Shift (the game's
-- GamePadEmulateShift) doesn't come with them reliably: LT + a paddle may come as the paddle alone. Easy
-- Controller tells them apart by reading the triggers on the press (its router), but hands the release on to
-- its own wheels only. Here: the paddle's key (with any modifier) clicks the target itself (another addon's
-- secure button: press and release), with priority over Easy Controller's bindings, through a check of ours
-- wrapped on it (SecureHandlerWrapScript, the game's own way): the press goes on only while the trigger is
-- held on the pad (GetGamePadState; or its Shift came), its release with it; anything else does nothing.
-- Other clicks of the target (its own key, its addon's) go through untouched.
-- And the d-pad's keys of the Steam layout ("Manette WoW": the d-pad in four-buttons mode sends up F8, down F5,
-- left F7, right F6; the right trackpad is the pad's d-pad). In Game Mode the game only gets those keys. In
-- Desktop Mode it reads the Deck's pad itself too: the d-pad comes twice, as the pad's d-pad (the gamepad bar's
-- d-pad slots, as the trackpad's in Game Mode) and as the key. So each key goes through a relay of ours that
-- does nothing while the pad's matching direction is held (GetGamePadState, read on the press: Desktop Mode),
-- else does the key's job:
--   * d-pad up (F8): Improved Forever's emote wheel (its open button: opens, or closes it if it's up)
--   * down (F5): the game's own job of the key (target party member 4); left (F7), right (F6): nothing
--   * LT + paddle 3 (L5, F11): Improved Forever's peek map (its hold button: press shows, release hides).
--     Validated with the real pad, 2026-11-15 (a keyboard Shift + F11 doesn't show what the pad does).
--------------------------------------------------------------------------------

local _, ns = ...

local ROUTES = {
	{ key = "F11", trigger = "PADLTRIGGER", target = "ImprovedForeverPeekMapHold" },
}
local KEYS = {
	{ key = "F8", pad = "PADDUP", click = "ImprovedForeverWheel_emotes" },
	{ key = "F5", pad = "PADDDOWN", unit = "party4" },
	{ key = "F7", pad = "PADDLEFT" },
	{ key = "F6", pad = "PADDRIGHT" },
}
-- (a relay's press stopped while its d-pad direction is held on the pad)
local SAME_DPAD = [[
	local state = GetGamePadState()
	local index = self:GetAttribute("df-pad")
	if state and state.buttons and index and state.buttons[index] then return false end
]]
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-" }
local BUTTON = "DeckForeverPaddle"

-- (on the target, before its own handler: a press without the trigger, and its release, stopped)
local CHECK = [[
	if button ~= "DeckForeverPaddle" then return end
	if down then
		local state = GetGamePadState()
		local index = self:GetAttribute("df-trigger")
		local held = (state and state.buttons and index and state.buttons[index]) or IsShiftKeyDown()
		if not held then
			self:SetAttribute("df-stopped", true)
			return false
		end
		self:SetAttribute("df-stopped", nil)
	elseif self:GetAttribute("df-stopped") then
		self:SetAttribute("df-stopped", nil)
		return false
	end
	return "LeftButton"
]]

local owner = CreateFrame("Frame", "DeckForeverPaddles")
local wrapped = {}
local pending

local function Apply()
	if InCombatLockdown() then pending = true return end
	pending = nil
	ClearOverrideBindings(owner)
	for _, bind in ipairs(KEYS) do
		local name = "DeckForeverDpad" .. bind.key
		local relay = _G[name]
		if not relay then
			relay = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
			relay:SetSize(1, 1)
			relay:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, 20)
			relay:RegisterForClicks("AnyDown")
			SecureHandlerWrapScript(relay, "OnClick", relay, SAME_DPAD)
		end
		relay:SetAttribute("df-pad", (C_GamePad and C_GamePad.ButtonBindingToIndex
			and C_GamePad.ButtonBindingToIndex(bind.pad) or -1) + 1)
		-- (a click as the wheel's button takes one from a macro: "Macro", opening it on the press's only phase)
		if bind.click then
			relay:SetAttribute("type", "macro")
			relay:SetAttribute("macrotext", "/click " .. bind.click .. " Macro")
		elseif bind.unit then
			relay:SetAttribute("type", "target")
			relay:SetAttribute("unit", bind.unit)
		else
			relay:SetAttribute("type", nil)
		end
		SetOverrideBindingClick(owner, true, bind.key, name, "LeftButton")
	end
	for _, route in ipairs(ROUTES) do
		local target = _G[route.target]
		if target and not target:IsForbidden() and C_GamePad and C_GamePad.ButtonBindingToIndex then
			if not wrapped[target] then
				wrapped[target] = true
				SecureHandlerWrapScript(target, "OnClick", target, CHECK)
			end
			target:SetAttribute("df-trigger", (C_GamePad.ButtonBindingToIndex(route.trigger) or -1) + 1)
			for _, prefix in ipairs(PREFIXES) do
				SetOverrideBindingClick(owner, true, prefix .. route.key, route.target, BUTTON)
			end
		end
	end
end
ns.ApplyPaddles = Apply

owner:RegisterEvent("PLAYER_ENTERING_WORLD")
owner:RegisterEvent("PLAYER_REGEN_ENABLED")
owner:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" and not pending then return end
	-- (a moment after the world: Improved Forever's buttons made, Easy Controller's bindings set)
	C_Timer.After(1, Apply)
end)
