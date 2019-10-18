HonorSpy = LibStub("AceAddon-3.0"):NewAddon("HonorSpy", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("HonorSpy", true)

local addonName = GetAddOnMetadata("HonorSpy", "Title");
local commPrefix = addonName;

local VERSION = 1;
local paused = false; -- pause all inspections when user opens inspect frame
local playerName = UnitName("player");
local playerIsInGuild = GetGuildInfo("player") ~= nil
local callback = nil

function HonorSpy:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HonorSpyDB", {
    	factionrealm = {
			currentStandings = {},
			last_reset = 0,
			reset_day = 3,
			sort = L["Honor"],
			limit = 750,
			minimapButton = {hide = false}
    	}
	}, true)

	self:SecureHook("InspectUnit");

	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");

	self:RegisterEvent("INSPECT_HONOR_UPDATE");

	self:RegisterComm(commPrefix, "OnCommReceive")

	self:RegisterEvent("PLAYER_DEAD");

	DrawMinimapIcon();
	HonorSpy:CheckNeedReset();

	HonorSpyGUI:PrepareGUI()
end

local inspectedPlayers = {}; -- stores last_checked time of all players met
local inspectedPlayerName = nil; -- name of currently inspected player

local function StartInspecting(unitID)
	local name, realm = UnitName(unitID);
	if (realm) then
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
	if (inspectedPlayerName == nil or paused) then
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

-- INSPECT HOOKS pausing to not mess with native inspect calls
local hooked = false;
function HonorSpy:InspectUnit(unitID)
	paused = true;
	if (not hooked) then
		self:SecureHookScript(InspectFrame, "OnHide");
		hooked = true;
	end
end
function HonorSpy:OnHide()
	paused = false;
end

-- INSPECTION TRIGGERS
function HonorSpy:UPDATE_MOUSEOVER_UNIT()
	if (not paused) then StartInspecting("mouseover") end
end
function HonorSpy:PLAYER_TARGET_CHANGED()
	if (not paused) then StartInspecting("target") end
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

-- REPORT
function HonorSpy:Estimate(playerOfInterest)
	if (not playerOfInterest) then
		playerOfInterest = playerName
	end
	playerOfInterest = string.upper(string.sub(playerOfInterest, 1, 1))..string.lower(string.sub(playerOfInterest, 2))

	local pool_size = 0;
	local standing = -1;
	local t = HonorSpyGUI:BuildStandingsTable()
	local avg_lastchecked = 0;
	pool_size = table.getn(t);
	for i = 1, table.getn(t) do
		if (playerOfInterest == t[i][1]) then
			standing = i
		end
	end
	if (standing == -1) then
		return
	end;
			  -- 1   2     3      4		 5		 6		7		8		9	10		11		12		13	14
	local brk = {1, 0.858, 0.715, 0.587, 0.477, 0.377, 0.287, 0.207, 0.137, 0.077, 0.037, 0.017, 0.007, 0.002} -- brackets percentage
	local RP  = {0, 400} -- RP for each bracket
	local Ranks = {0, 2000} -- RP for each rank

	local bracket = 1;
	local inside_br_progress = 0;
	for i = 2,14 do
		brk[i] = math.floor(brk[i]*pool_size+.5);
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
	playerOfInterest = string.upper(string.sub(playerOfInterest, 1, 1))..string.lower(string.sub(playerOfInterest, 2))
	
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

function broadcast(msg)
	HonorSpy:SendCommMessage(commPrefix, msg, "GROUP");
	if (playerIsInGuild) then
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
		player.is_outdated = false;
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
	local day = date("!%w");
	local h = date("!%H");
	local m = date("!%M");
	local s = date("!%S");
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