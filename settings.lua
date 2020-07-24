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

options.args["sep1"] = {
	order = 2,
	type = "description",
	name = "\n"
}

options.args["estHonorCol"] = {
	order = 3,
	type = "toggle",
	name = L["Show Estimated Honor"],
	desc = L["Shows the Estimated Honor column in the table. This data will only be populated by other people with HonorSpy."],
	get = function() return HonorSpy.db.factionrealm.estHonorCol.show end,
	set = function(info, v) HonorSpy.db.factionrealm.estHonorCol.show = v; HonorSpyGUI:PrepareGUI() end,
}

options.args["estHonorColDesc"] = {
	order = 4,
	type = "description",
	name = L["Shows the Estimated Honor column in the table. This data will only be populated by other people with HonorSpy."] .. '\n\n'
}

options.args["sep1"] = {
	order = 5,
	type = "description",
	name = "\n"
}

options.args["poolBoost"] = {
	order = 6,
	type = "range",
	name = L["Pool Booster Count"],
	desc = L["Number of characters to add to Pool"],
	min = 0,
	max = 10000,
	step = 5,
	bigStep = 100,
	get = function() return HonorSpy.db.factionrealm.poolBoost end,
	set = function(info, v) HonorSpy.db.factionrealm.poolBoost = tonumber(v); end
}

options.args["sep1"] = {
	order = 7,
	type = "description",
	name = L["This is how big the discrepancy is at the end of PvP week between HonorSpy pool size and real server pool size. Pool size will slowly be growing during the week reaching the final value of 'gathered number of players' + 'pool boost size'."] .. "\n\n"
}

options.args["export"] = {
	order = 8,
	type = "execute",
	name = L["Export to CSV"],
	desc = L["Show window with current data in CSV format"],
	func = function() HonorSpy:ExportCSV() end,
}
options.args["purge_data"] = {
	order = 9,
	type = "execute",
	name = L["_ purge all data"],
	desc = L["Delete all collected data"],
	confirm = true,
	confirmText = L["Delete all collected data"] .. '?',
	func = function() HonorSpy:ResetWeek() end,
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("HonorSpy-options", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("HonorSpy-options", "HonorSpy")