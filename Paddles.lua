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
--   * LT + paddle 3 (L5, F11): Improved Forever's peek map (its hold button: press shows, release hides).
--     Validated with the real pad, 2026-11-15 (a keyboard Shift + F11 doesn't show what the pad does).
--------------------------------------------------------------------------------

local _, ns = ...

local ROUTES = {
	{ key = "F11", trigger = "PADLTRIGGER", target = "ImprovedForeverPeekMapHold" },
}
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
