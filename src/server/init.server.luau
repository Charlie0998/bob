-- Server entry point. Services listen for PlayerStore.Loaded, so they must
-- start before PlayerStore begins loading players.

local BookService = require(script.BookService)
local CreatureService = require(script.CreatureService)
local PlayerStore = require(script.PlayerStore)
local ReefService = require(script.ReefService)

ReefService.start()
CreatureService.start()
BookService.start()
PlayerStore.start()
