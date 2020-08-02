local GUI = {}
_G["HonorSpyGUI"] = GUI

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("HonorSpy", true)

LibStub("AceHook-3.0"):Embed(GUI)

local mainFrame, poolSize, playerStandings, reportBtn, scroll = nil, nil, nil, nil
local rows, brackets = {}, {}
local playersPerRow = 50
local needsRelayout = true

local colors = {
	["ORANGE"] = "ff7f00",
	["GREY"] = "aaaaaa",
	["RED"] = "C41F3B",
	["GREEN"] = "00FF96",
	["SHAMAN"] = "0070DE",
	["nil"] = "FFFFFF",
	["NORMAL"] = "f2ca45"
}

local playerName = UnitName("player")

function GUI:Show(skipUpdate, sort_column)
	if (not skipUpdate) then
		HonorSpy:UpdatePlayerData(function()
			if (mainFrame:IsShown()) then
				GUI:Show(true, sort_column)
			end
		end)
	end
	
	rows = HonorSpy:BuildStandingsTable(sort_column)
	local brk = HonorSpy:GetBrackets(#rows)
	for i = 1, #brk do
		for j = brk[i], (brk[i+1] or 0)+1, -1 do
			brackets[j] = i
		end
	end

	local poolSizeText
	
	if HonorSpy.db.factionrealm.poolBoost > 0 then
		poolSizeText = format(
			L['Natural Pool Size'] .. ":" .. colorize(' %d', "RED") .. " - " .. 
			L['Boosted Pool Size'] .. ":" .. colorize(' %d', "GREEN"), 
			#rows, #rows + HonorSpy:GetPoolBoostForToday())
	else
		poolSizeText = format(
			L['Pool Size'] .. ":" .. colorize(' %d', "ORANGE"),#rows)
	end
	poolSize:SetText(poolSizeText)
	
	local pool_size, standing, bracket, RP, EstRP, Rank, Progress, EstRank, EstProgress = HonorSpy:Estimate()
	if (standing) then
		local playerText = colorize(L['Progress of'], "GREY") .. ' ' .. colorize(playerName, HonorSpy.db.factionrealm.currentStandings[playerName].class)
		playerText = playerText .. ", " .. colorize(L['Estimated Honor'] .. ': ', "GREY") .. colorize(HonorSpy.db.char.estimated_honor, "ORANGE")
		playerText = playerText .. '\n' .. colorize(L['Standing'] .. ':', "GREY") .. colorize(standing, "ORANGE")
		playerText = playerText .. ' ' .. colorize(L['Bracket'] .. ':', "GREY") .. colorize(bracket, "ORANGE")
		playerText = playerText .. ' ' .. colorize(L['Current Rank'] .. ':', "GREY") .. colorize(format('%d (%d%%)', Rank, Progress), "ORANGE")
		playerText = playerText .. ' ' .. colorize(L['Next Week Rank'] .. ':', "GREY") .. colorize(format('%d (%d%%)', EstRank, EstProgress), EstRP >= RP and "GREEN" or "RED")
		playerStandings:SetText(playerText .. '\n')

		scroll.scrollBar:SetValue(standing * scroll.buttonHeight-200)
		scroll.scrollBar.thumbTexture:Show()
	else
		playerStandings:SetText(format('%s %s, %s: %s\n%s\n', L['Progress of'], playerName, colorize(L['Estimated Honor'], "GREY"), colorize(HonorSpy.db.char.estimated_honor, "ORANGE"), L['You have 0 honor or not enough HKs, min = 15']))
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
		GUI:Show(false, L["EstHonor"])
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
	local brk_delim_inserted = false

	for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex];
		local itemIndex = buttonIndex + offset;

		if (itemIndex > 1 and brackets[itemIndex] and brackets[itemIndex-1] ~= brackets[itemIndex] and not brk_delim_inserted) then
			offset = offset-1
			brk_delim_inserted = true
			button.Name:SetText(colorize(format(L["Bracket"] .. " %d", brackets[itemIndex]), "GREY"))
			button.Honor:SetText();
			if HonorSpy.db.factionrealm.estHonorCol.show then
				button.EstHonor:SetText();
				button.EstHonor:SetWidth(80);
			else
				button.EstHonor:SetText();
				button.EstHonor:SetWidth(0);
			end
			button.LstWkHonor:SetText();
			button.Standing:SetText();
			button.RP:SetText();
			button.Rank:SetText();
			button.LastSeen:SetText();
			button.Background:SetTexture("Interface/Glues/CharacterCreate/CharacterCreateMetalFrameHorizontal")
			button.Highlight:SetTexture()
			button:Show();
		
		elseif (itemIndex <= #rows) then
			local name, class, thisWeekHonor, estHonor, lastWeekHonor, standing, RP, rank, last_checked = unpack(rows[itemIndex])
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
			button.Name:SetText(colorize(itemIndex .. ')  ', "GREY") .. colorize(name, class));
			button.Honor:SetText(colorize(thisWeekHonor, class));
			if HonorSpy.db.factionrealm.estHonorCol.show then 
				button.EstHonor:SetText(colorize(estHonor, class)); 
				button.EstHonor:SetWidth(80);
			else 
				button.EstHonor:SetText();
				button.EstHonor:SetWidth(0);
			end
			button.LstWkHonor:SetText(colorize(lastWeekHonor, class));
			button.Standing:SetText(colorize(standing, class));
			button.RP:SetText(colorize(RP, class));
			button.Rank:SetText(colorize(rank, class));
			button.LastSeen:SetText(colorize(last_seen_human, class));

			if (name == playerName) then
				button.Background:SetColorTexture(0.5, 0.5, 0.5, 0.2)
			else
				button.Background:SetColorTexture(0, 0, 0, 0.2)
			end
			button.Highlight:SetColorTexture(1, 0.75, 0, 0.2)

			brk_delim_inserted = false
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
	if HonorSpy.db.factionrealm.estHonorCol.show then mainFrame:SetWidth(680) else mainFrame:SetWidth(600) end
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
	reportBtn.text:SetFontObject("SystemFont_NamePlate")
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
		GUI:Show(false, L["Honor"])
	end)
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetWidth(80)
	btn:SetText(colorize(L["Honor"], "ORANGE"))
	tableHeader:AddChild(btn)

	if HonorSpy.db.factionrealm.estHonorCol.show then
		btn = AceGUI:Create("InteractiveLabel")
		btn:SetCallback("OnClick", function()
			GUI:Show(false, L["EstHonor"])
		end)
		btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
		btn:SetWidth(80)
		btn:SetText(colorize(L["EstHonor"], "ORANGE"))
		tableHeader:AddChild(btn)
	end

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(80)
	btn:SetText(colorize(L["LstWkHonor"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetCallback("OnClick", function()
		GUI:Show(false, L["Standing"])
	end)
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetWidth(70)
	btn:SetText(colorize(L["Standing"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(70)
	btn:SetText(colorize(L["RP"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetCallback("OnClick", function()
		GUI:Show(false, L["Rank"])
	end)
	btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
	btn:SetWidth(50)
	btn:SetText(colorize(L["Rank"], "ORANGE"))
	tableHeader:AddChild(btn)

	btn = AceGUI:Create("InteractiveLabel")
	btn:SetWidth(60)
	btn:SetText(colorize(L["LastSeen"], "ORANGE"))
	tableHeader:AddChild(btn)

	local scrollcontainer = AceGUI:Create("SimpleGroup")
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

	local hsFooter = AceGUI:Create("SimpleGroup")
	mainFrame:AddChild(hsFooter)
	hsFooter:SetWidth(mainFrame.frame:GetWidth() - 20)
	hsFooter:SetLayout("Flow")

	local hsShow = AceGUI:Create("Label")
	hsShow:SetText('|cff777777/hs show|r')
	hsShow:SetWidth(hsFooter.frame:GetWidth() / 4)
	hsShow:SetPoint("BOTTOMLEFT")
	hsShow:SetJustifyH("LEFT")
	hsFooter:AddChild(hsShow)

	poolSize = AceGUI:Create("Label")
	poolSize:SetWidth(hsFooter.frame:GetWidth() / 2)
	poolSize:SetPoint("BOTTOM")
	poolSize:SetJustifyH("CENTER")
	hsFooter:AddChild(poolSize)

	local hsSearch = AceGUI:Create("Label")
	hsSearch:SetWidth(hsFooter.frame:GetWidth() / 4)
	hsSearch:SetPoint("BOTTOMRIGHT")
	hsSearch:SetJustifyH("RIGHT")
	hsSearch:SetText('|cff777777/hs search nickname|r')
	hsFooter:AddChild(hsSearch)

	if (not HonorSpyGUI:IsHooked(HonorFrame, "OnUpdate")) then
		HonorSpyGUI:SecureHookScript(HonorFrame, "OnUpdate", "UpdateHonorFrameText")
	end
end

function HonorSpyGUI:UpdateHonorFrameText(setRankProgress)
	-- rank progress percentage
	local _, rankNumber = GetPVPRankInfo(UnitPVPRank("player"))
	local rankProgress = GetPVPRankProgress(); -- This is a player only call
	HonorFrameCurrentPVPRank:SetText(format("(%s %d) %d%%", RANK, rankNumber, rankProgress*100))
	
	-- today's honor
	HonorFrameCurrentHKValue:SetText(format("%d "..colorize("(Honor: %d)", "NORMAL"), GetPVPSessionStats(), HonorSpy.db.char.estimated_honor - HonorSpy.db.char.original_honor))
	-- this week honor
	local _, this_week_honor = GetPVPThisWeekStats();
	HonorFrameThisWeekContributionValue:SetText(format("%d (%d)", this_week_honor, HonorSpy.db.char.estimated_honor))
end

function colorize(str, colorOrClass)
	if (not colorOrClass) then -- some guys have nil class for an unknown reason
		colorOrClass = "nil"
	end
	
	if (not colors[colorOrClass] and RAID_CLASS_COLORS and RAID_CLASS_COLORS[colorOrClass]) then
		colors[colorOrClass] = format("%02x%02x%02x", RAID_CLASS_COLORS[colorOrClass].r * 255, RAID_CLASS_COLORS[colorOrClass].g * 255, RAID_CLASS_COLORS[colorOrClass].b * 255)
	end
	if (not colors[colorOrClass]) then
		colorOrClass = "nil"
	end

	return format("|cff%s%s|r", colors[colorOrClass], str)
end
