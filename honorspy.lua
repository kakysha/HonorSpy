sepgp = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceDebug-2.0", "AceEvent-2.0", "AceModuleCore-2.0", "FuBarPlugin-2.0")
sepgp:SetModuleMixins("AceDebug-2.0")

function sepgp:OnInitialize()
  self.OnMenuRequest = sepgp_buildoptions()
end

function sepgp_sortrw()
  if not GetGuildRosterShowOffline() then GetGuildRosterShowOffline(true)end
-- SortGuildRoster("name")
end

function sepgp_updateep(getname,ep)
  sepgp_sortrw()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if (name==getname) then GuildRosterSetPublicNote(i,ep); end
  end
end

function sepgp_updategp(getname,gp)
  sepgp_sortrw()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if (name==getname) then GuildRosterSetOfficerNote(i,gp); end
  end
end

function sepgp_getep(getname) -- gets ep by name
  sepgp_sortrw()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
        if tonumber(note)==nil then note=0 end
    if (name==getname) then return tonumber(note); end
  end
  return(0)
end

function sepgp_getgp(getname) -- gets gp by name
  sepgp_sortrw()
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    if tonumber(officernote)==nil then officernote=0 end
    if (name==getname) then return tonumber(officernote); end
  end
  return(0)
end

function sepgp_awardraidep(ep) -- awards ep to raid members in zone
  if GetNumRaidMembers()>0 then
    sepgp_sortrw()
    sepgp_say("Giving "..ep.." ep to all raidmembers")
    for i = 1, GetNumRaidMembers(true) do
      local name, _, _, _, class, zone, note, officernote, _, _ = GetRaidRosterInfo(i)
      sepgp_givenameep(name,ep)
    end
  else UIErrorsFrame:AddMessage("You aren't in a raid dummy",255,0,0)end
end

function sepgp_givenameep(getname,ep) -- awards ep to a single character
  sepgp_say("giving "..ep.." ep to "..getname)
  ep = ep + sepgp_getep(getname)
  sepgp_updateep(getname,ep)
end

function sepgp_givenamegp(getname,gp) -- assigns gp to a single character
  sepgp_say("giving "..gp.." gp to "..getname)
  gp = gp + sepgp_getgp(getname)
  sepgp_updategp(getname,gp)
end

function sepgp_decay() -- decays entire roster's ep and gp
  sepgp_sortrw()
  for i = 1, GetNumGuildMembers(true) do
    local name,_,_,_,class,_,ep,gp,_,_ = GetGuildRosterInfo(i)
    ep = tonumber(ep)
    gp = tonumber(gp)
    if ep == nil 
	then 
	else ep = sepgp_round(ep*0.9)
	     GuildRosterSetPublicNote(i,ep)
	     gp = sepgp_round(gp*0.9) 
	     if gp<135 then GuildRosterSetOfficerNote(i,135) 
		else GuildRosterSetOfficerNote(i,gp)
	     end
    end
  end
  sepgp_say("all ep and gp decayed by 10%")
end

 function sepgp_gpreset()
   for i = 1, GetNumGuildMembers(true) do
     GuildRosterSetOfficerNote(i, 50)
   end
   sepgp_say("All GP are resetted to 50.")
end

function sepgp_showstandings() -- shows standings window of entire roster
end

function sepgp_round(i)
  if mod(i,1)<0.5 then i=i-mod(i,1) else i=i+(1-mod(i,1))end
  return i
end

local T = AceLibrary("Tablet-2.0")

sepgp.defaultMinimapPosition = 180
sepgp.cannotDetachTooltip = true
sepgp.tooltipHidderWhenEmpty = false
sepgp.hasIcon = "Interface\\Icons\\INV_Misc_Orb_04"

function sepgp:OnTooltipUpdate()
  T:SetHint("Open EPGP Standings")
end

function sepgp:OnClick()
  sepgp_standings:Toggle()
end

function sepgp_buildoptions()
  if sepgp_saychannel == nil then sepgp_saychannel = "GUILD" end
  local options = {
    type = "group",
    desc = "shootyepgp options",
    args = { }
  }
  options.args["ep_raid"] = {
    type = "text",
    name = "+EPs to Raid",
    desc = "Award EPs to all raid members.",
    get = false,
    set = function(v) sepgp_awardraidep(tonumber(v))end,
    usage = "<EP>",
    disabled = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
    validate = function(v)
      local n = tonumber(v)
      return n and n >= 0 and n < 10000
    end
  }
  
--  options.args["ep"] = {
--    type = "group",
--    name = "+EPs to Member",
--    desc = "Account EPs for member.",
--    disabled = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
--    args = { }
--  }
--  for i = 1, GetNumGuildMembers(true) do
--    local member_name,_,_,_,class,_,ep,gp,_,_ = GetGuildRosterInfo(i)
--    if (not options.args["ep"].args[class]) then
--      options.args["ep"].args[class] = {
--        type = "group",
--        name = class,
--        desc = class .. " members",
--        disabled = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
--        args = { }
--      }
--    end
--    options.args["ep"].args[class].args[member_name] = {
--      type = "text",
--      name = member_name,
--      desc = "Account EPs to " .. member_name .. ".",
--      usage = "<EP>",
--      get = false,
--      set = function(v) sepgp_givenameep(member_name, tonumber(v)) end,
--      validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < 10000 end
--    }
--  end
  
--  options.args["gp"] = {
--    type = "group",
--    name = "+GPs to Member",
--    desc = "Account GPs for member.",
--    disabled = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
--    args = { }
--  }
--  for i = 1, GetNumGuildMembers(true) do
--    local member_name,_,_,_,class,_,ep,gp,_,_ = GetGuildRosterInfo(i)
--    if (not options.args["gp"].args[class]) then
--      options.args["gp"].args[class] = {
--        type = "group",
--        name = class,
--        desc = class .. " members",
--        disabled = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
--        args = { }
--      }
--    end
--    options.args["gp"].args[class].args[member_name] = {
--      type = "text",
--      name = member_name,
--      desc = "Account GPs to " .. member_name .. ".",
--      usage = "<GP>",
--      get = false,
--      set = function(v) sepgp_givenamegp(member_name, tonumber(v)) end,
--      validate = function(v) return (type(v) == "number" or tonumber(v)) and tonumber(v) < 10000 end
--    }
--  end
  options.args["report_channel"] = {
    type = "text",
    name = "Reporting channel",
    desc = "Channel used by reporting functions.",
    get = function() return sepgp_saychannel end,
    set = function(v) sepgp_saychannel = v end,
    validate = { "PARTY", "RAID", "GUILD", "OFFICER" },
  }
  options.args["decay"] = {
    type = "execute",
    name = "Decay EPGP",
    desc = "Decays all EPGP by 10%",
    disabled = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
    func = function() sepgp_decay() end
  }
  
  -- Reset EPGP data
--  options.args["reset"] = {
--    type = "execute",
--    name = "Reset GP",
--    desc = "gives everybody 50 basic GP.",
--    disabled = function() return not (CanEditOfficerNote() and CanEditPublicNote()) end,
--    func = function() sepgp_gpreset() end
--	}
  return options
end


function sepgp_say(msg)
  SendChatMessage("shootyepgp: "..msg, sepgp_saychannel)
end