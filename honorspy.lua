HonorSpy = LibStub("AceAddon-3.0"):NewAddon("HonorSpy", "AceConsole-3.0", "AceHook-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("HonorSpy", true)

local addonName = GetAddOnMetadata("HonorSpy", "Title");
local commPrefix = addonName;

local VERSION = 1;
local paused = false; -- pause all inspections when user opens inspect frame
local playerName = UnitName("player");

function HonorSpy:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HonorSpyDB", {
    	factionrealm = {
			currentStandings = {},
			last_reset = 0,
			sort = L["ThisWeekHonor"],
			limit = 750,
			minimapButton = {hide = false}
    	}
	}, true)
end

function HonorSpy:OnEnable()
	self:SecureHook("InspectUnit");

	self:RegisterEvent("PLAYER_TARGET_CHANGED");
	self:RegisterEvent("UPDATE_MOUSEOVER_UNIT");

	self:RegisterEvent("INSPECT_HONOR_UPDATE");

	self:RegisterComm(commPrefix, "OnCommReceive")

	self:RegisterEvent("PLAYER_DEAD");

	DrawMinimapIcon();
end

local inspectedPlayers = {}; -- stores last_checked time of all players met
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

	local player = HonorSpy.db.factionrealm.currentStandings[name] or inspectedPlayers[name];
	if (player == nil) then
		inspectedPlayers[name] = {last_checked = 0};
		player = inspectedPlayers[name];
	end
	if (time() - player.last_checked < 30) then -- 30 seconds until new inspection request
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
	
	player.last_checked = time();
	player.RP = 0;

	if (thisweekHK >= 0) then
		if (player.rank >= 3) then
			player.RP = math.ceil((player.rank-2) * 5000 + player.rankProgress * 5000)
		elseif (player.rank == 2) then
			player.RP = math.ceil(player.rankProgress * 3000 + 2000)
		end
		self.db.factionrealm.currentStandings[inspectedPlayerName] = player;
		self:SendCommMessage(commPrefix, self:Serialize(inspectedPlayerName, player), "GROUP");
		self:SendCommMessage(commPrefix, self:Serialize(inspectedPlayerName, player), "GUILD");
	end
	inspectedPlayers[inspectedPlayerName] = {last_checked = player.last_checked};
	inspectedPlayerName = nil;
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

-- CHAT COMMANDS
local options = {
	name = 'HonorSpy',
	type = 'group',
	args = {
		show = {
			type = 'execute',
			name = L['Show HonorSpy Standings'],
			desc = L['Show HonorSpy Standings'],
			func = function() HonorSpy:Print(HonorSpy.db.factionrealm.last_reset) end
		},
		search = {
			type = 'input',
			name = L['Report specific player standings'],
			desc = L['Report specific player standings'],
			usage = L['player_name'],
			get = false,
			set = function(playerName) HonorSpy.db.factionrealm.last_reset=HonorSpy.db.factionrealm.last_reset+1 end
		},
	}
}
LibStub("AceConfig-3.0"):RegisterOptionsTable("HonorSpy", options, {"honorspy", "hs"})

-- SYNCING --
function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

function store_player(playerName, player)
	if (player == nil) then return end
	
	if (player.last_checked < HonorSpy.db.factionrealm.last_reset
		or player.last_checked > time()
		or player.thisWeekHonor == 0) then
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

-- SEND
local last_send_time = 0;
function HonorSpy:PLAYER_DEAD()
	local filtered_players, count = {}, 0;
	if (time() - last_send_time < 5*60) then return	end;
	last_send_time = time();

	for playerName, player in pairs(self.db.factionrealm.currentStandings) do
		player.is_outdated = false;
		filtered_players[playerName] = player;
		count = count + 1;
		if (count == 10) then
			self:SendCommMessage(commPrefix, self:Serialize("filtered_players", filtered_players), "GROUP");
			self:SendCommMessage(commPrefix, self:Serialize("filtered_players", filtered_players), "GUILD");
			filtered_players, count = {}, 0;
		end
	end
	if (count > 0) then
		self:SendCommMessage(commPrefix, self:Serialize("filtered_players", filtered_players), "GROUP");
		self:SendCommMessage(commPrefix, self:Serialize("filtered_players", filtered_players), "GUILD");
	end
end

-- Minimap icon
function DrawMinimapIcon()
	LibStub("LibDBIcon-1.0"):Register("HonorSpy", LibStub("LibDataBroker-1.1"):NewDataObject("HonorSpy",
	{
		type = "data source",
		text = addonName,
		icon = "Interface\\Icons\\Inv_Misc_Bomb_04",
		OnClick = function() HonorSpyGUI:Toggle() end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(string.format("%s", addonName));
			tooltip:AddLine("|cff777777by Kakysha|r");
		end
	}), HonorSpy.db.factionrealm.minimapButton);
end