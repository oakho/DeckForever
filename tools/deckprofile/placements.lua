-- Where the Deck puts AishUI's blocks: DeckForever's layout of before AishUI (gamepad help top left, chat
-- bottom left, the game's quests top right (placed by DeckForever), minimap bottom right, the combat block
-- over the compact gamepad bar).
-- Absolute values, set on AishUI's "Steam Deck" profiles: build.lua runs this after scaling them,
-- !DiagErreurs' F10 runs it live (tools/deckprofile/dev-install.sh puts this file into it).
-- A = AishCore's profile, E = EllesmereUI's, live = EllesmereUIDB.unlockAnchors (the
-- anchors EllesmereUI works with: the profile only keeps a copy, taken at a profile switch or an export),
-- C = Chattynator's profile.
-- UIParent units (scale 0.96: Deck px).
DeckPlacements = function(A, E, live, C)
	local M = 8                -- the gap to the screen's edges, as everywhere in DeckForever
	local B = M + 4            -- from the bottom: over the XP bar
	local MAP = 203            -- EllesmereUI's minimap, square (measured)
	local MAP_RIM = 2          -- its border, drawn that far outside its frame on the right (measured: the
	                           -- frame M from the edge left the border 6 px from it, the quests' at 8)

	------------------------------------------------------------------ AishCore
	-- The combat block centred on the screen, below and right of the character (DeckForever's camera puts
	-- it left of the centre), over the compact gamepad bar (its top 161 up)
	local CX = 0
	A.resourceCircle.x = CX
	A.castBar.x, A.castBar.y = CX, 175
	local bars = A.unitBars.bars
	bars.player.x, bars.target.x, bars.focus.x = CX - 179, CX + 179, CX + 450
	-- the names in Friz Quadrata (the game's serif, as Improved Forever's target header: more immersive than
	-- AishUI's Bebas); the numbers stay in AishUI's sans serif. (Friz is wider: a size under Bebas's 16)
	for _, bar in pairs(bars) do
		bar.nameFont, bar.nameSize = "Fonts\\FRIZQT__.TTF", 14
	end
	-- the pet under the player, the target's target under the target ("parent": the reference + relX/Y)
	bars.pet.layout, bars.pet.mirrorOf, bars.pet.relX, bars.pet.relY, bars.pet.width = "parent", "player", 0, -30, 140
	local tot = bars.targettarget
	tot.layout, tot.mirrorOf, tot.relX, tot.relY, tot.width = "parent", "target", 0, -30, 140
	-- The out-of-combat circles by the character (at the default zoom: 44 % across, its knees at 41 % up):
	-- health and resource on its left, well fed on its right. Fractions of the screen from the bottom left.
	-- (AishCore's own followPlayer setting is read by nothing.)
	local h, r, w = A.healthCircle, A.outOfCombatResourceCircle, A.wellFedCircle
	h.anchorPctX, h.anchorPctY, h.x, h.y = 0.394, 0.41, 0, 0
	r.anchorPctX, r.anchorPctY, r.x, r.y = 0.4006, 0.3925, 0, 0
	w.anchorPctX, w.anchorPctY, w.x, w.y = 0.488, 0.41, 0, 0
	-- not on the Deck: the consumables (dynamic bar 2), the zone's name (wider than the minimap it sat
	-- over: EllesmereUI's minimap shows it instead, inside), the auto turn-in box (top left)
	local consumables = A.extraBars and A.extraBars.bars and A.extraBars.bars[2]
	if consumables then consumables.enabled = false end
	A.location.enabled = false
	-- the campfire HUD (a big diamond by a campfire): not wanted on the Deck
	A.campfire = A.campfire or {}
	A.campfire.enabled = false
	if A.spellEffects then A.spellEffects.campfireEnabled = false end
	-- the big AishUI logo on the AFK screen
	local afk = A.afkMode and A.afkMode.elements
	if afk then
		afk.aishLogo = afk.aishLogo or {}
		afk.aishLogo.enable = false
	end
	-- the level badge at AishUI's size (DeckForever fills the corner under it: Readability.lua)
	local badge = A.xpBar and A.xpBar.levelBg
	if badge then badge.x, badge.y, badge.w, badge.h = -20.2, -6.5, 87, 54 end
	-- AishCore's menu bar and addons list, bottom right under the mouse: for a mouse, not the gamepad
	if A.menuBar then A.menuBar.enabled = false end
	if A.addonCompartment then A.addonCompartment.enabled = false end
	-- the target's name bar at the top (Improved Forever's target header shows it, readable for the gamepad)
	if A.topTargetBar then A.topTargetBar.enabled = false end
	A.comfort = A.comfort or {}
	A.comfort.questTurnInBox = false

	------------------------------------------------------------------ EllesmereUI (unlock-mode anchors)
	-- An anchor to a screen edge holds one axis (SCREEN_LEFT/RIGHT: X, TOP/BOTTOM: Y): the main one and its
	-- "edge" hold one each. side = the target's side the element sits against: LEFT of SCREEN_RIGHT ->
	-- offset = the element's right - the screen's right; TOP of SCREEN_BOTTOM -> its bottom - the screen's
	-- bottom; BOTTOM of SCREEN_TOP -> its top - the screen's top.
	-- the minimap's own position (EllesmereUIMinimap: a point on the screen's centre; 640 x 400 from it to
	-- the edges): its border M from the right edge, B from the bottom
	-- On it: the place's name at its top (the subzone's, shorter; held to the map's width), the coordinates
	-- at its bottom right
	local mm = E.addons.EllesmereUIMinimap and E.addons.EllesmereUIMinimap.minimap
	if mm then
		mm.position = { point = "CENTER", relPoint = "CENTER", x = 640 - M - MAP_RIM - MAP / 2, y = -(400 - B - MAP / 2) }
		mm.locationMode, mm.locationPosition, mm.zoneShowSubZone = "inside", "top", true
		mm.coordsPosition = "bottomRight"
	end
	-- the clock, FPS and latency strip under the minimap (data bar "Minimap Companion"): not on the Deck
	local dataBars = E.addons.EllesmereUIDataBars and E.addons.EllesmereUIDataBars.bars
	-- and the other data bars, made for a mouse: the black bands along the screen's top and bottom
	-- ("Top Bar", "Bot Bar") and the one shown under the mouse at the bottom ("Data Bot")
	local OFF = { ["Minimap Companion"] = true, ["Top Bar"] = true, ["Bot Bar"] = true, ["Data Bot"] = true }
	for _, bar in pairs(dataBars or {}) do
		if OFF[bar.name] then bar.visibility = "never" end
	end
	-- the player's buffs and debuffs: the game's (placed by DeckForever's Edit Mode layout), not these, which
	-- hide the game's: the gamepad's "Améliorations" (LB / RB / Y) only goes through the game's
	local uf = E.addons.EllesmereUIUnitFrames
	if uf and uf.playerAuraBars then uf.playerAuraBars.enabled = false end
	for _, anchors in ipairs({ E.unlockLayout.anchors, live }) do
		anchors.EBS_Minimap = { side = "LEFT", target = "SCREEN_RIGHT", offsetX = -(M + MAP_RIM), offsetY = 0,
			edge = { key = "SCREEN_BOTTOM", side = "TOP", offset = B } }
	end

	------------------------------------------------------------------ Chattynator
	-- The chat as in DeckForever's first layout: bottom left, M from the left edge, over the XP bar (B),
	-- as tall as the minimap with the zone's name over it; the line you type in over its top lines, shown
	-- only while you type; the tabs only under the mouse (never with the gamepad). Its 65 % brightness,
	-- full while you type: DeckForever's fader (ChattynatorHyperlinkHandler, its windows' parent).
	if C and C.windows and C.windows[1] then
		C.windows[1].position = { "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", M, B }
		C.windows[1].size = { 312, MAP + 18 }
		C.edit_box_position = "top"
		C.keep_edit_box_visible = false
		C.show_tabs_1 = "hover"
	end
end
