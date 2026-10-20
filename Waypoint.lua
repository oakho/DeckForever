--------------------------------------------------------------------------------
-- TomTom's arrow on the quests, by itself. TomTom only does it on retail (WOW_PROJECT_ID 1); this
-- client is project 18, so its quest integration stays off and the arrow waits for a waypoint set by
-- hand. Here: the quest you follow (super tracked) or else the closest watched one on your map, given
-- to TomTom as a waypoint of ours (not saved, never cleared on arrival), changed when the quest or its
-- place changes. A waypoint you set yourself keeps the arrow. Nothing without TomTom.
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
local function Target()
	local followed = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()
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
	if ours then pcall(TomTom.RemoveWaypoint, TomTom, ours) end
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
		if not (TomTom and TomTom.AddWaypoint and C_QuestLog and C_QuestLog.GetQuestsOnMap) then return end
		-- the arrow at the top's middle, set once in TomTom's own setting (which it applies as the world
		-- loads; moved by hand afterwards, it stays where you put it)
		local arrow = TomTom.profile and TomTom.profile.arrow
		if arrow and not DeckForeverDB.arrowPlaced then
			DeckForeverDB.arrowPlaced = true
			arrow.position = { "TOP", nil, "TOP", 0, -M }
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
