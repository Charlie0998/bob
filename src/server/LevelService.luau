-- Reef level and XP. Harvesting, planting, and feeding creatures give XP;
-- each level can unlock a decoration, a free plot slot, a zone, a coral, or
-- Shells (Balance.json > levels.rewards). Unlocked decorations stand behind
-- the player's reef.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)
local ReefLevel = require(ReplicatedStorage.Shared.ReefLevel)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local CONFIG = Balance.levels

local LevelService = {}

local function publish(player: Player)
	local data = PlayerStore.get(player)
	if data then
		player:SetAttribute("Level", data.level)
		player:SetAttribute("XP", data.xp)
		player:SetAttribute("XPNext", ReefLevel.xpToNext(data.level, CONFIG))
	end
end

-- Places every unlocked decoration in a row behind the plot.
local function buildDecor(player: Player)
	local data = PlayerStore.get(player)
	local plot = ReefService.getPlot(player)
	local base = plot and plot.PrimaryPart
	if not data or not plot or not base then
		return
	end
	local folder = plot:FindFirstChild("Decor") or Instance.new("Folder")
	folder.Name = "Decor"
	folder:ClearAllChildren()
	-- Level-unlocked decorations plus any bought in the Market.
	local decor = ReefLevel.unlocked(data.level, "decor", CONFIG)
	for id in data.decorOwned do
		if not table.find(decor, id) then
			table.insert(decor, id)
		end
	end
	table.sort(decor)
	local spacing = math.min(8, (base.Size.X - 6) / math.max(1, #decor))
	for i, id in decor do
		local model = DecorModels.build(id)
		local x = -((#decor - 1) * spacing) / 2 + (i - 1) * spacing
		model:PivotTo(base.CFrame * CFrame.new(x, 0.5, base.Size.Z / 2 + 4))
		model.Parent = folder
	end
	folder.Parent = plot
end

local function applyReward(player: Player, reward: any)
	if reward.decor then
		buildDecor(player)
	end
	if reward.slot then
		for _ = 1, reward.slot do
			if not ReefService.grantSlot(player) then
				ReefService.addCurrency(player, 0, 50, "LevelSlotFull")
			end
		end
	end
	if reward.coral then
		ReefService.addInventory(player, reward.coral, 1)
	end
	if reward.shells then
		ReefService.addCurrency(player, 0, reward.shells, "LevelReward")
	end
	local data = PlayerStore.get(player)
	if reward.zone and data then
		player:SetAttribute("Zones", table.concat(ReefLevel.unlocked(data.level, "zone", CONFIG), ","))
	end
end

function LevelService.refreshDecor(player: Player)
	buildDecor(player)
end

function LevelService.addXp(player: Player, amount: number)
	local data = PlayerStore.get(player)
	if not data or amount <= 0 or data.level >= CONFIG.maxLevel then
		return
	end
	data.xp += amount
	while data.level < CONFIG.maxLevel and data.xp >= ReefLevel.xpToNext(data.level, CONFIG) do
		data.xp -= ReefLevel.xpToNext(data.level, CONFIG)
		data.level += 1
		local reward = CONFIG.rewards[tostring(data.level)]
		ReefService.toast(
			player,
			if reward then string.format("Reef level %d! Unlocked: %s", data.level, reward.text) else string.format("Reef level %d!", data.level),
			"unlock"
		)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		ReefService.effect("levelup", root, data.level, player.UserId)
		ReefService.activity(player, "levelup", 1)
		if reward then
			applyReward(player, reward)
		end
	end
	publish(player)
end

function LevelService.start()
	ReefService.Activity:Connect(function(player, kind, amount)
		if kind == "harvested" then
			LevelService.addXp(player, ReefLevel.harvestXp(amount))
		elseif kind == "plant" then
			LevelService.addXp(player, CONFIG.plantXp * amount)
		elseif kind == "feed" then
			LevelService.addXp(player, CONFIG.feedXp * amount)
		end
	end)
	PlayerStore.Loaded:Connect(function(player)
		-- Let ReefService build the plot first.
		task.defer(function()
			local data = PlayerStore.get(player)
			if not data then
				return
			end
			publish(player)
			player:SetAttribute("Zones", table.concat(ReefLevel.unlocked(data.level, "zone", CONFIG), ","))
			buildDecor(player)
		end)
	end)
end

return LevelService
