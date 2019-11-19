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

options.args["syncOverGuild"] = {
	order = 3,
	type = "toggle",
	name = L["Sync over GUILD instead of separate 'HonorSpySync' channel"],
	desc = L["You won't join 'HonorSpySync' channel anymore and will only sync data with your guildmates. Relog after changing this."],
	get = function() return HonorSpy.db.factionrealm.syncOverGuild end,
	set = function(info, v) HonorSpy.db.factionrealm.syncOverGuild = v end,
}
options.args["syncOverGuildDesc"] = {
	order = 4,
	type = "description",
	name = L["You won't join 'HonorSpySync' channel anymore and will only sync data with your guildmates. Relog after changing this."] .. '\n\n'
}

options.args["sep1"] = {
	order = 5,
	type = "description",
	name = "\n"
}

local days = { L["Sunday"], L["Monday"], L["Tuesday"], L["Wednesday"], L["Thursday"], L["Friday"], L["Saturday"] };
options.args["reset_day"] = {
	order = 6,
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
	order = 7,
	type = "header",
	name = ""
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
	func = function() HonorSpy:Purge() end,
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("HonorSpy-options", options)
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("HonorSpy-options", "HonorSpy")