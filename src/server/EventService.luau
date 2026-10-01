-- Server-wide reef events, every 12-20 minutes for 4 minutes:
--   Coral Bloom  - every coral grows twice as fast
--   Night Glow   - the reef lights up and mutations are twice as likely
--   Storm        - when it passes, a treasure chest washes up on every reef
-- Also runs the growth engine that applies Bloom and creature growth boosts.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CreatureService = require(script.Parent.CreatureService)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local CONFIG = Balance.events
local GROWTH_TICK = 5

local EventService = {}

local current: any = nil
local rng = Random.new()

local function setEvent(event: any, endsAt: number)
	current = event
	ReplicatedStorage:SetAttribute("EventId", if event then event.id else "")
	ReplicatedStorage:SetAttribute("EventName", if event then event.name else "")
	ReplicatedStorage:SetAttribute("EventText", if event then event.text else "")
	ReplicatedStorage:SetAttribute("EventEndsAt", endsAt)
end

local function pickLoot(): any
	local total = 0
	for _, loot in CONFIG.treasure.loot do
		total += loot.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, loot in CONFIG.treasure.loot do
		roll -= loot.weight
		if roll <= 0 then
			return loot
		end
	end
	return CONFIG.treasure.loot[1]
end

-- A treasure chest on the sand at the front of each reef. Only the owner can open it.
local function spawnTreasure(owner: Player)
	local plot = ReefService.getPlot(owner)
	local base = plot and plot.PrimaryPart
	if not plot or not base then
		return
	end
	local chest = Instance.new("Part")
	chest.Name = "Treasure"
	chest.Size = Vector3.new(4, 3, 3)
	chest.Transparency = 1
	chest.Anchored = true
	chest.CanCollide = false
	chest.CFrame = base.CFrame * CFrame.new(rng:NextNumber(-base.Size.X / 2 + 8, base.Size.X / 2 - 8), 2, -(base.Size.Z / 2 - 1.5))
	chest:SetAttribute("OwnerId", owner.UserId)
	local opened = false
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 80
	click.MouseClick:Connect(function(player)
		if opened or player ~= owner then
			return
		end
		opened = true
		local loot = pickLoot()
		if loot.coral ~= "" then
			ReefService.addInventory(player, loot.coral, 1)
		end
		if loot.shells > 0 then
			ReefService.addCurrency(player, 0, loot.shells, "Treasure")
		end
		ReefService.toast(player, "The storm left you " .. loot.text .. "!", "unlock")
		ReefService.effect("rare", nil, 0, player.UserId)
		ReefService.effect("feed", chest, 0, player.UserId)
		task.delay(0.5, function()
			chest:Destroy()
		end)
	end)
	click.Parent = chest
	CollectionService:AddTag(chest, "ReefTreasure")
	chest.Parent = plot
	ReefService.toast(owner, "The storm washed a treasure chest onto your reef! Tap it to open.", "unlock")
	task.delay(CONFIG.treasure.lifetimeSeconds, function()
		if chest.Parent then
			chest:Destroy()
		end
	end)
end

local function runEvents()
	setEvent(nil, 0)
	while true do
		task.wait(rng:NextNumber(CONFIG.minGapSeconds, CONFIG.maxGapSeconds))
		local total = 0
		for _, event in CONFIG.list do
			total += event.weight
		end
		local roll = rng:NextNumber(0, total)
		local chosen = CONFIG.list[1]
		for _, event in CONFIG.list do
			roll -= event.weight
			if roll <= 0 then
				chosen = event
				break
			end
		end
		setEvent(chosen, workspace:GetServerTimeNow() + CONFIG.durationSeconds)
		for _, player in Players:GetPlayers() do
			ReefService.toast(player, chosen.name .. "! " .. chosen.text, "unlock")
		end
		task.wait(CONFIG.durationSeconds)
		setEvent(nil, 0)
		if chosen.id == "Storm" then
			for _, player in Players:GetPlayers() do
				spawnTreasure(player)
			end
		end
	end
end

-- Every few seconds, push coral timers forward for Bloom and creature boosts.
local function runGrowth()
	while true do
		task.wait(GROWTH_TICK)
		local bloom = if current then current.growth else 0
		for _, player in Players:GetPlayers() do
			if PlayerStore.get(player) then
				local growth = CreatureService.activeBoosts(player).growth
				ReefService.advanceGrowth(player, function(coralType)
					local speed = bloom + (growth[coralType] or 0) + (growth["*"] or 0)
					return speed * GROWTH_TICK
				end)
			end
		end
	end
end

function EventService.start()
	ReefService.addMutationSource("event", function()
		return if current then current.mutation else 1
	end)
	task.spawn(runEvents)
	task.spawn(runGrowth)
end

return EventService
