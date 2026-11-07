-- Where the Deck puts AishUI's blocks: DeckForever's layout of before AishUI (gamepad help top left, chat
-- bottom left, quests top right, minimap bottom right, the combat block over the compact gamepad bar).
-- Absolute values, set on AishUI's "Steam Deck" profiles: build.lua runs this after scaling them,
-- !DiagErreurs' F10 runs it live (tools/deckprofile/dev-install.sh puts this file into it).
-- A = AishCore's profile, E = EllesmereUI's, H = HorizonSuite's, live = EllesmereUIDB.unlockAnchors (the
-- anchors EllesmereUI works with: the profile only keeps a copy, taken at a profile switch or an export).
-- UIParent units (scale 0.96: Deck px).
DeckPlacements = function(A, E, H, live)
	local M = 8                -- the gap to the screen's edges, as everywhere in DeckForever
	local B = M + 4            -- from the bottom: over the XP bar
	local MAP = 203            -- EllesmereUI's minimap, square (measured)
	local QUESTS = 260         -- the quest tracker's width

	------------------------------------------------------------------ AishCore
	-- The combat block centred on the screen, below and right of the character (DeckForever's camera puts
	-- it left of the centre), over the compact gamepad bar (its top 161 up)
	local CX = 0
	A.resourceCircle.x = CX
	A.castBar.x, A.castBar.y = CX, 175
	local bars = A.unitBars.bars
	bars.player.x, bars.target.x, bars.focus.x = CX - 179, CX + 179, CX + 450
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
	-- the consumables (dynamic bar 2, out of combat: AishUI's place was off the screen, clamped onto the
	-- minimap): bottom right on the supplies' line, left of Easy Controller's supplies (DeckForever's /df go
	-- puts them M left of the minimap, about 34 wide). Placed by its centre, 49 tall.
	local consumables = A.extraBars and A.extraBars.bars and A.extraBars.bars[2]
	if consumables then
		consumables.anchor = "CENTER"
		consumables.x, consumables.y = 640 - (M + MAP + M + 34 + M), -(400 - B - 49 / 2)   -- (measured: its centre sits M left of the supplies)
	end
	-- the zone's name over the minimap, right-aligned with it
	local loc = A.location
	loc.point, loc.relativePoint, loc.x, loc.y = "BOTTOMRIGHT", "BOTTOMRIGHT", -M, B + MAP + 4

	------------------------------------------------------------------ EllesmereUI (unlock-mode anchors)
	-- An anchor to a screen edge holds one axis (SCREEN_LEFT/RIGHT: X, TOP/BOTTOM: Y): the main one and its
	-- "edge" hold one each. side = the target's side the element sits against: LEFT of SCREEN_RIGHT ->
	-- offset = the element's right - the screen's right; TOP of SCREEN_BOTTOM -> its bottom - the screen's
	-- bottom; BOTTOM of SCREEN_TOP -> its top - the screen's top.
	-- the minimap's own position (EllesmereUIMinimap: a point on the screen's centre; 640 x 400 from it to
	-- the edges): its border M from the right edge, B from the bottom
	local mm = E.addons.EllesmereUIMinimap and E.addons.EllesmereUIMinimap.minimap
	if mm then
		mm.position = { point = "CENTER", relPoint = "CENTER", x = 640 - M - MAP / 2, y = -(400 - B - MAP / 2) }
	end
	for _, anchors in ipairs({ E.unlockLayout.anchors, live }) do
		anchors.EBS_Minimap = { side = "LEFT", target = "SCREEN_RIGHT", offsetX = -M, offsetY = 0,
			edge = { key = "SCREEN_BOTTOM", side = "TOP", offset = B } }
		-- the buffs top right, left of the quests; the debuffs under them
		anchors.PAB_Buffs = { side = "BOTTOM", target = "SCREEN_TOP", offsetX = 0, offsetY = -M,
			edge = { key = "SCREEN_RIGHT", side = "LEFT", offset = -(M + QUESTS + M) } }
		anchors.PAB_Debuffs = { side = "BOTTOM", target = "SCREEN_TOP", offsetX = 0, offsetY = -(M + 60 + M),
			edge = { key = "SCREEN_RIGHT", side = "LEFT", offset = -(M + QUESTS + M) } }
	end

	------------------------------------------------------------------ HorizonSuite
	-- the quests top right
	H.point, H.relPoint, H.x, H.y = "TOPRIGHT", "TOPRIGHT", -M, -M
	H.panelWidth = QUESTS
	H.maxContentHeight, H.maxContentHeightOverworld = 420, 420
end
