local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("HonorSpy", true)

local GUI = {}
_G["HonorSpyGUI"] = GUI

local mainFrame, statusLine, playerStandings, reportBtn, scroll = nil, nil, nil, nil
local rows, brackets = {}, {}
local playersPerRow = 50
local needsRelayout = true

local colors = {
	["ORANGE"] = "ff7f00",
	["GREY"] = "aaaaaa",
	["RED"] = "C41F3B",
	["GREEN"] = "00FF96",
	["SHAMAN"] = "0070DE",
	["br14"] = {color="a911f5",r=0.663,g=0.067,b=0.961},
	["br13"] = {color="672492",r=0.404,g=0.141,b=0.573},
	["br12"] = {color="5645aa",r=0.337,g=0.271,b=0.667},
	["br11"] = {color="1370ba",r=0.075,g=0.439,b=0.729},
	["br10"] = {color="277ee5",r=0.153,g=0.494,b=0.898},
	["br9"] = {color="2d83de",r=0.176,g=0.514,b=0.871},
	["br8"] = {color="1acbeb",r=0.102,g=0.796,b=0.922},
	["br7"] = {color="3f788a",r=0.247,g=0.471,b=0.541},
	["br6"] = {color="c84d72",r=0.784,g=0.302,b=0.447},
	["br5"] = {color="09dfa0",r=0.035,g=0.875,b=0.627},
	["br4"] = {color="04bc25",r=0.016,g=0.737,b=0.145},
	["br3"] = {color="e96258",r=0.914,g=0.384,b=0.345},
	["br2"] = {color="90f3e1",r=0.565,g=0.953,b=0.882},
	["br1"] = {color="d1cf88",r=0.82,g=0.812,b=0.533}
}

local playerName = UnitName("player")

function GUI:Show(skipUpdate)
	if (not skipUpdate) then
		HonorSpy:UpdatePlayerData(function()
			if (mainFrame:IsShown()) then
				GUI:Show(true)
			end
		end)
	end
	
	rows = HonorSpy:BuildStandingsTable()
	local brk = HonorSpy:GetBrackets(#rows)
	for i = 1, #brk do
		for j = brk[i], (brk[i+1] or 0)+1, -1 do
			brackets[j] = i
		end
	end

	local poolSizeText = format(L['Pool Size'] .. ': %d ', #rows)
	statusLine:SetText('|cff777777/hs show|r                                                                         ' .. poolSizeText .. '                                                       |cff777777/hs search nickname|r')

	local pool_size, standing, bracket, RP, EstRP, Rank, Progress, EstRank, EstProgress = HonorSpy:Estimate()
	if (standing) then
		local playerText = colorize(L['Progress of'], "GREY") .. ' ' .. colorize(playerName, HonorSpy.db.factionrealm.currentStandings[playerName].class)
		playerText = playerText .. '\n' .. colorize(L['Standing'] .. ':', "GREY") .. colorize(standing, "ORANGE")
		playerText = playerText .. ' ' .. colorize(L['Bracket'] .. ':', "GREY") .. colorize(bracket, "ORANGE")
		playerText = playerText .. ' ' .. colorize(L['Current Rank'] .. ':', "GREY") .. colorize(format('%d (%d%%)', Rank, Progress), "ORANGE")
		playerText = playerText .. ' ' .. colorize(L['Next Week Rank'] .. ':', "GREY") .. colorize(format('%d (%d%%)', EstRank, EstProgress), EstRP >= RP and "GREEN" or "RED")
		playerStandings:SetText(playerText .. '\n')

		scroll.scrollBar:SetValue(standing * scroll.buttonHeight-200)
		scroll.scrollBar.thumbTexture:Show()
	else
		playerStandings:SetText(format('%s %s\n%s\n', L['Progress of'], playerName, L['not enough HKs, min = 15']))
	end

	reportBtn:SetText(L['Report'] .. ' ' .. (UnitIsPlayer("target") and UnitName("target") or ''))

	mainFrame:Show()
	GUI:UpdateTableView()
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
		GUI:PrepareGUI()
	end
end

function GUI:UpdateTableView()
	local buttons = HybridScrollFrame_GetButtons(scroll);
    local offset = HybridScrollFrame_GetOffset(scroll);

    for buttonIndex = 1, #buttons do
        local button = buttons[buttonIndex];
        local itemIndex = buttonIndex + offset;

        if itemIndex <= #rows then
            local name, class, thisWeekHonor, lastWeekHonor, standing, RP, rank, last_checked = unpack(rows[itemIndex])
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
            button:SetID(itemIndex);
            button.Name:SetText(colorize(itemIndex .. ') ' .. name, class));
            button.Honor:SetText(colorize(thisWeekHonor, class));
            button.LstWkHonor:SetText(colorize(lastWeekHonor, class));
            button.Standing:SetText(colorize(standing, class));
            button.RP:SetText(colorize(RP, class));
            button.Rank:SetText(colorize(rank, class));
            button.LastSeen:SetText(colorize(last_seen_human, class));

            if (name == playerName) then
            	button.Background:SetColorTexture(0.5, 0.5, 0.5, 0.2)
            else
            	button.Background:SetColorTexture(colors["br"..brackets[itemIndex]].r, colors["br"..brackets[itemIndex]].g, colors["br"..brackets[itemIndex]].b, 0.1)
            end

            button:Show();
        else
            button:Hide();
        end
    end

    local buttonHeight = scroll.buttonHeight;
    local totalHeight = #rows * buttonHeight;
    local shownHeight = #buttons * buttonHeight;

	HybridScrollFrame_Update(scroll, totalHeight, shownHeight);
end

function GUI:PrepareGUI()
	mainFrame = AceGUI:Create("Window")
	mainFrame:Hide()
	_G["HonorSpyGUI_MainFrame"] = mainFrame
	tinsert(UISpecialFrames, "HonorSpyGUI_MainFrame")	-- allow ESC close
	mainFrame:SetTitle(L["HonorSpy Standings"])
	mainFrame:SetWidth(600)
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
	btn:SetWidth(150)
	btn:SetText(colorize(L["Name"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetCallback("OnClick", function()
		HonorSpy.db.factionrealm.sort = L["Honor"]
		GUI:Show()
	end)
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetWidth(80)
	btn:SetText(colorize(L["Honor"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(80)
	btn:SetText(colorize(L["LstWkHonor"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(70)
	btn:SetText(colorize(L["Standing"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(70)
	btn:SetText(colorize(L["RP"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetCallback("OnClick", function()
		HonorSpy.db.factionrealm.sort = L["Rank"]
		GUI:Show()
	end)
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetWidth(50)
	btn:SetText(colorize(L["Rank"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(60)
	btn:SetText(colorize(L["LastSeen"], "ORANGE"))
	tableHeader:AddChild(btn)

	scrollcontainer = AceGUI:Create("SimpleGroup")
	scrollcontainer:SetFullWidth(true)
	scrollcontainer:SetHeight(390)
	scrollcontainer:SetLayout("Fill")
	mainFrame:AddChild(scrollcontainer)
	scrollcontainer:ClearAllPoints()
	scrollcontainer.frame:SetPoint("TOP", tableHeader.frame, "BOTTOM", 0, -5)
	scrollcontainer.frame:SetPoint("BOTTOM", 0, 20)

	scroll = CreateFrame("ScrollFrame", nil, scrollcontainer.frame, "HybridScrollFrame")
	HybridScrollFrame_CreateButtons(scroll, "HybridScrollListItemTemplate");
	HybridScrollFrame_SetDoNotHideScrollBar(scroll, true)
	scroll.update = function() GUI:UpdateTableView() end

	statusLine = AceGUI:Create("Label")
	statusLine:SetFullWidth(true)
	mainFrame:AddChild(statusLine)
	statusLine:ClearAllPoints()
	statusLine:SetPoint("BOTTOM", mainFrame.frame, "BOTTOM", 0, 15)
end

function colorize(str, colorOrClass)
	if (not colors[colorOrClass] and RAID_CLASS_COLORS and RAID_CLASS_COLORS[colorOrClass]) then
		colors[colorOrClass] = format("%02x%02x%02x", RAID_CLASS_COLORS[colorOrClass].r * 255, RAID_CLASS_COLORS[colorOrClass].g * 255, RAID_CLASS_COLORS[colorOrClass].b * 255)
	end

	return format("|cff%s%s|r", colors[colorOrClass], str)
end