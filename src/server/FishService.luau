-- Tapping a swimming fish (drawn on the client by Fish.luau) gives a pearl.
-- The client only reports the tap; the server limits how often it pays so
-- tapping can't be farmed: one pearl per COOLDOWN seconds, SESSION_CAP per
-- visit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReefService = require(script.Parent.ReefService)

local COOLDOWN = 2
local SESSION_CAP = 100

local FishService = {}

local lastTap: { [Player]: number } = {}
local paid: { [Player]: number } = {}

function FishService.start()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "TapFish"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastTap[player] or 0) < COOLDOWN or (paid[player] or 0) >= SESSION_CAP then
			return
		end
		lastTap[player] = now
		paid[player] = (paid[player] or 0) + 1
		ReefService.addCurrency(player, 1, 0, "TapFish")
		ReefService.toast(player, "+1 pearl from a happy fish!", "pearls")
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastTap[player] = nil
		paid[player] = nil
	end)
end

return FishService
