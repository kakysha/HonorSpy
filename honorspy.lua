HonorSpy = LibStub("AceAddon-3.0"):NewAddon("HonorSpy", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("HonorSpy", true)

local addonName = GetAddOnMetadata("HonorSpy", "Title");
local commPrefix = addonName .. "2";

local paused = false; -- pause all inspections when user opens inspect frame
local playerName = UnitName("player");
local callback = nil
local syncChannelID = 0

function HonorSpy:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("HonorSpyDB", {
		factionrealm = {
			currentStandings = {},
			last_reset = 0,
			reset_day = 3,
			sort = L["Honor"],
			minimapButton = {hide = false},
			syncOverGuild = false
		},
		char = {
			today_kills = {
				['*'] = 0
			},
			estimated_honor = 0,
			original_honor = 0
		}
	}, true)

	self:SecureHook("InspectUnit");
	self:SecureHook("UnitPopup_ShowMenu");

	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");

	self:RegisterEvent("INSPECT_HONOR_UPDATE");
	ChatFrame_AddMessageEventFilter("CHAT_MSG_COMBAT_HONOR_GAIN", CHAT_MSG_COMBAT_HONOR_GAIN_HANDLER)

	self:RegisterComm(commPrefix, "OnCommReceive")

	self:RegisterEvent("PLAYER_DEAD");

	DrawMinimapIcon();
	HonorSpy:CheckNeedReset();

	HonorSpyGUI:PrepareGUI()
	PrintWelcomeMsg();

	HonorSpy:UpdatePlayerData()
	checkDailyReset()

	if (not HonorSpy.db.factionrealm.syncOverGuild) then
		HS_wait(5, HS_joinSyncChannel)
	end
end

local inspectedPlayers = {}; -- stores last_checked time of all players met
local inspectedPlayerName = nil; -- name of currently inspected player

local function StartInspecting(unitID)
	local name, realm = UnitName(unitID);
	if (paused or realm) then
		return
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

function HonorSpy:INSPECT_HONOR_UPDATE()
	if (inspectedPlayerName == nil or paused or not HasInspectHonorData()) then
		return;
	end

	local player = self.db.factionrealm.currentStandings[inspectedPlayerName] or inspectedPlayers[inspectedPlayerName];
	if (player.class == nil) then player.class = "nil" end

	local _, _, _, _, thisweekHK, thisWeekHonor, _, lastWeekHonor, standing = GetInspectHonorData();
	player.thisWeekHonor = thisWeekHonor;
	player.lastWeekHonor = lastWeekHonor;
	player.standing = standing;

	player.rankProgress = GetInspectPVPRankProgress();
	ClearInspectPlayer();
	NotifyInspect("target"); -- change real target back to player's target, broken by prev NotifyInspect call
	ClearInspectPlayer();
	
	player.last_checked = GetServerTime();
	player.RP = 0;

	if (thisweekHK >= 15) then
		if (player.rank >= 3) then
			player.RP = math.ceil((player.rank-2) * 5000 + player.rankProgress * 5000)
		elseif (player.rank == 2) then
			player.RP = math.ceil(player.rankProgress * 3000 + 2000)
		end
		if (lastPlayer and lastPlayer.honor == thisWeekHonor and lastPlayer.name ~= inspectedPlayerName) then
			return
		end
		lastPlayer = {name = inspectedPlayerName, honor = thisWeekHonor}
		self.db.factionrealm.currentStandings[inspectedPlayerName] = player;
		broadcast(self:Serialize(inspectedPlayerName, player))
	end
	inspectedPlayers[inspectedPlayerName] = {last_checked = player.last_checked};
	inspectedPlayerName = nil;
	if callback then
		callback()
		callback = nil
	end
end

local last_msg_id = 0
function CHAT_MSG_COMBAT_HONOR_GAIN_HANDLER(_s, e, msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, id, ...)
	if (id == last_msg_id) then
		return nil, msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, id, ...-- due to the bug, this chat filter is called twice
	end
	last_msg_id = id
	checkDailyReset()
	local victim, est_honor = msg:match("([^%s]+) dies, honorable kill Rank: %w+ %(Estimated Honor Points: (%d+)%)")
	if (victim) then
		if (not HonorSpy.db.char.today_kills[victim]) then
			HonorSpy.db.char.today_kills[victim] = 0
		end
		est_honor = math.floor(est_honor * (1-0.25*HonorSpy.db.char.today_kills[victim]) + 0.5)
		HonorSpy.db.char.today_kills[victim] = HonorSpy.db.char.today_kills[victim]+1
		HonorSpy.db.char.estimated_honor = HonorSpy.db.char.estimated_honor+est_honor

		last_killed = {name = victim, ts = time()}
		return nil, msg .. format(" kills: %d, honor:|cff00FF96%d", HonorSpy.db.char.today_kills[victim], est_honor), arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, id, ...
	end
	local awarded_honor = msg:match("You have been awarded %d+ honor.")
	if (awarded_honor) then
		handler_invocation_ts = time()
		HonorSpy.db.char.estimated_honor = HonorSpy.db.char.estimated_honor+awarded_honor
		return nil, msg, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, id, ...
	end
end

function checkDailyReset()
	if (not HonorSpy.db.factionrealm.currentStandings[playerName] or HonorSpy.db.char.original_honor == HonorSpy.db.factionrealm.currentStandings[playerName].thisWeekHonor) then
		return
	end
	HonorSpy.db.char.original_honor = HonorSpy.db.factionrealm.currentStandings[playerName].thisWeekHonor
	HonorSpy.db.char.estimated_honor = HonorSpy.db.char.original_honor
	HonorSpy.db.char.today_kills = {}

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
			set = function(info, playerName) HonorSpy:Report(playerName) end
		},
	}
}
LibStub("AceConfig-3.0"):RegisterOptionsTable("HonorSpy", options, {"honorspy", "hs"})

function HonorSpy:BuildStandingsTable()
	local t = { }
	for playerName, player in pairs(HonorSpy.db.factionrealm.currentStandings) do
		table.insert(t, {playerName, player.class, player.thisWeekHonor or 0, player.lastWeekHonor or 0, player.standing or 0, player.RP or 0, player.rank or 0, player.last_checked or 0})
	end
	
	local sort_column = 3; -- ThisWeekHonor
	if (HonorSpy.db.factionrealm.sort == L["Rank"]) then sort_column = 6; end
	table.sort(t, function(a,b)
		return a[sort_column] > b[sort_column]
	end)

	return t
end

-- REPORT
function HonorSpy:GetBrackets(pool_size)
			  -- 1   2       3      4	  5		 6		7	   8		9	 10		11		12		13	14
	local brk =  {1, 0.858, 0.715, 0.587, 0.477, 0.377, 0.287, 0.207, 0.137, 0.077, 0.037, 0.017, 0.007, 0.002} -- brackets percentage
	
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
	playerOfInterest = string.utf8upper(string.utf8sub(playerOfInterest, 1, 1))..string.utf8lower(string.utf8sub(playerOfInterest, 2))

	
	local standing = -1;
	local t = HonorSpy:BuildStandingsTable()
	local avg_lastchecked = 0;
	local pool_size = #t;

	for i = 1, pool_size do
		if (playerOfInterest == t[i][1]) then
			standing = i
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

	for i = 2,14 do
		if (standing > brk[i]) then
			inside_br_progress = (brk[i-1] - standing)/(brk[i-1] - brk[i])
			break
		end;
		bracket = i;
	end
	if (bracket == 14 and standing == 1) then inside_br_progress = 1 end;
	for i = 3,14 do
		RP[i] = (i-2) * 1000;
		Ranks[i] = (i-2) * 5000;
	end
	local award = RP[bracket] + 1000 * inside_br_progress;
	local RP = HonorSpy.db.factionrealm.currentStandings[playerOfInterest].RP;
	local EstRP = math.floor(RP*0.8+award+.5);
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
	playerOfInterest = string.utf8upper(string.utf8sub(playerOfInterest, 1, 1))..string.utf8lower(string.utf8sub(playerOfInterest, 2))
	
	local pool_size, standing, bracket, RP, EstRP, Rank, Progress, EstRank, EstProgress = HonorSpy:Estimate(playerOfInterest)
	if (not standing) then
		self:Print(format(L["Player %s not found in table"], playerOfInterest));
		return
	end
	if (playerOfInterest ~= playerName) then
		SendChatMessage(format("- HonorSpy: %s %s", L["Report for player"], playerOfInterest),"emote")
	end
	SendChatMessage(format("- HonorSpy: %s = %d, %s = %d, %s = %d, %s = %s, %s = %d", L["Pool Size"], pool_size, L["Standing"], standing, L["Bracket"], bracket, L["Current RP"], RP, L["Next Week RP"], EstRP), "emote")
	SendChatMessage(format("- HonorSpy: %s = %d (%d%%), %s = %d (%d%%)", L["Current Rank"], Rank, Progress, L["Next Week Rank"], EstRank, EstProgress), "emote")
end

-- SYNCING --
function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

function store_player(playerName, player)
	if (player == nil) then return end
	
	if (player.last_checked < HonorSpy.db.factionrealm.last_reset
		or player.last_checked > GetServerTime()
		or player.thisWeekHonor == 0
		) then
		return
	end
	
	local player = table.copy(player);
	local localPlayer = HonorSpy.db.factionrealm.currentStandings[playerName];
	if (localPlayer == nil or localPlayer.last_checked < player.last_checked) then
		HonorSpy.db.factionrealm.currentStandings[playerName] = player;
	end
end

function HonorSpy:OnCommReceive(prefix, message, distribution, sender)
	if (distribution == "BATTLEGROUND" and UnitRealmRelationship(sender) ~= 1) then
		return -- discard any message from players from different servers (on x-realm BGs)
	end
	local ok, playerName, player = self:Deserialize(message);
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

function HS_joinSyncChannel()
	local channelName = "HonorSpySync"
	if (GetChannelName(channelName) == 0) then
		JoinTemporaryChannel("hstemp1")
		JoinTemporaryChannel("hstemp2")
		JoinTemporaryChannel(channelName)
		HS_wait(1, LeaveChannelByName, "hstemp1")
		HS_wait(1, LeaveChannelByName, "hstemp2")
	end
	syncChannelID = GetChannelName(channelName)
end

function broadcast(msg)
	if (UnitInBattleground("player") ~= nil) then
		HonorSpy:SendCommMessage(commPrefix, msg, "BATTLEGROUND");
	else
		HonorSpy:SendCommMessage(commPrefix, msg, "RAID");
	end
	if (syncChannelID > 0) then
		HonorSpy:SendCommMessage(commPrefix, msg, "CHANNEL", syncChannelID);
	elseif (GetGuildInfo("player") ~= nil) then
		HonorSpy:SendCommMessage(commPrefix, msg, "GUILD");
	end
end

-- Broadcast on death
local last_send_time = 0;
function HonorSpy:PLAYER_DEAD()
	local filtered_players, count = {}, 0;
	if (GetServerTime() - last_send_time < 5*60) then return end;
	last_send_time = GetServerTime();

	for playerName, player in pairs(self.db.factionrealm.currentStandings) do
		filtered_players[playerName] = player;
		count = count + 1;
		if (count == 10) then
			broadcast(self:Serialize("filtered_players", filtered_players))
			filtered_players, count = {}, 0;
		end
	end
	if (count > 0) then
		broadcast(self:Serialize("filtered_players", filtered_players))
	end
end

-- RESET WEEK
function HonorSpy:Purge()
	inspectedPlayers = {};
	HonorSpy.db.factionrealm.currentStandings={};
	HonorSpyGUI:Reset();
	HonorSpy:Print(L["All data was purged"]);
end
function resetWeek(must_reset_on)
	HonorSpy.db.factionrealm.last_reset = must_reset_on;
	HonorSpy:Purge()
	HonorSpy:Print(L["Weekly data was reset"]);
end
function HonorSpy:CheckNeedReset()
	checkDailyReset()
	local day = date("!%w", GetServerTime());
	local h = date("!%H", GetServerTime());
	local m = date("!%M", GetServerTime());
	local s = date("!%S", GetServerTime());
	local days_diff = (7 + (day - HonorSpy.db.factionrealm.reset_day)) - math.floor((7 + (day - HonorSpy.db.factionrealm.reset_day))/7) * 7;
	local diff_in_seconds = s + m*60 + h*60*60 + days_diff*24*60*60 - 10*60*60 - 1; -- 10 AM UTC - fixed hour of PvP maintenance
	if (diff_in_seconds > 0) then -- it is negative on reset_day untill 10AM
		local must_reset_on = GetServerTime()-diff_in_seconds;
		if (must_reset_on > HonorSpy.db.factionrealm.last_reset) then resetWeek(must_reset_on) end
	end
end

-- Minimap icon
function DrawMinimapIcon()
	LibStub("LibDBIcon-1.0"):Register("HonorSpy", LibStub("LibDataBroker-1.1"):NewDataObject("HonorSpy",
	{
		type = "data source",
		text = addonName,
		icon = "Interface\\Icons\\Inv_Misc_Bomb_04",
		OnClick = function(self, button) 
			if (button == "RightButton") then
				HonorSpy:Report()
			elseif (button == "MiddleButton") then
				HonorSpy:Report(UnitIsPlayer("target") and UnitName("target") or nil)
			else 
				HonorSpy:CheckNeedReset()
				HonorSpyGUI:Toggle()
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(format("%s", addonName));
			tooltip:AddLine("|cff777777by Kakysha|r");
			tooltip:AddLine("|cFFCFCFCFLeft Click: |r" .. L['Show HonorSpy Standings']);
			tooltip:AddLine("|cFFCFCFCFMiddle Click: |r" .. L['Report Target']);
			tooltip:AddLine("|cFFCFCFCFRight Click: |r" .. L['Report Me']);
		end
	}), HonorSpy.db.factionrealm.minimapButton);
end

function PrintWelcomeMsg()
	local realm = GetRealmName()
	local faction = UnitFactionGroup("player")
	local msg = format("|cffAAAAAAversion: %s, bugs & features: github.com/kakysha/honorspy|r\n|cff209f9b", GetAddOnMetadata("HonorSpy", "Version"))
	if (realm == "Flamelash" and faction == "Horde") then
		msg = msg .. format("You are lucky enough to play with HonorSpy author on one |cffFFFFFF%s |cff209f9brealm! Feel free to mail me (|cff8787edKakysha|cff209f9b) a supportive gold tip or kind word!", realm)
	end
	HonorSpy:Print(msg .. "|r")
end

local waitTable = {};
local waitFrame = nil;
function HS_wait(delay, func, ...)
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