-- Gamepasses, developer products, and rewarded ads. IDs live in
-- Balance.json > monetization; an ID of 0 means "not set up yet" and the
-- item is skipped. Paid items only save time or add style.
--
-- Passes:   2x Pearls, Auto-Harvest, Extra Plot Slots, VIP Reef Pack
-- Products: Growth Speed-Ups (1/5/20), Rare Coral Bundle
-- Ads:      a rewarded video grants a free speed-up via its dev product

local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local CONFIG = Balance.monetization
local MAX_RECEIPTS = 50

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local lastRequest: { [Player]: number } = {}

local function throttled(player: Player): boolean
	if os.clock() - (lastRequest[player] or 0) < 1 then
		return true
	end
	lastRequest[player] = os.clock()
	return false
end

function MonetizationService.owns(player: Player, passKey: string): boolean
	return owned[player] ~= nil and owned[player][passKey] == true
end

local function publishSpeedups(player: Player)
	local data = PlayerStore.get(player)
	if data then
		player:SetAttribute("SpeedUps", data.speedups)
	end
end

local function addVipTag(player: Player, character: Model)
	local head = character:WaitForChild("Head", 5)
	if not head or head:FindFirstChild("VipTag") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.fromOffset(80, 28)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 205, 90)
	label.TextColor3 = Color3.fromRGB(60, 40, 10)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "VIP"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = tag
	tag.Parent = head
end

-- Applies a pass's effect. Safe to call more than once.
local function applyPass(player: Player, key: string)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	player:SetAttribute("Pass_" .. key, true)
	if key == "ExtraSlots" then
		player:SetAttribute("BonusSlots", CONFIG.passes.ExtraSlots.slots)
		ReefService.refreshPad(player)
	elseif key == "VIP" then
		local data = PlayerStore.get(player)
		if data and not data.vipGranted then
			data.vipGranted = true
			local coral = CONFIG.passes.VIP.coral
			ReefService.addInventory(player, coral, 1)
			data.untradeable[coral] = (data.untradeable[coral] or 0) + 1
			ReefService.addInventory(player, coral, 0)
		end
		if player.Character then
			task.spawn(addVipTag, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			addVipTag(player, character)
		end)
	end
	ReefService.incomeMultiplier(player)
end

local function checkPasses(player: Player)
	for key, pass in CONFIG.passes do
		if pass.id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and has then
				applyPass(player, key)
			end
		end
	end
	publishSpeedups(player)
end

local function productById(productId: number): (string?, any)
	for key, product in CONFIG.products do
		if product.id ~= 0 and product.id == productId then
			return key, product
		end
	end
	if CONFIG.rewardedAd.productId ~= 0 and CONFIG.rewardedAd.productId == productId then
		return "RewardedAd", CONFIG.rewardedAd
	end
	return nil, nil
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and PlayerStore.get(player)
	if not player or not data then
		-- Not loaded here; Roblox retries the receipt later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	if table.find(data.receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key, product = productById(receipt.ProductId)
	if not key then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if product.speedups then
		data.speedups += product.speedups
		publishSpeedups(player)
		ReefService.toast(player, string.format("+%d growth speed-up%s", product.speedups, if product.speedups == 1 then "" else "s"), "unlock")
	end
	if product.corals then
		for coral, count in product.corals do
			ReefService.addInventory(player, coral, count)
			-- Robux-bought corals can't be traded.
			data.untradeable[coral] = (data.untradeable[coral] or 0) + count
			ReefService.addInventory(player, coral, 0)
		end
		ReefService.toast(player, product.name .. " added to your corals!", "unlock")
	end
	table.insert(data.receipts, purchaseId)
	while #data.receipts > MAX_RECEIPTS do
		table.remove(data.receipts, 1)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onUseSpeedUp(player: Player)
	local data = PlayerStore.get(player)
	if throttled(player) or not data or data.speedups <= 0 then
		return
	end
	if ReefService.speedUp(player) then
		data.speedups -= 1
		publishSpeedups(player)
	else
		ReefService.toast(player, "No corals are growing right now")
	end
end

local function onWatchAd(player: Player)
	if throttled(player) or CONFIG.rewardedAd.productId == 0 then
		return
	end
	local ok, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(CONFIG.rewardedAd.productId)
		return AdService:ShowRewardedVideoAdAsync(player, reward)
	end)
	-- On ShowCompleted, Roblox grants the reward through processReceipt.
	if not ok or result ~= Enum.ShowAdResult.ShowCompleted then
		ReefService.toast(player, "No ad available right now. Try again later.")
	end
end

function MonetizationService.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local useSpeedUp = Instance.new("RemoteEvent")
	useSpeedUp.Name = "UseSpeedUp"
	useSpeedUp.Parent = remotes
	useSpeedUp.OnServerEvent:Connect(onUseSpeedUp)
	local watchAd = Instance.new("RemoteEvent")
	watchAd.Name = "WatchAd"
	watchAd.Parent = remotes
	watchAd.OnServerEvent:Connect(onWatchAd)

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in CONFIG.passes do
			if pass.id == passId then
				applyPass(player, key)
				ReefService.toast(player, "Thanks! " .. pass.name .. " is active.", "unlock")
			end
		end
	end)

	ReefService.addMultiplier("passes", function(player)
		local m = 1
		if MonetizationService.owns(player, "Pearls2x") then
			m *= 2
		end
		if MonetizationService.owns(player, "VIP") then
			m *= CONFIG.passes.VIP.multiplier
		end
		return m
	end)

	PlayerStore.Loaded:Connect(checkPasses)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		lastRequest[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CONFIG.autoHarvestSeconds)
			for player in owned do
				if MonetizationService.owns(player, "AutoHarvest") and player.Parent then
					ReefService.harvestAll(player)
				end
			end
		end
	end)
end

return MonetizationService
