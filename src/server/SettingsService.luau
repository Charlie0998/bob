-- Player settings saved with their data. Right now just Graphics: Low,
-- published as the LowGraphics attribute for the client's Graphics module.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStore = require(script.Parent.PlayerStore)

local SettingsService = {}

function SettingsService.start()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "SetGraphics"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote.OnServerEvent:Connect(function(player, low)
		local data = PlayerStore.get(player)
		if data and type(low) == "boolean" then
			data.lowGraphics = low
			player:SetAttribute("LowGraphics", low)
		end
	end)
	PlayerStore.Loaded:Connect(function(player)
		local data = PlayerStore.get(player)
		if data then
			player:SetAttribute("LowGraphics", data.lowGraphics)
		end
	end)
end

return SettingsService
