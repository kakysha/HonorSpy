HonorSpy = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "FuBarPlugin-2.0", "AceComm-2.0")

local T = AceLibrary("Tablet-2.0")

HonorSpy:RegisterDB("HonorSpyDB")

HonorSpy:RegisterDefaults('realm', {
	hs = {
		currentStandings = {},
		last_reset = 0,
		sort = "Rank"
	}
})

local commPrefix = "HonorSpy";

function HonorSpy:OnEnable()
	self:SetCommPrefix(commPrefix)
	self:RegisterComm(commPrefix, "GROUP", "OnCommReceive")
	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");
	self:RegisterEvent("INSPECT_HONOR_UPDATE");
	self:RegisterEvent("PARTY_MEMBERS_CHANGED");
	self.OnMenuRequest = BuildMenu();
	checkNeedReset();
end

local inspectedPlayers = {}; -- table of players we tried to inspect
local inspectedPlayerName = nil; -- name of currently inspected player

local function StartInspecting(unitID)
	local name = UnitName(unitID);
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
	
	local player = inspectedPlayers[name];
	if (player == nil) then
		inspectedPlayers[name] = {last_checked = 0};
		player = inspectedPlayers[name];
	end
	if (utctime() - player.last_checked < 30) then -- 30 seconds until new inspection request
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
	if (inspectedPlayerName == nil) then
		return;
	end

	local player = inspectedPlayers[inspectedPlayerName];
	if (player.class == nil) then player.class = "nil" end

	_, _, _, _, _, player.thisWeekHonor, _, player.lastWeekHonor, player.standing, _, _, topRank = GetInspectHonorData();

	_, topRank = GetPVPRankInfo(topRank);
	player.rankProgress = GetInspectPVPRankProgress();
	player.last_checked = utctime();
	player.RP = 0;
	player.is_outdated = false;

	if (topRank > 2 or player.thisWeekHonor > 30000) then -- save only those with R3 and higher or having 30k honor this week
		if (player.rank >= 3) then
			player.RP = math.ceil((player.rank-2) * 5000 + player.rankProgress * 5000)
		elseif (player.rank == 2) then
			player.RP = math.ceil(player.rankProgress * 3000 + 2000)
		end
		self.db.realm.hs.currentStandings[inspectedPlayerName] = player;
		self:SendCommMessage("GROUP", inspectedPlayerName, player);
	end

	ClearInspectPlayer();
end

function resetWeek(must_reset_on)
	if (must_reset_on == nil) then must_reset_on = utctime() end -- manual reset
	HonorSpy.db.realm.hs.last_reset = must_reset_on;
	for playerName, player in pairs(HonorSpy.db.realm.hs.currentStandings) do
		player.is_outdated = true;
		player.lastWeekHonor = player.thisWeekHonor;
		player.thisWeekHonor = 0;
		player.standing = 0;
		player.rankProgress = 0;
	end
	HonorSpyStandings:Refresh();
	HonorSpy:Print("Weekly data was reset");
end

function checkNeedReset()
	if (HonorSpy.db.realm.hs.reset_day == nil) then HonorSpy.db.realm.hs.reset_day = 3 end
	local day = date("!%w");
	local h = date("!%H");
	local m = date("!%M");
	local s = date("!%S");
	local days_diff = (7 + (day - HonorSpy.db.realm.hs.reset_day)) - math.floor((7 + (day - HonorSpy.db.realm.hs.reset_day))/7) * 7;
	local diff_in_seconds = s + m*60 + h*60*60 + days_diff*24*60*60 - 10*60*60; -- 10 AM UTC - fixed hour of PvP maintenance
	local must_reset_on = utctime()-diff_in_seconds;
	if (must_reset_on > HonorSpy.db.realm.hs.last_reset) then resetWeek(must_reset_on) end
end

function purgeData()
	StaticPopup_Show ("PURGE_DATA")
end

function utctime()
	return time(date("!*t"));
end

function HonorSpy:UPDATE_MOUSEOVER_UNIT()
	StartInspecting("mouseover");
end

function HonorSpy:PLAYER_TARGET_CHANGED()
	StartInspecting("target");
end

function HonorSpy:OnClick()
	checkNeedReset();
	HonorSpyStandings:Toggle()
end

HonorSpy.defaultMinimapPosition = 200
HonorSpy.cannotDetachTooltip = true
HonorSpy.tooltipHidderWhenEmpty = false
HonorSpy.hasIcon = "Interface\\Icons\\Inv_Misc_Bomb_04"

StaticPopupDialogs["PURGE_DATA"] = {
  text = "This will purge ALL addon data, you sure?",
  button1 = "Yes",
  button2 = "No",
  OnAccept = function()
		inspectedPlayers = {};
		HonorSpy.db.realm.hs.currentStandings={};
		HonorSpyStandings:Refresh();
		HonorSpy:Print("All data was purged");
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function BuildMenu()
  local options = {
    type = "group",
    desc = "HonorSpy options",
    args = { }
  }
  
  local days = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" };
  options.args["reset_day"] = {
    type = "text",
    name = "PvP Week Reset On",
    desc = "Day of week when new PvP week starts (10AM UTC)",
    get = function() return days[HonorSpy.db.realm.hs.reset_day+1] end,
    set = function(v)
    	for k,nv in pairs(days) do
    		if (v == nv) then HonorSpy.db.realm.hs.reset_day = k-1 end;
    	end
    end,
    validate = days,
  }
  options.args["sort"] = {
    type = "text",
    name = "Sort By",
    desc = "Set up sorting column",
    get = function() return HonorSpy.db.realm.hs.sort end,
    set = function(v)
    	HonorSpy.db.realm.hs.sort = v;
    	HonorSpyStandings:Refresh();
    end,
    validate = {"Rank", "ThisWeekHonor"},
  }
  options.args["export"] = {
    type = "execute",
    name = "Export to CSV",
    desc = "Show window with current data in CSV format",
    func = function() HonorSpy:ExportCSV() end,
  }
  options.args["reset_week"] = {
    type = "execute",
    name = "Reset Week Manually",
    desc = "Start new PvP week",
    func = function() resetWeek() end,
  }
  options.args["purge_data"] = {
    type = "execute",
    name = "_ Purge all data",
    desc = "Delete all collected data",
    func = function() purgeData() end,
  }
  
  return options
end

-- SYNCING --

function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

function HonorSpy:OnCommReceive(prefix, sender, distribution, playerName, player)
	local player = table.copy(player);
	local localPlayer = self.db.realm.hs.currentStandings[playerName];
	if (localPlayer == nil or localPlayer.last_checked < player.last_checked) then
		self.db.realm.hs.currentStandings[playerName] = player;
		inspectedPlayers[playerName] = player;
	end
end

function HonorSpy:PARTY_MEMBERS_CHANGED()
	for playerName, player in pairs(self.db.realm.hs.currentStandings) do
		if (not player.is_outdated) then
			self:SendCommMessage("GROUP", playerName, player);
		end
	end
end