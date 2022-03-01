local L = LibStub("AceLocale-3.0"):NewLocale("HonorSpy", "ruRU")

if L then

L["HonorSpy Standings"] = "Таблица HonorSpy"
L["Name"] = "Игрок"
L["Honor"] = "Честь"
L["KnownHonor"] = true
L["ThisWeekHonor"] = "ЧестьНаЭтойНеделе"
L["EstHonor"] = "ОжидЧесть"
L["LstWkHonor"] = "ЧестьНаПрНед"
L["Standing"] = "Позиция"
L["RP"] = "ОР"
L["Rank"] = "Ранг"
L["LastSeen"] = "Актуальность"
L["Progress of"] = "Прогресс"
L["d"] = "д"
L["h"] = "ч"
L["m"] = "м"
L["s"] = "с"

L["Weekly data was reset"] = "Еженедельные данные были сброшены"
L["This will purge ALL addon data, you sure?"] = "Это удалит ВСЕ данные аддона, вы уверены?"
L["All data was purged"] = "Все данные были удалены"
L["Show HonorSpy Standings"] = "Показать HonorSpy позиции"
L["Report specific player standings"] = "Отчёт по другому игроку"
L["player_name"] = "player_name"
L["Player %s not found in table"] = "Игрок %s не найден в таблице"

L["Pool Booster Count"] = "Искуственное увеличение пула"
L["Number of characters to add to Pool"] = "Какое кол-во игроков добавить к реальному пулу"
L["Spread the poolboost count over the week"] = true
L["As final pool boost should be only achieved at the end of the week"] = true
L['Poolsize'] = true
L['Set the number of boosted character in the pool'] = true
L['Number of booster character in the pool'] = true

L["Report"] = "Отчёт"
L["Report for player"] = "Отчёт по др. игроку"
L["Report Target"] = "Отчёт по цели"
L["Report Me"] = "Отчёт по себе"
L["Pool Size"] = "Размер пула"
L["Natural Pool Size"] = "Реальный размер пула"
L["Boosted Pool Size"] = "Увеличенный размер пула"
L["Standing"] = "Позиция"
L["Bracket"] = "Группа"
L["Current RP"] = "Текущие ОР"
L["Next Week RP"] = "ОР на след. неделе"
L["Current Rank"] = "Текущий ранг"
L["Next Week Rank"] = "Будущий ранг"
L["HonorSpy Options"] = "Настройки HonorSpy"
L["Sunday"] = "Воскресенье"
L["Monday"] = "Понедельник"
L["Tuesday"] = "Вторник"
L["Wednesday"] = "Среда"
L["Thursday"] = "Четверг"
L["Friday"] = "Пятница"
L["Saturday"] = "Суббота"
L["PvP Week Reset On"] = "PvP неделя сбрасывается в"
L["Day of week when new PvP week starts (10AM UTC)"] = "День недели, когда начинается новая PvP неделя"
L["Sort By"] = "Сортировка по"
L["Set up sorting column"] = "Установка сортировки колонок"
L["Export to CSV"] = "Экспортировать в CSV"
L["Show window with current data in CSV format"] = "Показать окно с текущими данными в CSV формате"
L["Report My Standing"] = "Сообщить мою позицию"
L["Reports your current standing as emote"] = "покажет вашу текущую позицию в чат"
L["Purge all data"] = "_ очистить все данные"
L["Delete all collected data"] = "Удалить все собранные данные"
L["Limit Rows"] = "лимит строк в таблице"
L["Limits number of rows shown in table, from 1 to 9999"] = "Ограничивает количество строк отображаемых в таблице, от 1 до 9999"
L["<EP>"] = "<EP>"
L["Limit"] = "Лимит строк"
L['You have 0 honor or not enough HKs, min = 15'] = "У вас 0 хонора или недостаточно убийств, мин = 15"
L["Hide Minimap Button"] = "Скрыть иконку на миникарте"
L["Use \'/hs show\' to bring HonorSpy window, if hidden. Will Reload UI on change."] = "Введите \'/hs show' чтобы открыть окно HonorSpy, если скрыли. UI будет перезагружен."
L["Show Estimated Honor"] = "Показывать ожидаемую честь"
L["Shows the Estimated Honor column in the table. This data will only be populated by other people with HonorSpy."] = "Показывает колонку в таблице с ожидаемой честью. Данные будут показываться только для других игроков с установленным аддоном."
L["Estimated Honor"] = "Ожидаемая Честь"
L["Sync over GUILD instead of separate 'HonorSpySync' channel"] = "Синхронизировать с Гильдией, вместо отдельного канала HonorSpySync"
L["You won't join 'HonorSpySync' channel anymore and will only sync data with your guildmates. Relog after changing this."] = "Вы больше не будете подключаться к каналу HonorSpySync, а будете синхронизировать данные только с согильдийцами. Требуется релог при изменении."
L["This is how big the discrepancy is at the end of PvP week between HonorSpy pool size and real server pool size. Pool size will slowly be growing during the week reaching the final value of 'gathered number of players' + 'pool boost size'."] = "Разница между размером пула в HonorSpy и реальным пулом на сервере к концу недели. Это число будет постепенно добавляться к предполагаемому пулу, к концу недели достигнув значения 'количество игроков в таблице' + 'искуственное увеличение пула'"
L["Season of Mastery"] = "Сезон мастерства"
L["Implements the ranking changes applied to Season of Mastery."] = "Реализует изменения рейтинга, применяемые к сезону мастерства."
L["Enables Season of Mastery ranking changes."] = "Позволяет сезон ранжирования изменений Мастерства."

end
