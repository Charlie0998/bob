-- The central Market: 6 rotating coral slots per player (restock every 10
-- minutes, or pay Shells to restock now), and decorations for Shells. The
-- daily deal is handled by DailyService. Every purchase is checked here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local ShopRotation = require(ReplicatedStorage.Shared.ShopRotation)
local LevelService = require(script.Parent.LevelService)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local MarketService = {}

local lastRequest: { [Player]: number } = {}

local function throttled(player: Player): boolean
	if os.clock() - (lastRequest[player] or 0) < 0.4 then
		return true
	end
	lastRequest[player] = os.clock()
	return false
end

-- Starts a fresh stock when the 10-minute period rolls over.
local function current(data: PlayerStore.PlayerData)
	local period = ShopRotation.marketPeriod(Balance, os.time())
	if data.market.period ~= period then
		data.market = { period = period, restocks = 0, bought = {} }
	end
	return data.market
end

local function publish(player: Player)
	local data = PlayerStore.get(player)
	if not data then
		return
	end
	local market = current(data)
	local bought = {}
	for slot in market.bought do
		table.insert(bought, slot)
	end
	player:SetAttribute("MarketPeriod", market.period)
	player:SetAttribute("MarketRestocks", market.restocks)
	player:SetAttribute("MarketBought", table.concat(bought, ","))
	local owned = {}
	for id in data.decorOwned do
		table.insert(owned, id)
	end
	player:SetAttribute("DecorOwned", table.concat(owned, ","))
end

local function onBuy(player: Player, slot: unknown)
	local data = PlayerStore.get(player)
	if throttled(player) or not data or type(slot) ~= "number" then
		return
	end
	local market = current(data)
	local items = ShopRotation.market(Balance, market.period, market.restocks, player.UserId)
	local item = items[slot]
	local key = tostring(slot)
	if not item or market.bought[key] then
		ReefService.toast(player, "Sold out!")
		publish(player)
		return
	end
	local have = if item.currency == "pearls" then data.pearls else data.shells
	if have < item.price then
		ReefService.toast(player, string.format("Need %d %s", item.price, item.currency))
		return
	end
	if item.currency == "pearls" then
		ReefService.addCurrency(player, -item.price, 0, "Market_" .. item.coral)
	else
		ReefService.addCurrency(player, 0, -item.price, "Market_" .. item.coral)
	end
	market.bought[key] = true
	ReefService.addInventory(player, item.coral, 1)
	if ReefService.discover(player, "corals", item.coral) then
		ReefService.toast(player, "New coral in your book: " .. Balance.corals[item.coral].displayName .. "!", "unlock")
	end
	ReefService.toast(player, Balance.corals[item.coral].displayName .. " added to your corals!", "unlock")
	publish(player)
end

local function onRestock(player: Player)
	local data = PlayerStore.get(player)
	if throttled(player) or not data then
		return
	end
	local market = current(data)
	local cost = ShopRotation.restockCost(Balance, market.restocks)
	if data.shells < cost then
		ReefService.toast(player, string.format("Need %d shells to restock", cost))
		return
	end
	ReefService.addCurrency(player, 0, -cost, "MarketRestock")
	market.restocks += 1
	market.bought = {}
	ReefService.toast(player, "Fresh stock!", "unlock")
	publish(player)
end

local function onBuyDecor(player: Player, id: unknown)
	local data = PlayerStore.get(player)
	if throttled(player) or not data or type(id) ~= "string" then
		return
	end
	for _, offer in Balance.decorShop do
		if offer.id == id then
			if data.decorOwned[id] then
				ReefService.toast(player, "You already own that")
			elseif data.shells < offer.shells then
				ReefService.toast(player, string.format("Need %d shells", offer.shells))
			else
				ReefService.addCurrency(player, 0, -offer.shells, "Decor_" .. id)
				data.decorOwned[id] = true
				LevelService.refreshDecor(player)
				ReefService.toast(player, "Decoration placed on your reef!", "unlock")
				ReefService.effect("rare", nil, 0, player.UserId)
				publish(player)
			end
			return
		end
	end
end

function MarketService.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	for name, handler in { MarketBuy = onBuy, MarketRestock = onRestock, BuyDecor = onBuyDecor } do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
		remote.OnServerEvent:Connect(handler :: any)
	end
	PlayerStore.Loaded:Connect(publish)
	-- Roll every online player's stock over when the period ends.
	task.spawn(function()
		while true do
			local _, endsAt = ShopRotation.marketPeriod(Balance, os.time())
			task.wait(math.max(1, endsAt - os.time()) + 1)
			for _, player in Players:GetPlayers() do
				publish(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return MarketService
