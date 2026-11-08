--------------------------------------------------------------------------------
-- The followed quest as a waypoint, by itself: this client (project 18) gives no navigation for a super
-- tracked quest. Here: the quest you follow (super tracked) or else the closest watched one on your map,
-- changed when the quest or its place changes.
--   * with WaypointUI (AishUI): given to it through its API (WaypointUIAPI.Navigation), flagged as ours;
--     it shows it in the world. It makes it a map pin the game tracks, which ends the quest's super
--     tracking: the quest you picked is kept while our pin is what's tracked. A pin you set yourself is
--     never replaced, but by a quest you pick
--   * else TomTom's arrow (TomTom's own quest integration is retail-only), a waypoint you set yourself
--     keeping the arrow
--------------------------------------------------------------------------------

local M = 8                            -- from the screen's edges
local LOOK = 2                         -- seconds between looks (the closest quest changes as you move)
local TURN_IN = "À rendre : "

local ours                             -- our waypoint in TomTom (its uid), and what it points to
local oursKey
local arrowOurs                        -- the arrow shows our waypoint

-- where a quest is on a map, from the quest log's points on it: x, y (0..1), or nil
local function OnMap(questID, mapID)
	for _, info in ipairs(C_QuestLog.GetQuestsOnMap(mapID) or {}) do
		if info.questID == questID and info.x and info.y then return info.x, info.y end
	end
end

-- the quest to point at: questID, mapID, x, y
-- WaypointUI shows our waypoint as a map pin it super tracks, which ends the quest's super tracking in the
-- same moment: the quest you picked is kept while a map pin is what's tracked, and while it's in your log
local FLAG = "DeckForever_Quest"
local function WUI() return WaypointUIAPI and WaypointUIAPI.Navigation end
local function OursTracked()
	local nav = WUI()
	if nav then return nav.IsUserNavigationFlagged and nav.IsUserNavigationFlagged(FLAG) end
	return C_SuperTrack.IsSuperTrackingUserWaypoint and C_SuperTrack.IsSuperTrackingUserWaypoint()
end
local lastFollowed
local picked                           -- the quest was just picked (a real super tracking): it may replace a pin
local function Target()
	local followed = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
	picked = followed and followed > 0
	if picked then
		lastFollowed = followed
	elseif lastFollowed and OursTracked()
		and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(lastFollowed) then
		followed = lastFollowed
	else
		lastFollowed = nil
	end
	if followed and followed > 0 then
		local mapID = GetQuestUiMapID(followed)
		if mapID and mapID > 0 then
			local x, y = OnMap(followed, mapID)
			if x then return followed, mapID, x, y end
		end
	end
	local mapID = C_Map.GetBestMapForUnit("player")
	local here = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
	if not here then return end
	local px, py = here:GetXY()
	local best, bx, by, bestDist
	for i = 1, C_QuestLog.GetNumQuestWatches() do
		local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
		local x, y
		if questID then x, y = OnMap(questID, mapID) end
		if x then
			local dist = (x - px) ^ 2 + (y - py) ^ 2
			if not bestDist or dist < bestDist then best, bx, by, bestDist = questID, x, y, dist end
		end
	end
	if best then return best, mapID, bx, by end
end

-- (an error shown once, not every LOOK)
local reported
local function Safe(fn)
	local ok, err = pcall(fn)
	if not ok and not reported then reported = true geterrorhandler()(err) end
end

local function Clear()
	local nav = WUI()
	if nav then
		if nav.IsUserNavigationFlagged and nav.IsUserNavigationFlagged(FLAG) then pcall(nav.ClearUserNavigation) end
	elseif ours then
		pcall(TomTom.RemoveWaypoint, TomTom, ours)
	end
	ours, oursKey = nil, nil
end

local function Update()
	local questID, mapID, x, y = Target()
	if not questID then
		if ours then Clear() end
		return
	end
	local title = C_QuestLog.GetTitleForQuestID(questID) or ""
	if C_QuestLog.IsComplete(questID) then title = TURN_IN .. title end
	local key = ("%d:%d:%.3f:%.3f:%s"):format(questID, mapID, x, y, title)
	local nav = WUI()
	if nav then
		if key == oursKey and OursTracked() then return end
		-- a pin of yours (not ours) stays, but for a quest you just picked
		local tracked = nav.IsUserNavigationTracked and nav.IsUserNavigationTracked()
		if tracked and not OursTracked() and not picked then return end
		local ok = pcall(nav.NewUserNavigation, { name = title, mapID = mapID, x = x * 100, y = y * 100,
			flags = FLAG, suppressAudio = true, stripCoordinates = true })
		if ok then ours, oursKey = true, key end
		return
	end
	if key == oursKey then return end
	local free = TomTom:IsCrazyArrowEmpty() or arrowOurs
	Clear()
	local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y, {
		title = title, from = "DeckForever", persistent = false, silent = true,
		cleardistance = 0, crazy = free,
	})
	if ok and uid then
		ours, oursKey = uid, key
		arrowOurs = free
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		if not ((WUI() or (TomTom and TomTom.AddWaypoint)) and C_QuestLog and C_QuestLog.GetQuestsOnMap) then return end
		-- the arrow at the top's middle, set once in TomTom's own setting (which it applies as the world
		-- loads; moved by hand afterwards, it stays where you put it)
		local arrow = TomTom and TomTom.profile and TomTom.profile.arrow
		if arrow and not DeckForeverDB.arrowPlaced then
			DeckForeverDB.arrowPlaced = true
			arrow.position = { "TOP", nil, "TOP", 0, -M }
		end
		-- with WaypointUI (AishUI) TomTom only feeds it: WaypointUI shows the waypoint TomTom's arrow is set
		-- to, in the world, so TomTom's own arrow is hidden (a doublon at the top)
		if arrow and C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("WaypointUI") and arrow.enable ~= false then
			arrow.enable = false
			if TomTom.ShowHideCrazyArrow then pcall(TomTom.ShowHideCrazyArrow, TomTom) end
		end
		-- TomTom's coordinates block off (it sat between the unit frames; the minimap shows them), once,
		-- in TomTom's own setting: turned back on in its options as any other
		local block = TomTom and TomTom.profile and TomTom.profile.block
		if block and not DeckForeverDB.coordsOff then
			DeckForeverDB.coordsOff = true
			block.enable = false
			if TomTom.ShowHideCoordBlock then pcall(TomTom.ShowHideCoordBlock, TomTom) end
		end
		for _, e in ipairs({ "QUEST_POI_UPDATE", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED",
			"SUPER_TRACKING_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
			pcall(f.RegisterEvent, f, e)
		end
		local wait = 0
		f:SetScript("OnUpdate", function(_, elapsed)
			wait = wait - elapsed
			if wait > 0 then return end
			wait = LOOK
			Safe(Update)
		end)
		return
	end
	C_Timer.After(0, function() Safe(Update) end)
end)

-- WaypointUI's text under its waypoint (the quest's name, the distance) is 100 wide, set in its code
-- (no option): long quest names wrapped in narrow lines. Widened here, again every LOOK (its layout may
-- set it back); display only, WaypointUI's own frames, nothing protected.
local FOOTER_WIDTH = 300
local FOOTER_TEXTS = { "WUIWaypointFrame.Footer.InfoText", "WUIWaypointFrame.Footer.DistanceText",
	"WUIWaypointFrame.Footer.ArrivalTimeText" }
local function Widen(frame)
	if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
	if frame.GetWidth and math.abs(frame:GetWidth() - FOOTER_WIDTH) > 0.5 then frame:SetWidth(FOOTER_WIDTH) end
	for _, region in ipairs({ frame.GetRegions and frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "FontString" and math.abs(region:GetWidth() - FOOTER_WIDTH) > 0.5 then
			region:SetWidth(FOOTER_WIDTH)
		end
	end
end
local widener = CreateFrame("Frame")
local wait = 0
widener:SetScript("OnUpdate", function(_, elapsed)
	wait = wait - elapsed
	if wait > 0 then return end
	wait = LOOK
	-- (its frames are named but not globals: found under WUIWaypointFrame, by name)
	local root = _G.WUIWaypointFrame
	if not root then return end
	local wanted = { ["WUIWaypointFrame.Footer"] = true }
	for _, name in ipairs(FOOTER_TEXTS) do wanted[name] = true end
	local function walk(frame, depth)
		if depth > 5 then return end
		for _, child in ipairs({ frame:GetChildren() }) do
			if wanted[child:GetName() or ""] then pcall(Widen, child) end
			walk(child, depth + 1)
		end
	end
	pcall(walk, root, 0)
end)
