-- Server entry point. Services listen for PlayerStore.Loaded, so they must
-- start before PlayerStore begins loading players.

local BookService = require(script.BookService)
local CreatureService = require(script.CreatureService)
local DailyService = require(script.DailyService)
local PlayerStore = require(script.PlayerStore)
local PrestigeService = require(script.PrestigeService)
local ReefService = require(script.ReefService)
local SocialService = require(script.SocialService)

ReefService.start()
CreatureService.start()
BookService.start()
PrestigeService.start()
DailyService.start()
SocialService.start()
PlayerStore.start()
