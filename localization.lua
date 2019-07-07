local L = AceLibrary("AceLocale-2.2"):new("HonorSpy")

L:RegisterTranslations("enUS", function() return {
	["HonorSpy standings"] = true,
	["Name"] = true,
	["ThisWeekHonor"] = true,
	["LastWeekHonor"] = true,
	["Standing"] = true,
	["RP"] = true,
	["Rank"] = true,
	["d"] = true,
	["h"] = true,
	["m"] = true,
	["s"] = true,
	
	["Weekly data was reset"] = true,
	["This will purge ALL addon data, you sure?"] = true,
	["All data was purged"] = true,
	["Show HonorSpy Standings"] = true,
	["Report specific player standings"] = true,
	["player_name"] = true,
	["Player %s not found in table"] = true,
	
	["Report for player"] = true,
	["Pool Size"] = true,
	["Standing"] = true,
	["Bracket"] = true,
	["current RP"] = true,
	["Next Week RP"] = true,
	["Current Rank"] = true,
	["Next Week Rank"] = true,
	["HonorSpy options"] = true,
	["Sunday"] = true,
	["Monday"] = true,
	["Tuesday"] = true,
	["Wednesday"] = true,
	["Thursday"] = true,
	["Friday"] = true,
	["Saturday"] = true,
	["PvP Week Reset On"] = true,
	["Day of week when new PvP week starts (10AM UTC)"] = true,
	["Sort By"] = true,
	["Set up sorting column"] = true,
	["Export to CSV"] = true,
	["Show window with current data in CSV format"] = true,
	["Report My Standing"] = true,
	["Reports your current standing as emote"] = true,
	["_ purge all data"] = true,
	["Delete all collected data"] = true,
	["Limit Rows"] = true,
	["Limits number of rows shown in table"] = true,
	["<EP>"] = true,
	["Limit"] = true,
} end)

L:RegisterTranslations("ruRU", function() return {
	["HonorSpy standings"] = "HonorSpy standings", -- 
	["Name"] = "Игрок",
	["ThisWeekHonor"] = "ЧестьНаЭтойНеделе",
	["LastWeekHonor"] = "ЧестьНаПрошлойНеделе",
	["Standing"] = "Позиция",
	["RP"] = "ОР",
	["Rank"] = "Ранг",
	["d"] = "д",
	["h"] = "ч",
	["m"] = "м",
	["s"] = "с",
	
	["Weekly data was reset"] = "Еженедельные данные были сброшены", --
	["This will purge ALL addon data, you sure?"] = "Это удалит ВСЕ данные аддона, вы уверены?", --
	["All data was purged"] = "Все данные были удалены", --
	["Show HonorSpy Standings"] = "Show HonorSpy Standings", --
	["Report specific player standings"] = "Report specific player standings", --
	["player_name"] = "player_name", --
	["Player %s not found in table"] = "Игрок %s не найден в таблице",
	
	["Report for player"] = "Report for player", --
	["Pool Size"] = "Размер пула",
	["Standing"] = "Позиция",
	["Bracket"] = "Группа",
	["current RP"] = "текущие ОР",
	["Next Week RP"] = "ОР на след. неделе",
	["Current Rank"] = "Текущий ранг",
	["Next Week Rank"] = "Будущий ранг",
	["HonorSpy options"] = "Настройки HonorSpy",
	["Sunday"] = "Воскресенье",
	["Monday"] = "Понедельник",
	["Tuesday"] = "Вторник",
	["Wednesday"] = "Среда",
	["Thursday"] = "Четверг",
	["Friday"] = "Пятница",
	["Saturday"] = "Суббота",
	["PvP Week Reset On"] = "Сброс ПВП недели",
	["Day of week when new PvP week starts (10AM UTC)"] = "День недели когда начинается новая ПВП неделя",
	["Sort By"] = "Сортировка по",
	["Set up sorting column"] = "Установка сортировки колонок",
	["Export to CSV"] = "Экспортировать в CSV",
	["Show window with current data in CSV format"] = "Показать окно с текущими данными в CSV формате", --
	["Report My Standing"] = "Сообщить мою позицию", --
	["Reports your current standing as emote"] = "Отчет вашей текущей позиции в чат", --
	["_ purge all data"] = "_ очистить все данные", --
	["Delete all collected data"] = "Удалить все собранные данные", --
	["Limit Rows"] = "Ограничить колонки", --
	["Limits number of rows shown in table"] = "Ограничевает количество колонок отображаемых в таблице", --
	["<EP>"] = "<EP>", --
	["Limit"] = "Limit", --
} end)
