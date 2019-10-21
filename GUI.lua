local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("HonorSpy", true)

local GUI = {}
_G["HonorSpyGUI"] = GUI

local mainFrame, statusLine, playerStandings, reportBtn, scroll = nil, nil, nil, nil
local rows = {}
local playersPerRow = 50
local needsRelayout = true

local colors = {
	["ORANGE"] = "ff7f00",
	["GREY"] = "aaaaaa",
	["RED"] = "C41F3B",
	["GREEN"] = "00FF96",
	["SHAMAN"] = "0070DE"
}

local nameWidth, dataWidth, lstWkHonorWidth = 0, 0, 0

local playerName = UnitName("player")

function GUI:Show(skipUpdate)
	if (not skipUpdate) then
		HonorSpy:UpdatePlayerData(function()
			if (mainFrame:IsShown()) then
				GUI:Show(true)
			end
		end)
	end
	
	mainFrame:Show()

	local limit = HonorSpy.db.factionrealm.limit

	local t = self:BuildStandingsTable()

	local resultText = ""
	local tableRowNumber = 0
	for i = 1, #t do
		local name, class, thisWeekHonor, lastWeekHonor, standing, RP, rank, last_checked = unpack(t[i])

		local last_seen, last_seen_human = (GetServerTime() - last_checked), ""
		if (last_seen/60/60/24 > 1) then
			last_seen_human = ""..math.floor(last_seen/60/60/24)..L["d"]
		elseif (last_seen/60/60 > 1) then
			last_seen_human = ""..math.floor(last_seen/60/60)..L["h"]
		elseif (last_seen/60 > 1) then
			last_seen_human = ""..math.floor(last_seen/60)..L["m"]
		else
			last_seen_human = ""..last_seen..L["s"]
		end

		local text = (name == playerName and '\n' or '') .. format('%d) %s', i, name)
		text = padTextToWidth(text, nameWidth)
		text = text .. thisWeekHonor
		text = padTextToWidth(text, nameWidth+dataWidth)
		text = text .. lastWeekHonor
		text = padTextToWidth(text, nameWidth+dataWidth+lstWkHonorWidth)
		text = text .. standing
		text = padTextToWidth(text, nameWidth+2*dataWidth+lstWkHonorWidth)
		text = text .. RP
		text = padTextToWidth(text, nameWidth+3*dataWidth+lstWkHonorWidth)
		text = text .. rank
		text = padTextToWidth(text, nameWidth+4*dataWidth+lstWkHonorWidth)
		text = text .. last_seen_human .. (name == playerName and '\n' or '')
		
		resultText = resultText .. colorize(text, class)

		if (math.fmod(i, playersPerRow) == 0 or i == limit or i == #t) then
			tableRowNumber = tableRowNumber + 1
			if (not rows[tableRowNumber]) then
				generateRow(tableRowNumber)
			end
			rows[tableRowNumber]:SetText(resultText)
			resultText = ""
		else
			resultText = resultText .. '\n'
		end

		if (i == limit) then
			break
		end
	end
	if (needsRelayout) then
		scroll:DoLayout()
		needsRelayout = false
	end

	local poolSizeText = format(L['Pool Size'] .. ': %d ', #t)
	if (#t > limit) then
		poolSizeText = poolSizeText .. colorize(format('(limit: %d)', limit), "GREY")
	else
		poolSizeText = poolSizeText .. '                        '
	end
	statusLine:SetText('|cff777777/hs show|r                                                    ' .. poolSizeText .. '                  |cff777777/hs search nickname|r')

	local pool_size, standing, bracket, RP, EstRP, Rank, Progress, EstRank, EstProgress = HonorSpy:Estimate()
	if (standing) then
		local playerText = colorize(L['Progress of'], "GREY") .. ' ' .. colorize(playerName, HonorSpy.db.factionrealm.currentStandings[playerName].class)
		playerText = playerText .. '\n' .. colorize(L['Standing'] .. ':', "GREY") .. colorize(standing, "ORANGE")
		playerText = playerText .. ' ' .. colorize(L['Bracket'] .. ':', "GREY") .. colorize(bracket, "ORANGE")
		playerText = playerText .. ' ' .. colorize(L['Current Rank'] .. ':', "GREY") .. colorize(format('%d (%d%%)', Rank, Progress), "ORANGE")
		playerText = playerText .. ' ' .. colorize(L['Next Week Rank'] .. ':', "GREY") .. colorize(format('%d (%d%%)', EstRank, EstProgress), EstRP >= RP and "GREEN" or "RED")
		playerStandings:SetText(playerText .. '\n')

		if (standing <= limit) then
			scroll:SetScroll(math.floor(standing / math.min(pool_size, limit) * 1000))
		end
	else
		playerStandings:SetText(format('%s %s\n%s\n', L['Progress of'], playerName, L['not enough HKs, min = 15']))
	end

	reportBtn:SetText(L['Report'] .. ' ' .. (UnitIsPlayer("target") and UnitName("target") or ''))
end

function GUI:Hide()
	if (mainFrame) then
		mainFrame:Hide()
	end
end

function GUI:Toggle()
	if (mainFrame and mainFrame:IsShown()) then
		GUI:Hide()
	else
		GUI:Show()
	end
end

function GUI:Reset()
	if (rows[1]) then
		rows = {}
		scroll:ReleaseChildren()
		GUI:PrepareGUI()
	end
end

function GUI:BuildStandingsTable()
	local t = { }
	for playerName, player in pairs(HonorSpy.db.factionrealm.currentStandings) do
	table.insert(t, {playerName, player.class, player.thisWeekHonor, player.lastWeekHonor, player.standing, player.RP, player.rank, player.last_checked})
	end
	local sort_column = 3; -- ThisWeekHonor
	if (HonorSpy.db.factionrealm.sort == L["Rank"]) then sort_column = 6; end
	table.sort(t, function(a,b)
	return a[sort_column] > b[sort_column]
	end)
	return t
end

function GUI:PrepareGUI()
	mainFrame = AceGUI:Create("Window")
	mainFrame:Hide()
	_G["HonorSpyGUI_MainFrame"] = mainFrame
	tinsert(UISpecialFrames, "HonorSpyGUI_MainFrame")	-- allow ESC close
	mainFrame:SetTitle(L["HonorSpy Standings"])
	mainFrame:SetWidth(500)
	mainFrame:SetLayout("List")
	mainFrame:EnableResize(false)

	-- Player Standings
	local playerStandingsGrp = AceGUI:Create("SimpleGroup")
	playerStandingsGrp:SetFullWidth(true)
	playerStandingsGrp:SetLayout("Flow")
	mainFrame:AddChild(playerStandingsGrp)

	playerStandings = AceGUI:Create("Label")
	playerStandings:SetRelativeWidth(0.8)
	playerStandings:SetText('\n\n')
	playerStandingsGrp:AddChild(playerStandings)

	reportBtn = AceGUI:Create("Button")
	reportBtn:SetRelativeWidth(0.19)
	reportBtn.text:SetFont("Fonts\\FRIZQT__.TTF", 8)
	reportBtn:SetCallback("OnClick", function()
		HonorSpy:Report(UnitIsPlayer("target") and UnitName("target") or nil)
	end)
	playerStandingsGrp:AddChild(reportBtn)

	-- TABLE HEADER
	local tableHeader = AceGUI:Create("SimpleGroup")
	tableHeader:SetFullWidth(true)
	tableHeader:SetLayout("Flow")
	mainFrame:AddChild(tableHeader)

	local btn = AceGUI:Create("InteractiveLabel")
	btn.OnWidthSet = function(self, width)
		if (btn:IsShown() and width > 0) then
			nameWidth = width
		end
	end
	btn:SetRelativeWidth(0.25)
	btn:SetText(colorize(L["Name"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn.OnWidthSet = function(self, width)
		if (btn:IsShown() and width > 0) then
			dataWidth = width
		end
	end
	btn:SetCallback("OnClick", function()
		HonorSpy.db.factionrealm.sort = L["Honor"]
		GUI:Show()
	end)
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetRelativeWidth(0.12)
	btn:SetText(colorize(L["Honor"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn.OnWidthSet = function(self, width)
		if (btn:IsShown() and width > 0) then
			lstWkHonorWidth = width
		end
	end
	btn:SetRelativeWidth(0.15)
	btn:SetText(colorize(L["LstWkHonor"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetRelativeWidth(0.12)
	btn:SetText(colorize(L["Standing"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetRelativeWidth(0.12)
	btn:SetText(colorize(L["RP"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetCallback("OnClick", function()
		HonorSpy.db.factionrealm.sort = L["Rank"]
		GUI:Show()
	end)
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetRelativeWidth(0.12)
	btn:SetText(colorize(L["Rank"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetRelativeWidth(0.1)
	btn:SetText(colorize(L["LastSeen"], "ORANGE"))
	tableHeader:AddChild(btn)

	scrollcontainer = AceGUI:Create("SimpleGroup")
	scrollcontainer:SetFullWidth(true)
	scrollcontainer:SetHeight(390)
	scrollcontainer:SetLayout("Fill")
	mainFrame:AddChild(scrollcontainer)

	scroll = AceGUI:Create("ScrollFrame")
	scroll:SetFullWidth(true)
	scroll:SetLayout("List")

	statusLine = AceGUI:Create("Label")
	statusLine:SetFullWidth(true)
	mainFrame:AddChild(statusLine)

	local playersToShow = math.min(#self:BuildStandingsTable(), HonorSpy.db.factionrealm.limit)
	for i = 1, math.floor(playersToShow / playersPerRow) + 1 do
		generateRow(i)
	end

	scrollcontainer:AddChild(scroll)
	scrollcontainer:ClearAllPoints()
	scrollcontainer.frame:SetPoint("TOP", tableHeader.frame, "BOTTOM", 0, -5)
	scrollcontainer.frame:SetPoint("BOTTOM", 0, 20)
	statusLine:ClearAllPoints()
	statusLine:SetPoint("BOTTOM", mainFrame.frame, "BOTTOM", 0, 15)
end

function generateRow(i)
	rows[i] = AceGUI:Create("Label")
	rows[i]:SetFullWidth(true)
	scroll:AddChild(rows[i])
	needsRelayout = true
end

function colorize(str, colorOrClass)
	if (not colors[colorOrClass] and RAID_CLASS_COLORS and RAID_CLASS_COLORS[colorOrClass]) then
		colors[colorOrClass] = format("%02x%02x%02x", RAID_CLASS_COLORS[colorOrClass].r * 255, RAID_CLASS_COLORS[colorOrClass].g * 255, RAID_CLASS_COLORS[colorOrClass].b * 255)
	end

	return format("|cff%s%s|r", colors[colorOrClass], str)
end

local label = AceGUI:Create("Label")
function padTextToWidth(str, width)
	repeat
		str = str .. ' '
		label:SetText(str)
	until label.label:GetStringWidth() >= width
	return str
end