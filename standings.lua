local T = AceLibrary("Tablet-2.0")
local D = AceLibrary("Dewdrop-2.0")
local C = AceLibrary("Crayon-2.0")

local BC = AceLibrary("Babble-Class-2.2")

sepgp_standings = sepgp:NewModule("sepgp_standings", "AceDB-2.0")

function sepgp_standings:OnEnable()
  if not T:IsRegistered("sepgp_standings") then
    T:Register("sepgp_standings",
      "children", function()
        T:SetTitle("shootyepgp")
        self:OnTooltipUpdate()
      end,
  		"showTitleWhenDetached", true,
  		"showHintWhenDetached", true,
  		"cantAttach", true,
  		"menu", function()
        D:AddLine(
          "text", "Group by class",
          "tooltipText", "Group members by class.",
          "checked", sepgp_groupbyclass,
          "func", function() sepgp_standings:ToggleGroupByClass() end
        )
        D:AddLine(
          "text", "Refresh",
          "tooltipText", "Refresh window",
          "func", function() sepgp_standings:Refresh() end
        )
  		end
    )
  end
  if not T:IsAttached("sepgp_standings") then
    T:Open("sepgp_standings")
  end
end

function sepgp_standings:OnDisable()
  T:Close("sepgp_standings")
end

function sepgp_standings:Refresh()
  T:Refresh("sepgp_standings")
end

function sepgp_standings:Toggle()
  if T:IsAttached("sepgp_standings") then
    T:Detach("sepgp_standings")
    if (T:IsLocked("sepgp_standings")) then
      T:ToggleLocked("sepgp_standings")
    end
  else
    T:Attach("sepgp_standings")
  end
end

function sepgp_standings:ToggleGroupByClass()
  sepgp_groupbyclass = not sepgp_groupbyclass 
  self:Refresh()
end

-- Builds a standings table with record:
-- name, class, EP, GP, PR
-- and sorted by PR
function sepgp_standings:BuildStandingsTable()
  local t = { }
  for i = 1, GetNumGuildMembers(true) do
    local name, _, _, _, class, _, note, officernote, _, _ = GetGuildRosterInfo(i)
    local ep = sepgp_getep(name)
    local gp = sepgp_getgp(name)
    table.insert(t,{name,class,ep,gp,ep/gp})
  end
  if (sepgp_groupbyclass) then
    table.sort(t, function(a,b)
      if (a[2] ~= b[2]) then return a[2] > b[2]
      else return a[5] > b[5] end
    end)
  else
    table.sort(t, function(a,b)
    return a[5] > b[5]
    end)
  end
  return t
end

function sepgp_standings:OnTooltipUpdate()
  local cat = T:AddCategory(
      "columns", 4,
      "text",  C:Orange("Name"),   "child_textR",    1, "child_textG",    1, "child_textB",    1, "child_justify",  "LEFT",
      "text2", C:Orange("ep"),     "child_text2R",   1, "child_text2G",   1, "child_text2B",   1, "child_justify2", "RIGHT",
      "text3", C:Orange("gp"),     "child_text3R",   1, "child_text3G",   1, "child_text3B",   1, "child_justify3", "RIGHT",
      "text4", C:Orange("pr"),     "child_text4R",   1, "child_text4G",   1, "child_text4B",   0, "child_justify4", "RIGHT"
    )
  local t = self:BuildStandingsTable()
  for i = 1, table.getn(t) do
    local name, class, ep, gp, pr = unpack(t[i])
    cat:AddLine(
      "text", C:Colorize(BC:GetHexColor(class), name),
      "text2", string.format("%.4g", ep),
      "text3", string.format("%.4g", gp),
      "text4", string.format("%.4g", pr)
    )
  end
end

