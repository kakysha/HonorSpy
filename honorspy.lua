HonorSpy = LibStub("AceAddon-3.0"):NewAddon("HonorSpy", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("HonorSpy", true)
local libDeflate = LibStub("LibDeflate")

local addonName = GetAddOnMetadata("HonorSpy", "Title");
local commPrefix = addonName .. "7";

local paused = false; -- pause all inspections when user opens inspect frame
local playerName = HonorSpyUtils:getFullUnitName("player");
local callback = nil
local nameToTest = nil
local startRemovingFakes = false
local som_realm = false
local ERR_FRIEND_ONLINE_PATTERN = ERR_FRIEND_ONLINE_SS:gsub("%%s", "(.+)"):gsub("([%[%]])", "%%%1")
local last_test = time() - 300
local checkingPlayers = false;
local addingPlayer = false;
local muteTimer = C_Timer.NewTimer(1,function () end)
local lastPlayer

local inspectedPlayers = {}; -- stores last_checked time of all players met
local inspectedPlayerName = nil; -- name of currently inspected player

local function isFakePlayer(playerName)
	if (HonorSpy.db.factionrealm.fakePlayers[playerName]) then
		return true
	end
	return false
end

local function class_exist(className)
	if className == "WARRIOR" or 
	className == "PRIEST" or
	className == "SHAMAN" or
	className == "WARLOCK" or
	className == "MAGE" or
	className == "ROGUE" or
	className == "HUNTER" or
	className == "PALADIN" or
	className == "DRUID" then
		return true
	end
	return false
end

-- Adds Hexadecimal string length as prefix to check on receiving end
local function prefixMessage(message)
	return string.format("%04x", #message) .. message
end

-- Splits the original message and it's length prefix
local function splitPrefixAndMessage(prefixedMessage)
	return string.sub(prefixedMessage, 1, 4), string.sub(prefixedMessage, 5)
end

-- prefix, compress and encode message for comms
local function prepareMessageForComms(message)
	message = prefixMessage(message)
	message = libDeflate:CompressZlib(message)
	message = libDeflate:EncodeForWoWAddonChannel(message)

	return message
end

-- Uncompress the message and checks if it's length match the prefix value
-- Returns nil if the message is corrupted
local function decodeDecompressAndCheckMessage(message, decodeAndDecompress)
	if (decodeAndDecompress) then
		message = libDeflate:DecodeForWoWAddonChannel(message)
		if (nil == message) then return end
		message = libDeflate:DecompressZlib(message)
		if (nil == message) then return end
	end

	-- Manually check the length of the original message
	local prefix, originalMessage = splitPrefixAndMessage(message)
	if (tonumber("0x" .. prefix) ~= #originalMessage) then return end

	return originalMessage
end

local function playerIsValid(player)
	if (not player.last_checked or type(player.last_checked) ~= "number" or player.last_checked < HonorSpy.db.char.last_reset
		or player.last_checked > GetServerTime()
		or not player.thisWeekHonor or type(player.thisWeekHonor) ~= "number" or player.thisWeekHonor == 0
		-- Avoids storing players that were not reset properly by blizzard in the first 12h after the weekly reset
		or (player.last_checked < HonorSpy.db.char.last_reset + 12 * 60 * 60 and player.thisWeekHonor > 1)
		or not player.lastWeekHonor or type(player.lastWeekHonor) ~= "number"
		or not player.standing or type(player.standing) ~= "number"
		or not player.RP or type(player.RP) ~= "number"
		or not player.rankProgress or type(player.rankProgress) ~= "number"
		or not player.rank or type(player.rank) ~= "number"
		or not player.class or not class_exist(player.class)
		) then
		return false
	end
	return true
end

local function store_player(playerName, player)
	if (
		player == nil or
		playerName == nil or
		not playerName:find("-") or
		playerName:gsub("%-", "", 1):find("[%d%p%s%c%z]") or
		isFakePlayer(playerName) or
		not playerIsValid(player)
	) then
		return
	end
	
	if(addingPlayer) then
		C_Timer.After(0.1,function() store_player(playerName, player); end)
	else
		addingPlayer = true
		
		local player = table.copy(player);
		local localPlayer = HonorSpy.db.factionrealm.currentStandings[playerName];
				
		if (localPlayer == nil or localPlayer.last_checked < player.last_checked) then
			HonorSpy.db.factionrealm.currentStandings[playerName] = player;
			if (not checkingPlayers and (time() - last_test >= 300)) then
				HonorSpy:TestNextFakePlayer();
			else
				if(not HonorSpy.db.factionrealm.goodPlayers[playerName] and not HonorSpy.db.factionrealm.fakePlayers[playerName]) then
					HonorSpy:TestNextFakePlayer();
				end
			end
			addingPlayer = false;
		else
			addingPlayer = false;
		end
	end
end

local function broadcast(originalMessage, skip_yell)

	local encodedMessage = prepareMessageForComms(originalMessage)
	if (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance()) then
		HonorSpy:SendCommMessage(commPrefix, encodedMessage, "INSTANCE_CHAT");
	elseif (IsInRaid()) then
		HonorSpy:SendCommMessage(commPrefix, encodedMessage, "RAID");
	end
	if (GetGuildInfo("player") ~= nil) then
		HonorSpy:SendCommMessage(commPrefix, encodedMessage, "GUILD");
	end

	if (not skip_yell) then
		-- No compression / encoding for yells
		local prefixedMessage = prefixMessage(originalMessage)
		HonorSpy:SendCommMessage(commPrefix, prefixedMessage, "YELL");
	end
end

local function processInspect(player, name, todayHK, thisweekHK, thisWeekHonor, lastWeekHonor, standing, rankProgress)
    if (thisweekHK < 15) and (todayHK >= 15) then
        thisweekHK = todayHK
        thisWeekHonor = 1
    end
    
    player.thisWeekHonor = thisWeekHonor;
	player.lastWeekHonor = lastWeekHonor;
	player.standing = standing;
	if ( name == playerName ) then
		player.estHonor = HonorSpy.db.char.estimated_honor
	end

	player.rankProgress = rankProgress
	
	player.last_checked = GetServerTime();
	player.RP = 0;
    
    if (thisweekHK >= 15) then
		if (player.rank >= 3) then
			player.RP = math.ceil((player.rank-2) * 5000 + player.rankProgress * 5000)
		elseif (player.rank == 2) then
			player.RP = math.ceil(player.rankProgress * 3000 + 2000)
		end
		store_player(name, player)
		broadcast(HonorSpy:Serialize(name, player))
	else
		HonorSpy.db.factionrealm.currentStandings[name] = nil
	end
end

-- store the last checked details about the player, so we can only re-broadcast if something actually changed, or enough time has passed
local lastPlayerTodayHK, lastPlayerEstHonor, lastPlayerThisweekHK, lastPlayerThisWeekHonor, lastPlayerLastWeekHonor, lastPlayerStanding, lastPlayerRankProgress, lastPlayerChecked

local function StartInspecting(unitID)

	local _, realm = GetUnitName(unitID, true);
	local name = HonorSpyUtils:getFullUnitName(unitID)
	if (name == nil or not UnitPlayerControlled(unitID) or UnitName(unitID) == UNKNOWNOBJECT) then return end
	if (realm == nil) then realm = HonorSpyUtils:getRealmFromFullUnitName(name) end

	if unitID == "player" then
        -- Instead of waiting for an inspect of self, we can use GetPVPSessionStats and GetPVPThisWeekStats
        local player = HonorSpy.db.factionrealm.currentStandings[name] or {last_checked = 0, unitID = "player", rank = select(2, GetPVPRankInfo(UnitPVPRank("player"))), class = select(2, UnitClass("player")),}
	    if (player == nil) then return end
	    if (player.class == nil) then player.class = "nil" end

	    local todayHK = GetPVPSessionStats()
        local thisweekHK, thisWeekHonor = GetPVPThisWeekStats()
        local _, _, lastWeekHonor, standing = GetPVPLastWeekStats()
        local rankProgress = GetPVPRankProgress()

        if (lastPlayerTodayHK ~= todayHK) or
            (lastPlayerEstHonor ~= player.estHonor) or
            (lastPlayerThisweekHK ~= thisweekHK) or
            (lastPlayerThisWeekHonor ~= thisWeekHonor) or
            (lastPlayerLastWeekHonor ~= lastWeekHonor) or
            (lastPlayerStanding ~= standing) or
            (lastPlayerRankProgress ~= rankProgress) or
            (lastPlayerChecked and ((GetServerTime() - lastPlayerChecked) > 60)) then
                processInspect(player, name, todayHK, thisweekHK, thisWeekHonor, lastWeekHonor, standing, rankProgress)
                lastPlayerTodayHK, lastPlayerEstHonor, lastPlayerThisweekHK, lastPlayerThisWeekHonor, lastPlayerLastWeekHonor, lastPlayerStanding, lastPlayerRankProgress, lastPlayerChecked = todayHK, player.estHonor, thisweekHK, thisWeekHonor, lastWeekHonor, standing, rankProgress, GetServerTime()
        end
    else
        if (paused or (not C_PlayerInfo.UnitIsSameServer(PlayerLocation:CreateFromUnit(unitID)))) then
            return
        end
       
        if realm and realm ~= "" and realm ~= GetRealmName() then
            HonorSpy.db.factionrealm.connectedRealms[realm] = true
        end
        if (name ~= inspectedPlayerName) then -- changed target, clear currently inspected player
            ClearInspectPlayer();
            inspectedPlayerName = nil;
        end
        if (name == nil
            or name == inspectedPlayerName
		    or not UnitIsPlayer(unitID)
		    or not UnitIsFriend("player", unitID)
		    or not CheckInteractDistance(unitID, 1)
		    or not CanInspect(unitID)) then
		      return
	    end
    	local player = HonorSpy.db.factionrealm.currentStandings[name] or inspectedPlayers[name];
    	if (player == nil) then
    		inspectedPlayers[name] = {last_checked = 0};
    		player = inspectedPlayers[name];
    	end
    	if (GetServerTime() - player.last_checked < 30) then -- 30 seconds until new inspection request
    		return
    	end
    	-- we gonna inspect new player, clear old one
    	ClearInspectPlayer();
    	inspectedPlayerName = name;
    	player.unitID = unitID;
    	NotifyInspect(unitID);
    	RequestInspectHonorData();
    	_, player.rank = GetPVPRankInfo(UnitPVPRank(player.unitID)); -- rank must be get asap while mouse is still over a unit
    	_, player.class = UnitClass(player.unitID); -- same
    end
end

function HonorSpy:INSPECT_HONOR_UPDATE()
	if (inspectedPlayerName == nil or paused or not HasInspectHonorData()) then
		return;
	end

	local player = self.db.factionrealm.currentStandings[inspectedPlayerName] or inspectedPlayers[inspectedPlayerName];
	if (player == nil) then return end
	if (player.class == nil) then player.class = "nil" end

	local todayHK, _, _, _, thisweekHK, thisWeekHonor, _, lastWeekHonor, standing = GetInspectHonorData();
    local rankProgress = GetInspectPVPRankProgress()
	
    if (lastPlayer and (thisWeekHonor ~= 1) and lastPlayer.honor == thisWeekHonor and lastPlayer.name ~= inspectedPlayerName) then
		return
	end
	lastPlayer = {name = inspectedPlayerName, honor = thisWeekHonor}
    
    processInspect(player, inspectedPlayerName, todayHK, thisweekHK, thisWeekHonor, lastWeekHonor, standing, rankProgress)
    
	ClearInspectPlayer();
	NotifyInspect("target"); -- change real target back to player's target, broken by prev NotifyInspect call
	ClearInspectPlayer();
    
	inspectedPlayers[inspectedPlayerName] = {last_checked = player.last_checked};
	inspectedPlayerName = nil;
	if callback then
		callback()
		callback = nil
	end
end

local realmCache = {}
local function COMBAT_LOG_EVENT_UNFILTERED_EVENT(e)
    if not UnitIsPVP("player") then return end
    
    local _, _, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
    if destGUID == nil or destGUID == "" or destGUID == " " then return end
    
    local _, _, _, _, _, name, realm = GetPlayerInfoByGUID(destGUID)
    if not name then return end
    
    realmCache[name] = realm
end

-- parse message
-- COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)";
-- COMBATLOG_HONORAWARD = "You have been awarded %d honor points.";
local function parseHonorMessage(msg)
	local honor_gain_pattern = string.gsub(COMBATLOG_HONORGAIN, "%(", "%%(")
	honor_gain_pattern = string.gsub(honor_gain_pattern, "%)", "%%)")
	honor_gain_pattern = string.gsub(honor_gain_pattern, "(%%s)", "(.+)")
	honor_gain_pattern = string.gsub(honor_gain_pattern, "(%%d)", "(%%d+)")
    local victim, rank, est_honor = msg:match(honor_gain_pattern)
    if (victim) then
        if not victim:find("-") then
            if realmCache[victim] and realmCache[victim] ~= "" and realmCache[victim] ~= GetRealmName() then
                victim = victim.."-"..realmCache[victim]
            end
        end
    	est_honor = math.max(0, math.floor(est_honor * (1-0.10*((HonorSpy.db.char.today_kills[victim] or 1)-1)) + 0.5))
    end

    local honor_award_pattern = string.gsub(COMBATLOG_HONORAWARD, "(%%d)", "(%%d+)")
    local awarded_honor = msg:match(honor_award_pattern)
    return victim, est_honor, awarded_honor
end

-- this is called before filter
local function CHAT_MSG_COMBAT_HONOR_GAIN_EVENT(e, msg)
	local victim, _, awarded_honor = parseHonorMessage(msg)
    if victim then
        HonorSpy.db.char.today_kills[victim] = (HonorSpy.db.char.today_kills[victim] or 0) + 1
        local _, est_honor = parseHonorMessage(msg)
        HonorSpy.db.char.estimated_honor = HonorSpy.db.char.estimated_honor + est_honor
    elseif awarded_honor then
        HonorSpy.db.char.estimated_honor = HonorSpy.db.char.estimated_honor + awarded_honor
    end
end

-- this is called after eventg	ww
local function CHAT_MSG_COMBAT_HONOR_GAIN_FILTER(_s, e, msg, ...)
	local victim, est_honor, awarded_honor = parseHonorMessage(msg)
	C_Timer.After(1, HonorSpy.CheckNeedReset) -- At this point, GetPVPSessionStats() hasn't always yet updated with the new HK
	if (not victim) then
		return
	end
	return false, format("%s kills: %d, honor: |cff00FF96%d", msg, HonorSpy.db.char.today_kills[victim] or 0, est_honor), ...
end

-- INSPECT HOOKS pausing to not mess with native inspect calls
-- pause when use opens target right click menu, as it breaks "inspect" button sometimes
function HonorSpy:UnitPopup_ShowMenu(s, menu, frame, name, id)
	if (menu == "PLAYER" and not self:IsHooked(_G["DropDownList1"], "OnHide")) then
			self:SecureHookScript(_G["DropDownList1"], "OnHide", "CloseDropDownMenu")
			paused = true
		return
	end
end
function HonorSpy:CloseDropDownMenu()
	self:Unhook(_G["DropDownList1"], "OnHide")
	paused = false
end
-- pause when use opens inspect frame
function HonorSpy:InspectUnit(unitID)
	paused = true;
	if (not self:IsHooked(InspectFrame, "OnHide")) then
		self:SecureHookScript(InspectFrame, "OnHide", "InspectFrameClose");
	end
end
function HonorSpy:InspectFrameClose()
	paused = false;
end

-- INSPECTION TRIGGERS
function HonorSpy:UPDATE_MOUSEOVER_UNIT()
	StartInspecting("mouseover")
end
function HonorSpy:PLAYER_TARGET_CHANGED()
	StartInspecting("target")
end

function HonorSpy:UpdatePlayerData(cb)
	if (paused) then 
		return
	end
	callback = cb
	StartInspecting("player")
end

-- CHAT COMMANDS
local options = {
	name = 'HonorSpy',
	type = 'group',
	args = {
		show = {
			type = 'execute',
			name = L['Show HonorSpy Standings'],
			desc = L['Show HonorSpy Standings'],
			func = function() HonorSpyGUI:Toggle() end
		},
		search = {
			type = 'input',
			name = L['Report specific player standings'],
			desc = L['Report specific player standings'],
			usage = L['player_name'],
			get = false,
			set = function(info, playerName) HonorSpy:Report(HonorSpyUtils:getCompleteName(playerName)) end
		},
		pool = {
			type = 'input',
			name = L['Poolsize'],
			desc = L['Set the number of boosted character in the pool'],
			usage = L['Number of booster character in the pool'],
			pattern = "%d",
			get = false,
			set = function(info, count)
				HonorSpy.db.factionrealm.poolBoost = tonumber(count)
			end
		},
	}
}
LibStub("AceConfig-3.0"):RegisterOptionsTable("HonorSpy", options, {"honorspy", "hs"})

-- See GUI.lua for sort_column possible values
function HonorSpy:BuildStandingsTable(sort_column)
	local t = { }
	for playerName, player in pairs(HonorSpy.db.factionrealm.currentStandings) do
		table.insert(
			t,
			{
				playerName,
				player.class,
				tonumber(player.thisWeekHonor) or 0,
				tonumber(player.estHonor) or "",
				tonumber(player.lastWeekHonor) or 0,
				tonumber(player.standing) or 0,
				player.RP or 0,
				player.rank or 0,
				player.last_checked or 0
			}
		)
	end

	if (nil == sort_column) then
		sort_column = HonorSpy.sortColumns.honor;
	end

	local sort_func = function(a,b)
		local a3 = a[3] or 0
		local a4 = tonumber(a[4]) or 0
		local b3 = b[3] or 0
		local b4 = tonumber(b[4]) or 0
        if sort_column == HonorSpy.sortColumns.name then return a[1] < b[1] end
		if sort_column == HonorSpy.sortColumns.estimatedTodayHonor then
            local c = a4-a3
            if c < 0 then c = 0 end
            local d = b4-b3
            if d < 0 then d = 0 end
            return c > d 
        end
        if sort_column == HonorSpy.sortColumns.estimatedWeekHonor then
            local c = a4-a3
            if c < 0 then
                c = a3
            else
                c = a4
            end
            local d = b4-b3
            if d < 0 then
                d = b3
            else
                d = b4
            end
            return c > d
        end
        if sort_column == HonorSpy.sortColumns.lastWeekHonor then
            if a[5] == b[5] then
                return a[6] < b[6]
            end
        end
        if sort_column == HonorSpy.sortColumns.standing then
            if a[6] == 0 or b[6] == 0 then
                return a[5] > b[5]
            end
            return a[6] < b[6]
        end
		return a[sort_column] > b[sort_column]
	end
	table.sort(t, sort_func)

	return t
end

-- REPORT
function HonorSpy:GetPoolBoostCount()
	-- estimates pool boost to the date (as final pool boost should be only achieved at the end of the week)
	if (HonorSpy.db.factionrealm.spreadPoolBoostOverWeek) then
		return  math.floor((GetServerTime() - HonorSpy.db.char.last_reset) / (7*24*60*60) * (HonorSpy.db.factionrealm.poolBoost or 0)+.5)
	end

	return HonorSpy.db.factionrealm.poolBoost
end

function HonorSpy:GetBrackets(pool_size)
			  -- 1   2       3      4	  5		 6		7	   8		9	 10		11		12		13	14
	local brk =  {1, 0.845, 0.697, 0.566, 0.436, 0.327, 0.228, 0.159, 0.100, 0.060, 0.035, 0.020, 0.008, 0.003} -- brackets percentage
	
	pool_size = pool_size + HonorSpy:GetPoolBoostCount()

	if (not pool_size) then
		return brk
	end
	for i = 1,14 do
		brk[i] = math.floor(brk[i]*pool_size+.5)
	end
	return brk
end

function HonorSpy:Estimate(playerOfInterest)
	if (not playerOfInterest) then
		playerOfInterest = playerName
	end

	local standing = -1;
	local t = HonorSpy:BuildStandingsTable(HonorSpy.sortColumns.estimatedWeekHonor)
	local pool_size = #t;
	local curHonor = 0;
	local rp_factor = 1000;
	local decay_factor = 0.8;

	for i = 1, pool_size do
		if (playerOfInterest == t[i][1]) then
			standing = i
			curHonor = math.max(t[i][3], tonumber(t[i][4]) or 0)
		end
	end
	if (standing == -1) then
		return
	end;

	local RP  = {0, 400} -- RP for each bracket
	local Ranks = {0, 2000} -- RP for each rank
	local bracket = 1;
	local inside_br_progress = 0;
	local brk = self:GetBrackets(pool_size)
	
	-- change rank 2 and rp_factor if season of mastery
	if (HonorSpy.db.factionrealm.isSom == true) then
		RP[2] = 800
		rp_factor = 2000
		decay_factor = 0.6
	end
	
	for i = 2,14 do
		if (standing > brk[i]) then
			break
		end
		bracket = i;
	end

	local bracketEnd = brk[bracket]
	if (brk[bracket] > #t) then bracketEnd = #t end	
	local btm_break_point_honor = math.max(t[bracketEnd][3], tonumber(t[bracketEnd][4]) or 0)
	local top_break_point_honor = 0
	if brk[bracket + 1] and t[brk[bracket + 1]] then -- do we even have next bracket?
		top_break_point_honor = math.max(t[brk[bracket + 1]][3], tonumber(t[brk[bracket + 1]][4]) or 0)
	else
		top_break_point_honor = math.max(t[1][3], tonumber(t[1][4]) or 0)
	end
	if curHonor == top_break_point_honor then
		inside_br_progress = 1
	else
		inside_br_progress = (curHonor - btm_break_point_honor)/(top_break_point_honor - btm_break_point_honor)
	end

	for i = 3,14 do
		RP[i] = (i-2) * rp_factor
		Ranks[i] = (i-2) * 5000
	end
	local award = RP[bracket] + rp_factor * inside_br_progress;
	local RP = HonorSpy.db.factionrealm.currentStandings[playerOfInterest].RP;
	local EstRP = math.floor(RP*decay_factor+award+.5);
	--Max 2500 RP per week decay.  Applies to Classic Era and Season of Mastery
	if ((RP-EstRP) > 2500) then
		EstRP = RP - 2500
	end
	local Rank = HonorSpy.db.factionrealm.currentStandings[playerOfInterest].rank;
	local EstRank = 14;
	local Progress = math.floor(HonorSpy.db.factionrealm.currentStandings[playerOfInterest].rankProgress*100);
	local EstProgress = math.floor((EstRP - math.floor(EstRP/5000)*5000) / 5000*100);
	for i = 3,14 do
		if (EstRP < Ranks[i]) then
			EstRank = i-1;
			break;
		end
	end

	return pool_size, standing, bracket, RP, EstRP, Rank, Progress, EstRank, EstProgress
end

function HonorSpy:Report(playerOfInterest, skipUpdate)
	if (not playerOfInterest) then
		playerOfInterest = playerName
	end
	if (playerOfInterest == playerName) then
		HonorSpy:UpdatePlayerData() -- will update for next time, this report gonna be for old data
	end

	local pool_size, standing, bracket, RP, EstRP, Rank, Progress, EstRank, EstProgress = HonorSpy:Estimate(playerOfInterest)
	if (not standing) then
		self:Print(format(L["Player %s not found in table"], playerOfInterest));
		return
	end
	local text = "- HonorSpy: "
	if (playerOfInterest ~= playerName) then
		text = text .. format("%s <%s>: ", L['Progress of'], playerOfInterest)
	end
	text = text .. format("%s = %d, %s = %d, %s = %d, %s = %d (%d%%), %s = %d (%d%%)", L["Standing"], standing, L["Bracket"], bracket, L["Next Week RP"], EstRP, L["Rank"], Rank, Progress, L["Next Week Rank"], EstRank, EstProgress)
	SendChatMessage(text, "emote")
end

-- SYNCING --
function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

function HonorSpy:OnCommReceive(prefix, commMessage, distribution, sender)
	local sendersRealm = HonorSpyUtils:getRealmFromFullUnitName(sender)

	-- Do not process messages from the players himself
	if (HonorSpyUtils:getCompleteName(sender) == playerName) then return end

	if (distribution ~= "GUILD" and sendersRealm and HonorSpy.db.factionrealm.connectedRealms[sendersRealm] == nil) then
		return -- discard any message from players not from the same realm or connected realms (connected on ERA only)
	end

	-- Decompress message, reject if corrupted. No decode/decompress for yells
	local originalMessage = decodeDecompressAndCheckMessage(commMessage, distribution ~= "YELL")
	if (nil == originalMessage) then return end

	local ok, playerName, player = self:Deserialize(originalMessage);
	if (not ok) then
		return;
	end

	if (playerName == "filtered_players") then
		for playerName, player in pairs(player) do
			store_player(playerName, player);
		end
		return
	end
	store_player(playerName, player);
end

-- Broadcast on death
local last_send_time = 0;
function HonorSpy:PLAYER_DEAD()
	HonorSpy:broadcastPlayers(true)
end

function HonorSpy:broadcastPlayers(skipYell)
	local filtered_players, count = {}, 0;
	if (time() - last_send_time < 15*60) then return end;
	last_send_time = time();

	for playerName, player in pairs(self.db.factionrealm.currentStandings) do
		filtered_players[playerName] = player;
		count = count + 1;
		if (count == 10) then
			broadcast(self:Serialize("filtered_players", filtered_players), skipYell)
			filtered_players, count = {}, 0;
		end
	end
	if (count > 0) then
		broadcast(self:Serialize("filtered_players", filtered_players), skipYell)
	end
end

local function FAKE_PLAYERS_FILTER(_s, e, msg, ...)
	-- not found, fake
	if (msg == ERR_FRIEND_NOT_FOUND) then
		if (not nameToTest) then
			return true
		end

		-- We added a same server friend, but want to store it with the name-server format
		local name, realm = strsplit('-', nameToTest)
		if (realm == nil) then
			nameToTest = name .. '-' .. GetRealmName()
		end

		HonorSpy.db.factionrealm.currentStandings[nameToTest] = nil
		HonorSpy.db.factionrealm.fakePlayers[nameToTest] = true
		HonorSpy.db.factionrealm.goodPlayers[nameToTest] = nil
		-- HonorSpy:Print("removed non-existing player", nameToTest)
		nameToTest = nil
		return true
	end
	
	-- added or was in friends already, not fake
    local friend = msg:match(string.gsub(ERR_FRIEND_ADDED_S, "(%%s)", "(.+)"))
    if (not friend) then
    	friend = msg:match(string.gsub(ERR_FRIEND_ALREADY_S, "(%%s)", "(.+)"))
    end
	
    if (friend) then
		-- We added a same server friend, but want to store it with the name-server format
		local friendFullName = HonorSpyUtils:getCompleteName(friend)
		--HonorSpy:Print("Player '" .. friend .. "' is a valid player")
    	HonorSpy.db.factionrealm.goodPlayers[friendFullName] = true
    	HonorSpy.db.factionrealm.fakePlayers[friendFullName] = nil
		
    	if (friend == nameToTest) then
			local f = C_FriendList.GetFriendInfo(friend)
			if (f.notes == "HonorSpy testing") then
				C_FriendList.RemoveFriend(f.name)
			end
			f = nil;
			nameToTest = nil
			return true
    	end
    end
	
	friend = msg:match(ERR_FRIEND_ONLINE_PATTERN)
	if (friend) then
		local friendFullName = HonorSpyUtils:getCompleteName(friend)
		local f = C_FriendList.GetFriendInfo(friend)
		if(nameToTest and not f) then
			if (nameToTest == friend) then
				return true;
			end
		else
			if (f and (friend == nameToTest or f.notes == "HonorSpy testing")) then
				HonorSpy.db.factionrealm.goodPlayers[friendFullName] = true
				HonorSpy.db.factionrealm.fakePlayers[friendFullName] = nil
				return true;
			end
		end
		if (checkingPlayers) then
			PlaySoundFile(567518)
		end
	end
	
	friend = msg:match(ERR_FRIEND_ERROR)
	if (friend) then
		return true
	end	
end

function HonorSpy:removeTestedFriends()
	local limit = C_FriendList.GetNumFriends()
	if (type(limit) ~= "number") then
		return
	end
	for i = 1, limit do
		local f = C_FriendList.GetFriendInfoByIndex(i)
		if (f.notes == "HonorSpy testing") then
			C_FriendList.RemoveFriend(f.name)
		end
	end
end

function HonorSpy:TestNextFakePlayer()
	if (not startRemovingFakes) then
		return
	elseif (nameToTest) then
		checkingPlayers = true;
		return
	end
	
	checkingPlayers = true;
	last_test = time()
	
	for playerName, player in pairs(HonorSpy.db.factionrealm.currentStandings) do
		if (not HonorSpy.db.factionrealm.fakePlayers[playerName] and not HonorSpy.db.factionrealm.goodPlayers[playerName] and playerName ~= HonorSpyUtils:getFullUnitName("player")) then

			-- We strip the server suffix for same server friend testing
			local name, realm = strsplit("-", playerName)
			if (realm == GetRealmName()) then
				playerName = name
			end

			nameToTest = playerName
			break
		end
	end
	
	if (nameToTest) then
		MuteSoundFile(567518)
		C_FriendList.AddFriend(nameToTest, "HonorSpy testing")
		C_Timer.After(1,function () HonorSpy:TestNextFakePlayer() end)
	else
		HonorSpy:removeTestedFriends()
		checkingPlayers = false;
		UnmuteSoundFile(567518)
	end
end

-- RESET WEEK
function HonorSpy:Purge()
	inspectedPlayers = {};
	HonorSpy.db.factionrealm.currentStandings={};
	HonorSpy.db.factionrealm.fakePlayers={};
	HonorSpyGUI:Reset();
	HonorSpy:Print(L["All data was purged"]);
end

local function getResetTime()
	local currentUnixTime = GetServerTime()
	local regionId = GetCurrentRegion()
	local resetDay = 3 -- wed
	local resetHour = 7 -- 7 AM UTC

	if (regionId == 1) then -- US + BR + Oceania: 3 PM UTC Tue (7 AM PST Tue)
		resetDay = 2
		resetHour = 15
	elseif (regionId == 2) then -- Korea: 1 AM UTC Thu (10 AM KST Thu)
		resetDay = 4
		resetHour = 1
	elseif (regionId == 5) then -- China: 10 PM UTC Mon (7 AM KST Tue)
		resetDay = 1
		resetHour = 22
	elseif (regionId == 4) then -- Taiwan: 10 PM UTC Wed (7 AM KST Thu)
		resetDay = 3
		resetHour = 22
	elseif (regionId == 3) then -- EU + RU: 7 AM UTC Wed (7 AM UTC Wed)
	end

	local day = date("!%w", currentUnixTime);
	local h = date("!%H", currentUnixTime);
	local m = date("!%M", currentUnixTime);
	local s = date("!%S", currentUnixTime);

	local reset_seconds = resetDay*24*60*60 + resetHour*60*60 -- reset time in seconds from week start
	local now_seconds = s + m*60 + h*60*60 + day*24*60*60 -- seconds passed from week start
	
	local week_start = currentUnixTime - now_seconds
	local must_reset_on = 0

	if (now_seconds - reset_seconds > 0) then -- we passed this week reset time
		must_reset_on = week_start + reset_seconds
	else -- we not yet passed the reset moment in this week, still on prev week reset time
		must_reset_on = week_start - 7*24*60*60 + reset_seconds
	end

	return must_reset_on
end

function HonorSpy:ResetWeek()
	HonorSpy:Purge()
	HonorSpy:Print(L["Weekly data was reset"]);
end

function HonorSpy:CheckNeedReset(skipUpdate)
	if (not skipUpdate) then
		HonorSpy:UpdatePlayerData(function() HonorSpy:CheckNeedReset(true) end)
	end

	-- reset weekly standings
	local must_reset_on = getResetTime()
    
    -- Reset the rest of the database only if it hasn't already been done on an alt this week
    if (HonorSpy.db.factionrealm.last_reset ~= must_reset_on) then
        HonorSpy.db.factionrealm.last_reset = must_reset_on
    	HonorSpy:ResetWeek()
    end
    
    --[[
        There are a few different use cases around players daily and weekly honor resetting:
        1. 
            Player earns honor on day 1.
            On day 2 the player logs in and their honor has rolled over into "yesterday" and "this week", and their "today" honor has reset back to zero.
            On day 3 is the Tuesday/Wednesday reset and the player logs in, their "this week" honor has rolled over into "last week", and their "today" and "this week" honor has reset back to zero.
        2.
            Player earns honor on day 1.
            On day 2 the nightly calculation never worked, the honor they earned the day before is still under "today" unchanged, same with "this week".
            On day 3 the Tuesday/Wednesday reset happens and their honor catches up, rolls over into "last week", and their "today" and "this week" honor has reset back to zero.
        3.
            Player earns honor on day 1.
            On day 2 the nightly calculation fails. "this week" is still zero.
            On day 3 the weekly calculation fails. The player still has all the honor they earned the week before under "today" and "this week" still says zero.
        4.
            As with (3) except the nightly calculation succeeds instead of the weekly calculation. The players "today" honor moves into "this week".
            
        -- this algorithm fails scenario (3). That scenario is at least the rarest issue, so may just have to tolerate it.
    --]]
    
	-- reset daily honor
	local _, thisWeekHonor = GetPVPThisWeekStats()
    if (HonorSpy.db.char.original_honor ~= thisWeekHonor) or (HonorSpy.db.char.last_reset ~= must_reset_on) then
        HonorSpy.db.char.last_reset = must_reset_on
        HonorSpy.db.char.original_honor = thisWeekHonor
        HonorSpy.db.char.estimated_honor = thisWeekHonor
		HonorSpy.db.char.today_kills = {}
	end
end

-- Minimap icon
local function DrawMinimapIcon()
	LibStub("LibDBIcon-1.0"):Register("HonorSpy", LibStub("LibDataBroker-1.1"):NewDataObject("HonorSpy",
	{
		type = "data source",
		text = addonName,
		icon = "Interface\\Icons\\Inv_Misc_Bomb_04",
		OnClick = function(self, button) 
			if (button == "RightButton") then
				HonorSpy:Report()
			elseif (button == "MiddleButton") then
				HonorSpy:Report(UnitIsPlayer("target") and HonorSpyUtils:getFullUnitName("target") or nil)
			else 
				HonorSpy:CheckNeedReset()
				HonorSpyGUI:Toggle()
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddDoubleLine(format("%s", addonName), format("|cff777777v%s", GetAddOnMetadata(addonName, "Version")));
			tooltip:AddLine("|cff777777by Kakysha|r");
			tooltip:AddLine("|cFFCFCFCFLeft Click: |r" .. L['Show HonorSpy Standings']);
			tooltip:AddLine("|cFFCFCFCFMiddle Click: |r" .. L['Report Target']);
			tooltip:AddLine("|cFFCFCFCFRight Click: |r" .. L['Report Me']);
		end
	}), HonorSpy.db.factionrealm.minimapButton);
end

local function PrintWelcomeMsg()
	local realm = GetRealmName()
	local faction = UnitFactionGroup("player")
	local msg = format("|cffAAAAAAversion: %s, bugs & features: github.com/kakysha/honorspy|r\n|cff209f9b", GetAddOnMetadata(addonName, "Version"))
	if (realm == "Earthshaker" and faction == "Horde") then
		msg = msg .. format("You are lucky enough to play with an HonorSpy author on |cffFFFFFF%s |cff209f9brealm! Feel free to mail me (|cff8787edKakysha|cff209f9b) a supportive %s  tip or kind word!", realm, GetCoinTextureString(50000))
	end
	HonorSpy:Print(msg .. "|r")
end

local waitTable = {};
local waitFrame = nil;
local function HS_wait(delay, func, ...)
  if(type(delay)~="number" or type(func)~="function") then
	return false;
  end
  if(waitFrame == nil) then
	waitFrame = CreateFrame("Frame","WaitFrame", UIParent);
	waitFrame:SetScript("onUpdate",function (self,elapse)
	  local count = #waitTable;
	  local i = 1;
	  while(i<=count) do
		local waitRecord = tremove(waitTable,i);
		local d = tremove(waitRecord,1);
		local f = tremove(waitRecord,1);
		local p = tremove(waitRecord,1);
		if(d>elapse) then
		  tinsert(waitTable,i,{d-elapse,f,p});
		  i = i + 1;
		else
		  count = count - 1;
		  f(unpack(p));
		end
	  end
	end);
  end
  tinsert(waitTable,{delay,func,{...}});
  return true;
end

local function DBHealthCheck()
	for playerName, player in pairs(HonorSpy.db.factionrealm.currentStandings) do
		if (not playerIsValid(player)) then
			HonorSpy.db.factionrealm.currentStandings[playerName] = nil
			HonorSpy:Print("removed bad table row", playerName)
		end
	end

	if (HonorSpy.db.factionrealm.actualCommPrefix ~= commPrefix) then
		HonorSpy:Purge()
		HonorSpy.db.factionrealm.actualCommPrefix = commPrefix
	end

	HonorSpy:removeTestedFriends()
	HS_wait(5, function() startRemovingFakes = true; HonorSpy:TestNextFakePlayer(); end)
end

function HonorSpy:CombineConnectedRealms()
    local currentRealm = GetRealmName()
    local connectedRealms = HonorSpy.db.factionrealm.connectedRealms -- {["Felstriker"] = true, ["Yojamba"] = true,}
    local currentfactionrealm = HonorSpyDB.factionrealm[UnitFactionGroup("player").." - "..currentRealm].currentStandings
    
    for connectedRealm in pairs(connectedRealms) do
        if HonorSpyDB.factionrealm[UnitFactionGroup("player").." - "..connectedRealm] then
            local connectedfactionrealm = HonorSpyDB.factionrealm[UnitFactionGroup("player").." - "..connectedRealm].currentStandings
        
            for namerealm, data in pairs(connectedfactionrealm) do
                if namerealm:find("%-") then 
                    local _, _, name, realm = namerealm:find("(%a+)%-(%a+)")
                    if not realm or realm == "" or not name or name == "" then print("error 1") return end
                    if realm == currentRealm then
                        -- Example here: Player is from Arugal, message is from Felstriker, about a character on Arugal
                        -- Lets just remove the bit about Arugal
                        namerealm = name
                        -- If the realm name does not match: Player is from Arugal, message is from Felstriker, about a character on Yojamba
                        -- In this case just allow it as is
                    end
                else
                    -- Example here: Player is from Arugal, message is from Felstriker, about a character on Felstriker
                    -- Add "-Felstriker" to the name
                    namerealm = namerealm.."-"..connectedRealm
                end
                
                local exists = false
                for namerealm2, data2 in pairs(currentfactionrealm) do
                    if namerealm == namerealm2 then
                        if data.last_checked < data2.last_checked then
                            currentfactionrealm[namerealm] = data2
                        end
                        exists = true
                        break
                    end
                end
                
                if not exists then
                    currentfactionrealm[namerealm] = data
                end
            end
        end
    end
end

function HonorSpy:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("HonorSpyDB", {
		factionrealm = {
			currentStandings = {},
			last_reset = 0,
			minimapButton = {hide = false},
			estHonorCol = {show = false},
            estTodayHonorCol = {show = false},
			actualCommPrefix = "",
			fakePlayers = {},
			goodPlayers = {},
			poolBoost = 0,
			spreadPoolBoostOverWeek = true,
			isSom = false,
			som_Checked = false,
            connectedRealms = {},
		},
		char = {
			today_kills = {},
			estimated_honor = 0,
			original_honor = 0,
			last_reset = 0,
		}
	}, true)
	
	som_realm = C_Seasons.HasActiveSeason();
	
	if (not self.db.factionrealm.som_Checked) then
		self.db.factionrealm.isSom = som_realm;
		self.db.factionrealm.som_Checked = true;
	end
	
	self:SecureHook("InspectUnit");
	self:SecureHook("UnitPopup_ShowMenu");

	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	self:RegisterEvent("INSPECT_HONOR_UPDATE");
	self:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_EVENT);
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", COMBAT_LOG_EVENT_UNFILTERED_EVENT);
	ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_FILTER);
	self:RegisterComm(commPrefix, "OnCommReceive")
	self:RegisterEvent("PLAYER_DEAD");
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FAKE_PLAYERS_FILTER);

	DrawMinimapIcon();
	HS_wait(5, function() HonorSpy:CheckNeedReset() end)
	HonorSpyGUI:PrepareGUI()
	PrintWelcomeMsg();
	DBHealthCheck()

	C_Timer.NewTicker(60*60, function()
		-- Do not broadcast if player is busy to not interfere with more important addon comms
		if(not IsInInstance() and not InCombatLockdown()) then
			HonorSpy:broadcastPlayers(true)
		end
	end)
end