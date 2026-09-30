-- Server entry point. ReefService listens for PlayerStore.Loaded, so it must
-- start before PlayerStore begins loading players.

local PlayerStore = require(script.PlayerStore)
local ReefService = require(script.ReefService)

ReefService.start()
PlayerStore.start()
