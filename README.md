## HonorSpy addon for WoW: Classic

Addon helps players estimate their PvP next week rank and overall progress.

It uses the exact formulaes as game server does, the only difference is that it operates on the database collected by players themselves. The final result is pretty close to what you get in reality, as the database is collected by all addon users and is synced instantly across other players.

### How it works
Addon does all the magic in background.

- addon inspects every player you meet (you should mouseover the player or target him, in inspect range), stores his PvP data in your local database, send this info to other addon users
- occasionally, when you die, you broadcast your whole database to other users. It works other way around, so you get the most recent database from every other player when they die, and merge it into your database.
- data is synced across "RAID", "BATTLEGROUND" and "GUILD" channels, so when you play on BGs you transmit and receive data from your teammates. And all the time you exchange your data with your guildmates.

**Right click on minimap icon to estimate your progress without opening the addon window.**

### Install
You have three options:
- Use Twitch app to install this addon. Just search for 'honorspy' in Mods section of the app.
- Download directly from Curseforge https://www.curseforge.com/wow/addons/honorspy
- Download latest release from Github (https://github.com/kakysha/HonorSpy/releases/latest), unzip and put it in Interface/Addons folder, relaunch WoW.

### About

0. Estimates your honor during the day
1. Calculates diminishing returns after each kill, prints into chat real honor gained and number of kills for every victim
2. It inspects every player in 'inspect range' which you target or mouseover
3. It syncs your db with other party/raid/bg members and your guildmates on your death
4. It can estimate your (or specific player) onward RP, Rank and Progress, taking into account your (player's) standing and pool size
5. It can export your internal DB in CSV format to copy-paste it into Google Spreadsheets for future calculations. [Spreadsheet done specially for HonorSpy](https://docs.google.com/spreadsheets/d/1OvZ7PRhrFjRn8IoH8HIPwHfRDEq50uO64YLCsSsjBQc/edit#gid=2113352865), it will estimate RP for all players
6. It supports automatic weekly pvp reset. Reset day can be configured
7. Supports sorting by Rank and Honor
8. Groups players in table by brackets
9. *Esc → Interface Options → Addons → HonorSpy* for addon settings

It only stores players with >15HKs.
Reset day can be configured, default is Wednesday. Reset time is fixed at 10AM UTC.

P.S. Do not be afraid of losing all your data, very likely that other players with HonorSpy will push you their database very soon. The more players use and collect data -> the more up-to-date data you will have. Magic of sync.

### Commands
`/hs show` -> show/hide standings table

`/hs search player_name` -> report specific player's standing

### Screenshot

![HonorSpy Screenshot](https://habrastorage.org/webt/1j/ca/-z/1jca-zgabr5e2rvg0oujakdmnsa.png)
