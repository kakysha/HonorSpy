local L = LibStub("AceLocale-3.0"):GetLocale("HonorSpy", true)

local options = {
	type = "group",
	name = L["HonorSpy Options"],
	args = {}
}

options.args["minimapButton"] = {
	order = 0,
	type = "toggle",
	name = L["Hide Minimap Button"],
	desc = L["Use \'/hs show\' to bring HonorSpy window, if hidden. Will Reload UI on change."],
	get = function() return HonorSpy.db.factionrealm.minimapButton.hide end,
	set = function(info, v) HonorSpy.db.factionrealm.minimapButton.hide = v; ReloadUI() end,
}
options.args["minimapButtonDesc"] = {
	order = 1,
	type = "description",
	name = L["Use \'/hs show\' to bring HonorSpy window, if hidden. Will Reload UI on change."] .. '\n\n'
}

options.args["limit"] = {
	order = 2,
	type = "input",
	name = L["Limit Rows"],
	desc = L["Limits number of rows shown in table, from 1 to 9999"],
	get = function() return HonorSpy.db.factionrealm.limit end,
	set = function(info, v) HonorSpy.db.factionrealm.limit = v; HonorSpyGUI:Reset(); HonorSpy:Print(L["Limit"].." = "..v) end,
	validate = function(info, v)
		local n = math.ceil(tonumber(v) or 0)
		return n and n > 0 and n < 10000
	end
}

options.args["sep1"] = {
	order = 3,
	type = "description",
	name = "\n"
}

local days = { L["Sunday"], L["Monday"], L["Tuesday"], L["Wednesday"], L["Thursday"], L["Friday"], L["Saturday"] };
options.args["reset_day"] = {
	order = 4,
	type = "select",
	name = L["PvP Week Reset On"],
	desc = L["Day of week when new PvP week starts (10AM UTC)"],
	values = days,
	get = function() return HonorSpy.db.factionrealm.reset_day+1 end,
	set = function(info, v)
		HonorSpy.db.factionrealm.reset_day = v-1
		HonorSpy:CheckNeedReset();
	end
}
options.args["sep2"] = {
	order = 5,
	type = "header",
	name = ""
}
options.args["export"] = {
	order = 6,
	type = "execute",
	name = L["Export to CSV"],
	desc = L["Show window with current data in CSV format"],
	func = function() HonorSpy:ExportCSV() end,
}
options.args["purge_data"] = {
	order = 7,
	type = "execute",
	name = L["_ purge all data"],
	desc = L["Delete all collected data"],
	confirm = true,
	confirmText = L["Delete all collected data"] .. '?',
	func = function() HonorSpy:Purge() end,
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("HonorSpy-options", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("HonorSpy-options", "HonorSpy")