-- First-time tutorial progress: plant -> harvest -> buy a slot -> visit the
-- Market. The step is saved and published as the TutorialStep attribute;
-- the client draws the hints and arrows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local STEPS = { "plant", "harvest", "slot", "market" }
local DONE = #STEPS

local TutorialService = {}

-- Players replaying the tutorial from the Help panel (no second reward).
local replaying: { [Player]: boolean } = {}

local function publish(player: Player)
	local data = PlayerStore.get(player)
	if data then
		player:SetAttribute("TutorialStep", data.tutorial)
	end
end

local function advance(player: Player, kind: string)
	local data = PlayerStore.get(player)
	if data and data.tutorial < DONE and STEPS[data.tutorial + 1] == kind then
		data.tutorial += 1
		publish(player)
		if data.tutorial == DONE then
			if replaying[player] then
				replaying[player] = nil
				ReefService.toast(player, "Tutorial complete!", "unlock")
			else
				ReefService.addCurrency(player, 0, 25, "Tutorial")
				ReefService.toast(player, "Tutorial complete! +25 shells", "unlock")
			end
		end
	end
end

function TutorialService.start()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "Tutorial"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote.OnServerEvent:Connect(function(player, action)
		local data = PlayerStore.get(player)
		if not data then
			return
		end
		if action == "skip" then
			data.tutorial = DONE
			publish(player)
		elseif action == "market" then
			advance(player, "market")
		elseif action == "replay" and data.tutorial >= DONE then
			replaying[player] = true
			data.tutorial = 0
			publish(player)
		end
	end)
	ReefService.Activity:Connect(advance)
	Players.PlayerRemoving:Connect(function(player)
		replaying[player] = nil
	end)
	PlayerStore.Loaded:Connect(function(player)
		local data = PlayerStore.get(player)
		-- Players who already know the ropes skip the tutorial.
		if data and data.tutorial < DONE and data.stats.harvests >= 10 and data.slots > 6 then
			data.tutorial = DONE
		end
		publish(player)
	end)
end

return TutorialService
