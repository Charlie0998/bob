-- Builds each player's reef plot and handles planting, harvesting, and slot
-- purchases. All state changes happen here on the server; clients render the
-- coral models and effects from the attributes set on slot parts, and send
-- only a validated coral selection.

local AnalyticsService = game:GetService("AnalyticsService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local ReefHealth = require(ReplicatedStorage.Shared.ReefHealth)
local ReefMath = require(ReplicatedStorage.Shared.ReefMath)
local ShopRotation = require(ReplicatedStorage.Shared.ShopRotation)
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
-- Server -> all clients: (kind, slotOrPad, amount, actorUserId) for visual effects.
local effectRemote = Instance.new("RemoteEvent")
effectRemote.Name = "Effect"
effectRemote.Parent = remotes

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

-- Coral types a player may buy right now: the regular shop plus whatever the
-- rotating rare shop has in stock.
local function canBuy(coralType: string): boolean
	local def = Balance.corals[coralType]
	if not def then
		return false
	end
	if def.inShop then
		return true
	end
	local rotating = ShopRotation.current(Balance.shopRotation, os.time())
	return rotating == coralType
end

local function refreshHealth(player: Player)
	local data = PlayerStore.get(player)
	if not data then
		return
	end
	local score = ReefHealth.score(data.corals, data.slots, os.time(), Balance.offlineCapSeconds, Balance.reefHealth)
	local tier = ReefHealth.tier(score, Balance.reefHealth)
	player:SetAttribute("ReefHealth", score)
	player:SetAttribute("HealthTier", tier.name)
	player:SetAttribute("HealthMultiplier", tier.multiplier)
end
ReefService.refreshHealth = refreshHealth

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

local function anchoredPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function setCoral(tile: BasePart, coral: PlayerStore.CoralSave?)
	tile:SetAttribute("CoralType", if coral then coral.type else "")
	tile:SetAttribute("PlantedAt", if coral then coral.plantedAt else 0)
	tile:SetAttribute("BornAt", if coral then coral.bornAt or coral.plantedAt else 0)
end

local function createSlot(player: Player, state: PlayerState, slot: number)
	local base = state.plot.PrimaryPart :: BasePart
	-- A round sand tile: a cylinder turned on its side.
	local tile = anchoredPart({
		Name = "Slot" .. slot,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, CELL - 1, CELL - 1),
		CFrame = base.CFrame * slotOffset(slot) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(215, 195, 150),
		Material = Enum.Material.Sand,
	})
	tile:SetAttribute("OwnerId", player.UserId)
	tile:SetAttribute("Slot", slot)

	-- Invisible box over the slot so tapping anywhere on a tall coral counts.
	local hitbox = anchoredPart({
		Name = "Hitbox",
		Size = Vector3.new(CELL - 1, 5, CELL - 1),
		CFrame = base.CFrame * slotOffset(slot) * CFrame.new(0, 2.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
	})
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = MAX_REACH
	click.MouseClick:Connect(function(clicker)
		ReefService.onSlotClicked(clicker, tile)
	end)
	click.Parent = hitbox
	hitbox.Parent = tile

	local data = PlayerStore.get(player)
	setCoral(tile, data and data.corals[tostring(slot)])
	CollectionService:AddTag(tile, SLOT_TAG)
	tile.Parent = state.plot
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

	local rows = math.ceil(Balance.maxSlots / GRID_COLUMNS)
	local base = anchoredPart({
		Name = "Base",
		Size = Vector3.new(GRID_COLUMNS * CELL + 4, 1, rows * CELL + 4),
		CFrame = plotCFrame(state.plotIndex),
		Color = Color3.fromRGB(200, 180, 130),
		Material = Enum.Material.Sand,
	})
	base.Parent = model
	model.PrimaryPart = base

	-- Low rock border so the plot reads as its own little reef.
	local rng = Random.new(state.plotIndex)
	local halfX, halfZ = base.Size.X / 2, base.Size.Z / 2
	local perimeter = 2 * (base.Size.X + base.Size.Z)
	for i = 0, 27 do
		local d = i / 28 * perimeter
		local x, z
		if d < base.Size.X then
			x, z = -halfX + d, halfZ
		elseif d < base.Size.X + base.Size.Z then
			x, z = halfX, halfZ - (d - base.Size.X)
		elseif d < 2 * base.Size.X + base.Size.Z then
			x, z = halfX - (d - base.Size.X - base.Size.Z), -halfZ
		else
			x, z = -halfX, -halfZ + (d - 2 * base.Size.X - base.Size.Z)
		end
		if z == -halfZ and math.abs(x) < 7 then
			continue -- leave a gap at the front for the buy pad
		end
		local size = rng:NextNumber(1.6, 3)
		anchoredPart({
			Name = "Rock",
			Size = Vector3.new(size * rng:NextNumber(1, 1.6), size * 0.7, size),
			CFrame = base.CFrame
				* CFrame.new(x, 0.6, z)
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
			Color = Color3.fromRGB(110, 120, 135):Lerp(Color3.fromRGB(150, 140, 125), rng:NextNumber()),
			Material = Enum.Material.Slate,
			CanCollide = false,
		}).Parent = model
	end

	-- Name sign so visitors know whose reef this is.
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(240, 50)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	sign.MaxDistance = 200
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = player.DisplayName .. "'s Reef"
	nameLabel.Parent = sign
	sign.Parent = base

	-- Golden shell-like pad for buying slots.
	local pad = anchoredPart({
		Name = "BuyPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 7, 7),
		CFrame = base.CFrame * CFrame.new(0, 0.1, -(halfZ + 4)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 205, 90),
	})
	pad:SetAttribute("OwnerId", player.UserId)
	anchoredPart({
		Name = "Glow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.85, 5, 5),
		CFrame = pad.CFrame,
		Color = Color3.fromRGB(255, 240, 170),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	}).Parent = pad
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 235, 150))
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.Rate = 4
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.EmissionDirection = Enum.NormalId.Right -- the cylinder's axis points up
	sparkle.LightEmission = 1
	sparkle.Parent = pad
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
		local multiplier = ReefService.incomeMultiplier(player)
		local gained, newPlantedAt =
			ReefMath.harvest(coral.plantedAt, now, def.growSeconds, def.pearls, Balance.offlineCapSeconds)
		gained = math.floor(gained * multiplier)
		if gained == 0 then
			local left = ReefMath.secondsUntilReady(coral.plantedAt, now, def.growSeconds)
			toast(player, def.displayName .. " ready in " .. ReefMath.formatDuration(left))
			return
		end
		coral.plantedAt = newPlantedAt
		part:SetAttribute("PlantedAt", newPlantedAt)
		effectRemote:FireAllClients("harvest", part, gained, player.UserId)
		setPearls(player, data.pearls + gained)
		logPearls(player, Enum.AnalyticsEconomyFlowType.Source, gained, data.pearls, "Harvest_" .. coral.type)
		if data.stats.harvests == 0 then
			logOnboarding(player, ONBOARDING.firstHarvest)
		end
		data.stats.harvests += 1
		refreshHealth(player)
		toast(player, "+" .. gained .. " pearls", "pearls")
		return
	end

	local coralType = state.selected
	local def = Balance.corals[coralType]
	if not canBuy(coralType) then
		toast(player, def.displayName .. " is out of stock")
		return
	end
	if data.slots < def.unlockSlots then
		toast(player, def.displayName .. " unlocks at " .. def.unlockSlots .. " slots")
		return
	end
	if data.pearls < def.cost then
		toast(player, "Need " .. def.cost .. " pearls for " .. def.displayName)
		return
	end
	local planted = { type = coralType, plantedAt = now, bornAt = now }
	data.corals[key] = planted
	setCoral(part, planted)
	effectRemote:FireAllClients("plant", part, 0, player.UserId)
	setPearls(player, data.pearls - def.cost)
	logPearls(player, Enum.AnalyticsEconomyFlowType.Sink, def.cost, data.pearls, "Plant_" .. coralType)
	if data.stats.planted == 0 then
		logOnboarding(player, ONBOARDING.firstPlant)
	end
	data.stats.planted += 1
	refreshHealth(player)
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
	refreshHealth(player)
	toast(player, "New slot unlocked!", "unlock")
	local newTile = state.plot:FindFirstChild("Slot" .. data.slots)
	effectRemote:FireAllClients("slot", newTile, 0, player.UserId)
end

local function onSelectCoral(player: Player, coralType: unknown)
	local state = states[player]
	if not state or not allow(state) then
		return
	end
	if type(coralType) ~= "string" then
		return
	end
	if not canBuy(coralType) then
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
	refreshHealth(player)

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

-- Total harvest multiplier. Other systems (prestige, friends, passes) add
-- their factors here as they are built.
function ReefService.incomeMultiplier(player: Player): number
	return player:GetAttribute("HealthMultiplier") :: number? or 1
end

function ReefService.start()
	-- Care decays while players are away, so rescore everyone each minute.
	task.spawn(function()
		while true do
			task.wait(60)
			for player in states do
				refreshHealth(player)
			end
		end
	end)
	remotes.Parent = ReplicatedStorage
	plotsFolder.Parent = workspace
	selectRemote.OnServerEvent:Connect(onSelectCoral)
	PlayerStore.Loaded:Connect(onLoaded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return ReefService
