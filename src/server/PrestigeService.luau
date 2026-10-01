-- Tide Reset (prestige). Once a reef reaches the required size, the player
-- may reset it for a permanent income multiplier and a special coral. The
-- prestige shop sells rare corals for Shells to players who have reset.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local CONFIG = Balance.prestige

local PrestigeService = {}

local lastRequest: { [Player]: number } = {}

local function throttled(player: Player): boolean
	if os.clock() - (lastRequest[player] or 0) < 1 then
		return true
	end
	lastRequest[player] = os.clock()
	return false
end

local function publish(player: Player)
	local data = PlayerStore.get(player)
	if data then
		player:SetAttribute("TideLevel", data.prestige.level)
		ReefService.incomeMultiplier(player)
	end
end

local function onReset(player: Player)
	local data = PlayerStore.get(player)
	if throttled(player) or not data or data.slots < CONFIG.requiredSlots then
		return
	end
	data.prestige.level += 1
	ReefService.resetReef(player)
	ReefService.addInventory(player, CONFIG.rewardCoral, 1)
	publish(player)
	ReefService.toast(
		player,
		string.format("Tide Reset! Pearl income is now x%.2f forever, and you got a Crystal Coral.", 1 + data.prestige.level * CONFIG.multiplierPerLevel),
		"unlock"
	)
	ReefService.activity(player, "prestige", 1)
end

local function onBuy(player: Player, itemId: unknown)
	local data = PlayerStore.get(player)
	if throttled(player) or not data or type(itemId) ~= "string" then
		return
	end
	for _, item in CONFIG.shop do
		if item.id == itemId then
			if data.prestige.level < item.minLevel then
				ReefService.toast(player, "Do a Tide Reset to open the prestige shop")
			elseif data.shells < item.shells then
				ReefService.toast(player, string.format("Need %d shells", item.shells))
			else
				ReefService.addCurrency(player, 0, -item.shells, "Prestige_" .. item.id)
				ReefService.addInventory(player, item.coral, 1)
				ReefService.toast(player, Balance.corals[item.coral].displayName .. " added to your corals!", "unlock")
			end
			return
		end
	end
end

function PrestigeService.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local reset = Instance.new("RemoteEvent")
	reset.Name = "TideReset"
	reset.Parent = remotes
	reset.OnServerEvent:Connect(onReset)
	local buy = Instance.new("RemoteEvent")
	buy.Name = "BuyPrestigeItem"
	buy.Parent = remotes
	buy.OnServerEvent:Connect(onBuy)

	ReefService.addMultiplier("prestige", function(player)
		local data = PlayerStore.get(player)
		return if data then 1 + data.prestige.level * CONFIG.multiplierPerLevel else 1
	end)
	PlayerStore.Loaded:Connect(publish)
end

return PrestigeService
