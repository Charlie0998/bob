-- Builds each player's reef plot and handles planting, harvesting, and slot
-- purchases. All state changes happen here on the server; clients only render
-- the attributes set on slot parts and send a validated coral selection.

local AnalyticsService = game:GetService("AnalyticsService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local ReefMath = require(ReplicatedStorage.Shared.ReefMath)
local PlayerStore = require(script.Parent.PlayerStore)

local SLOT_TAG = "ReefSlot"
local PAD_TAG = "ReefBuyPad"
local GRID_COLUMNS = 8
local CELL = 6
local PLOT_RING = 8
local PLOT_RADIUS = 70
local RING_STEP = 60
local MAX_REACH = 80 -- studs between the player and the part they tap
local RATE_CAPACITY = 10
local RATE_REFILL_PER_SECOND = 6

local ONBOARDING = {
	joined = { 1, "Joined" },
	firstPlant = { 2, "First coral planted" },
	firstHarvest = { 3, "First harvest" },
	firstSlot = { 4, "First slot bought" },
}

local ReefService = {}

type PlayerState = {
	plot: Model,
	plotIndex: number,
	selected: string,
	tokens: number,
	lastRefill: number,
}

local states: { [Player]: PlayerState } = {}
local usedPlots: { [number]: boolean } = {}

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local toastRemote = Instance.new("RemoteEvent")
toastRemote.Name = "Toast"
toastRemote.Parent = remotes
local selectRemote = Instance.new("RemoteEvent")
selectRemote.Name = "SelectCoral"
selectRemote.Parent = remotes

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Reefs"

local function safeLog(fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warn("[ReefService] analytics:", err)
	end
end

local function logOnboarding(player: Player, step: { any })
	safeLog(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step[1], step[2])
	end)
end

local function logPearls(player: Player, flow: Enum.AnalyticsEconomyFlowType, amount: number, balance: number, sku: string)
	local transaction = if flow == Enum.AnalyticsEconomyFlowType.Source
		then Enum.AnalyticsEconomyTransactionType.Gameplay.Name
		else Enum.AnalyticsEconomyTransactionType.Shop.Name
	safeLog(function()
		AnalyticsService:LogEconomyEvent(player, flow, "Pearls", amount, balance, transaction, sku)
	end)
end

local function toast(player: Player, text: string, kind: string?)
	toastRemote:FireClient(player, text, kind or "info")
end

-- Token bucket so auto-clickers can't flood the server.
local function allow(state: PlayerState): boolean
	local now = os.clock()
	state.tokens = math.min(RATE_CAPACITY, state.tokens + (now - state.lastRefill) * RATE_REFILL_PER_SECOND)
	state.lastRefill = now
	if state.tokens < 1 then
		return false
	end
	state.tokens -= 1
	return true
end

local function inReach(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= MAX_REACH
end

local function setPearls(player: Player, pearls: number)
	local data = PlayerStore.get(player)
	if not data then
		return
	end
	data.pearls = pearls
	player:SetAttribute("Pearls", pearls)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild("Pearls") :: IntValue?
	if value then
		value.Value = pearls
	end
end

local function plotCFrame(index: number): CFrame
	local ring = (index - 1) // PLOT_RING
	local angle = ((index - 1) % PLOT_RING) / PLOT_RING * math.pi * 2
	local radius = PLOT_RADIUS + ring * RING_STEP
	local position = Vector3.new(math.cos(angle) * radius, 0.5, math.sin(angle) * radius)
	return CFrame.lookAt(position, Vector3.new(0, 0.5, 0))
end

local function slotOffset(slot: number): CFrame
	local rows = math.ceil(Balance.maxSlots / GRID_COLUMNS)
	local col = (slot - 1) % GRID_COLUMNS
	local row = (slot - 1) // GRID_COLUMNS
	return CFrame.new((col - (GRID_COLUMNS - 1) / 2) * CELL, 0.7, (row - (rows - 1) / 2) * CELL)
end

local function renderCoral(slotPart: BasePart, coralType: string?)
	local existing = slotPart:FindFirstChild("Coral")
	if existing then
		existing:Destroy()
	end
	slotPart:SetAttribute("CoralType", coralType or "")
	if not coralType then
		return
	end
	local def = Balance.corals[coralType]
	local coral = Instance.new("Part")
	coral.Name = "Coral"
	coral.Shape = Enum.PartType.Ball
	coral.Size = Vector3.new(3, 3, 3)
	coral.Color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])
	coral.Material = if def.rarity == "Epic" or def.rarity == "Legendary" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	coral.Anchored = true
	coral.CanCollide = false
	coral.CanQuery = false
	coral.CFrame = slotPart.CFrame * CFrame.new(0, 1.5, 0)
	coral.Parent = slotPart
end

local function createSlot(player: Player, state: PlayerState, slot: number)
	local base = state.plot.PrimaryPart :: BasePart
	local part = Instance.new("Part")
	part.Name = "Slot" .. slot
	part.Size = Vector3.new(CELL - 1, 0.4, CELL - 1)
	part.Color = Color3.fromRGB(236, 214, 160)
	part.Material = Enum.Material.Sand
	part.Anchored = true
	part.CFrame = base.CFrame * slotOffset(slot)
	part:SetAttribute("OwnerId", player.UserId)
	part:SetAttribute("Slot", slot)
	part:SetAttribute("CoralType", "")
	part:SetAttribute("PlantedAt", 0)

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = MAX_REACH
	click.MouseClick:Connect(function(clicker)
		ReefService.onSlotClicked(clicker, part)
	end)
	click.Parent = part

	CollectionService:AddTag(part, SLOT_TAG)
	part.Parent = state.plot

	local data = PlayerStore.get(player)
	local coral = data and data.corals[tostring(slot)]
	if coral then
		part:SetAttribute("PlantedAt", coral.plantedAt)
		renderCoral(part, coral.type)
	end
end

local function updatePad(player: Player, state: PlayerState)
	local data = PlayerStore.get(player)
	local pad = state.plot:FindFirstChild("BuyPad") :: BasePart?
	if not data or not pad then
		return
	end
	local full = data.slots >= Balance.maxSlots
	pad:SetAttribute("Cost", if full then -1 else ReefMath.slotCost(data.slots, Balance))
end

local function buildPlot(player: Player, state: PlayerState)
	local model = Instance.new("Model")
	model.Name = player.Name .. "'s Reef"

	local base = Instance.new("Part")
	base.Name = "Base"
	local rows = math.ceil(Balance.maxSlots / GRID_COLUMNS)
	base.Size = Vector3.new(GRID_COLUMNS * CELL + 4, 1, rows * CELL + 4)
	base.CFrame = plotCFrame(state.plotIndex)
	base.Color = Color3.fromRGB(70, 150, 170)
	base.Material = Enum.Material.SmoothPlastic
	base.Anchored = true
	base.Parent = model
	model.PrimaryPart = base

	local pad = Instance.new("Part")
	pad.Name = "BuyPad"
	pad.Size = Vector3.new(8, 1, 4)
	pad.CFrame = base.CFrame * CFrame.new(0, 0.2, -(base.Size.Z / 2 + 3))
	pad.Color = Color3.fromRGB(255, 210, 90)
	pad.Material = Enum.Material.SmoothPlastic
	pad.Anchored = true
	pad:SetAttribute("OwnerId", player.UserId)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = MAX_REACH
	click.MouseClick:Connect(function(clicker)
		ReefService.onBuySlot(clicker, pad)
	end)
	click.Parent = pad
	CollectionService:AddTag(pad, PAD_TAG)
	pad.Parent = model

	model.Parent = plotsFolder
	state.plot = model
end

function ReefService.onSlotClicked(player: Player, part: BasePart)
	local state = states[player]
	local data = PlayerStore.get(player)
	if not state or not data or part:GetAttribute("OwnerId") ~= player.UserId then
		return
	end
	if not allow(state) or not inReach(player, part) then
		return
	end

	local slot = part:GetAttribute("Slot") :: number
	local key = tostring(slot)
	local coral = data.corals[key]
	local now = os.time()

	if coral then
		local def = Balance.corals[coral.type]
		local gained, newPlantedAt = ReefMath.harvest(coral.plantedAt, now, def.growSeconds, def.pearls, Balance.offlineCapSeconds)
		if gained == 0 then
			local left = ReefMath.secondsUntilReady(coral.plantedAt, now, def.growSeconds)
			toast(player, def.displayName .. " ready in " .. ReefMath.formatDuration(left))
			return
		end
		coral.plantedAt = newPlantedAt
		part:SetAttribute("PlantedAt", newPlantedAt)
		setPearls(player, data.pearls + gained)
		logPearls(player, Enum.AnalyticsEconomyFlowType.Source, gained, data.pearls, "Harvest_" .. coral.type)
		if data.stats.harvests == 0 then
			logOnboarding(player, ONBOARDING.firstHarvest)
		end
		data.stats.harvests += 1
		toast(player, "+" .. gained .. " pearls", "pearls")
		return
	end

	local coralType = state.selected
	local def = Balance.corals[coralType]
	if data.slots < def.unlockSlots then
		toast(player, def.displayName .. " unlocks at " .. def.unlockSlots .. " slots")
		return
	end
	if data.pearls < def.cost then
		toast(player, "Need " .. def.cost .. " pearls for " .. def.displayName)
		return
	end
	data.corals[key] = { type = coralType, plantedAt = now }
	part:SetAttribute("PlantedAt", now)
	renderCoral(part, coralType)
	setPearls(player, data.pearls - def.cost)
	logPearls(player, Enum.AnalyticsEconomyFlowType.Sink, def.cost, data.pearls, "Plant_" .. coralType)
	if data.stats.planted == 0 then
		logOnboarding(player, ONBOARDING.firstPlant)
	end
	data.stats.planted += 1
end

function ReefService.onBuySlot(player: Player, pad: BasePart)
	local state = states[player]
	local data = PlayerStore.get(player)
	if not state or not data or pad:GetAttribute("OwnerId") ~= player.UserId then
		return
	end
	if not allow(state) or not inReach(player, pad) then
		return
	end
	if data.slots >= Balance.maxSlots then
		toast(player, "Your reef is full size!")
		return
	end
	local cost = ReefMath.slotCost(data.slots, Balance)
	if data.pearls < cost then
		toast(player, "Need " .. cost .. " pearls for a new slot")
		return
	end
	if data.slots == Balance.startingSlots then
		logOnboarding(player, ONBOARDING.firstSlot)
	end
	data.slots += 1
	setPearls(player, data.pearls - cost)
	logPearls(player, Enum.AnalyticsEconomyFlowType.Sink, cost, data.pearls, "Slot_" .. data.slots)
	player:SetAttribute("Slots", data.slots)
	createSlot(player, state, data.slots)
	updatePad(player, state)
	toast(player, "New slot unlocked!", "unlock")
end

local function onSelectCoral(player: Player, coralType: unknown)
	local state = states[player]
	if not state or not allow(state) then
		return
	end
	if type(coralType) ~= "string" then
		return
	end
	local def = Balance.corals[coralType]
	if not def or not def.inShop then
		return
	end
	state.selected = coralType
	player:SetAttribute("SelectedCoral", coralType)
end

local function onLoaded(player: Player)
	local data = PlayerStore.get(player)
	if not data then
		return
	end

	local plotIndex = 1
	while usedPlots[plotIndex] do
		plotIndex += 1
	end
	usedPlots[plotIndex] = true

	local state: PlayerState = {
		plot = nil :: any,
		plotIndex = plotIndex,
		selected = Balance.starterCoral,
		tokens = RATE_CAPACITY,
		lastRefill = os.clock(),
	}
	states[player] = state

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local pearls = Instance.new("IntValue")
	pearls.Name = "Pearls"
	pearls.Parent = leaderstats
	leaderstats.Parent = player

	buildPlot(player, state)
	for slot = 1, data.slots do
		createSlot(player, state, slot)
	end
	updatePad(player, state)
	setPearls(player, data.pearls)
	player:SetAttribute("SelectedCoral", state.selected)
	player:SetAttribute("Slots", data.slots)
	player:SetAttribute("PlotIndex", plotIndex)

	if data.stats.planted == 0 and data.stats.harvests == 0 then
		logOnboarding(player, ONBOARDING.joined)
	end

	-- Spawn the player at their own reef.
	local function moveToPlot(character: Model)
		local base = state.plot.PrimaryPart :: BasePart
		task.defer(function()
			character:PivotTo(base.CFrame * CFrame.new(0, 5, -(base.Size.Z / 2 + 8)) * CFrame.Angles(0, math.pi, 0))
		end)
	end
	player.CharacterAdded:Connect(moveToPlot)
	if player.Character then
		moveToPlot(player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	usedPlots[state.plotIndex] = nil
	if state.plot then
		state.plot:Destroy()
	end
end

function ReefService.start()
	remotes.Parent = ReplicatedStorage
	plotsFolder.Parent = workspace
	selectRemote.OnServerEvent:Connect(onSelectCoral)
	PlayerStore.Loaded:Connect(onLoaded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return ReefService
