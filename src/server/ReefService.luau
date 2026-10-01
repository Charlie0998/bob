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
local PlotLayout = require(ReplicatedStorage.Shared.PlotLayout)
local ReefMath = require(ReplicatedStorage.Shared.ReefMath)
local ShopRotation = require(ReplicatedStorage.Shared.ShopRotation)
local PlayerStore = require(script.Parent.PlayerStore)

local SLOT_TAG = "ReefSlot"
local PAD_TAG = "ReefBuyPad"
local GRID_COLUMNS = 8
local CELL = 6
local MAX_REACH = 80 -- studs between the player and the part they tap
-- The plot grid has room for the base cap plus the Extra Plot Slots pass.
local GRID_CAPACITY = Balance.maxSlots + Balance.monetization.passes.ExtraSlots.slots
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
local function canBuy(coralType: string, data: PlayerStore.PlayerData?): boolean
	local def = Balance.corals[coralType]
	if not def then
		return false
	end
	if data and (data.inventory[coralType] or 0) > 0 then
		return true
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

local function setShells(player: Player, shells: number)
	local data = PlayerStore.get(player)
	if data then
		data.shells = shells
		player:SetAttribute("Shells", shells)
	end
end

-- Publishes the inventory as attributes ("Inv_GlowingTube" = 2) for the HUD.
local function syncInventory(player: Player)
	local data = PlayerStore.get(player)
	if not data then
		return
	end
	for coralType in Balance.corals do
		player:SetAttribute("Inv_" .. coralType, data.inventory[coralType] or 0)
		player:SetAttribute("Locked_" .. coralType, data.untradeable[coralType] or 0)
	end
end

function ReefService.addCurrency(player: Player, pearls: number, shells: number, sku: string)
	local data = PlayerStore.get(player)
	if not data then
		return
	end
	if pearls ~= 0 then
		setPearls(player, data.pearls + pearls)
		logPearls(player, Enum.AnalyticsEconomyFlowType.Source, pearls, data.pearls, sku)
		if pearls > 0 then
			ReefService.activity(player, "pearls", pearls)
		end
	end
	if shells ~= 0 then
		setShells(player, data.shells + shells)
	end
end

function ReefService.addInventory(player: Player, coralType: string, count: number)
	local data = PlayerStore.get(player)
	if data then
		data.inventory[coralType] = (data.inventory[coralType] or 0) + count
		syncInventory(player)
	end
end

function ReefService.getPlot(player: Player): Model?
	local state = states[player]
	return state and state.plot
end

function ReefService.toast(player: Player, text: string, kind: string?)
	toast(player, text, kind)
end

function ReefService.effect(kind: string, target: Instance?, amount: number, actorId: number)
	effectRemote:FireAllClients(kind, target, amount, actorId)
end

local activitySignal = Instance.new("BindableEvent")
-- Fires with (player, kind, amount) for goal tracking: "harvest", "plant",
-- "slot", "pearls", plus kinds other services report through ReefService.activity.
ReefService.Activity = activitySignal.Event
function ReefService.activity(player: Player, kind: string, amount: number)
	activitySignal:Fire(player, kind, amount)
end

local discoveredSignal = Instance.new("BindableEvent")
-- Fires with (player, kind, id) when something is discovered for the first time.
ReefService.Discovered = discoveredSignal.Event

function ReefService.discover(player: Player, kind: "corals" | "creatures", id: string): boolean
	local data = PlayerStore.get(player)
	if not data or data.discovered[kind][id] then
		return false
	end
	data.discovered[kind][id] = true
	player:SetAttribute("Found_" .. id, true)
	effectRemote:FireClient(player, "rare", nil, 0, player.UserId)
	discoveredSignal:Fire(player, kind, id)
	return true
end

local function slotOffset(slot: number): CFrame
	local rows = math.ceil(GRID_CAPACITY / GRID_COLUMNS)
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
	tile:SetAttribute("Mutation", if coral then coral.mutation or "" else "")
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
	local full = data.slots >= ReefService.maxSlots(player)
	pad:SetAttribute("Cost", if full then -1 else ReefMath.slotCost(data.slots, Balance))
end

local function buildPlot(player: Player, state: PlayerState)
	local model = Instance.new("Model")
	model.Name = player.Name .. "'s Reef"

	local rows = math.ceil(GRID_CAPACITY / GRID_COLUMNS)
	local base = anchoredPart({
		Name = "Base",
		Size = Vector3.new(GRID_COLUMNS * CELL + 4, 1, rows * CELL + 4),
		CFrame = PlotLayout.cframe(state.plotIndex),
		Color = Color3.fromRGB(200, 180, 130),
		Material = Enum.Material.Sand,
	})
	base.Parent = model
	model.PrimaryPart = base

	-- The rim, pillars, arch, and the owner's name banner are drawn by each
	-- client (PlotDecor).
	local halfZ = base.Size.Z / 2
	model:SetAttribute("OwnerId", player.UserId)

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

-- Harvests one tile if it's ready and returns the pearls earned. `quiet`
-- skips the "not ready" and "+N" toasts (used by Auto-Harvest).
function ReefService.harvestTile(player: Player, part: BasePart, quiet: boolean): number
	local data = PlayerStore.get(player)
	local coral = data and data.corals[tostring(part:GetAttribute("Slot"))]
	if not data or not coral then
		return 0
	end
	local now = os.time()
	local def = Balance.corals[coral.type]
	local gained, newPlantedAt = ReefMath.harvest(coral.plantedAt, now, def.growSeconds, def.pearls, Balance.offlineCapSeconds)
	gained = math.floor(gained * ReefService.incomeMultiplier(player) * ReefService.mutationMultiplierFor(coral.mutation))
	if gained == 0 then
		if not quiet then
			local left = ReefMath.secondsUntilReady(coral.plantedAt, now, def.growSeconds)
			toast(player, def.displayName .. " ready in " .. ReefMath.formatDuration(left))
		end
		return 0
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
	ReefService.activity(player, "harvest", 1)
	ReefService.activity(player, "harvest_" .. coral.type, 1)
	ReefService.activity(player, "harvested", gained)
	ReefService.activity(player, "pearls", gained)
	if not quiet then
		toast(player, "+" .. gained .. " pearls", "pearls")
	end
	return gained
end

function ReefService.harvestAll(player: Player): number
	local plot = ReefService.getPlot(player)
	local total = 0
	if plot then
		for _, child in plot:GetChildren() do
			if child:IsA("BasePart") and CollectionService:HasTag(child, SLOT_TAG) then
				total += ReefService.harvestTile(player, child, true)
			end
		end
	end
	return total
end

-- Finishes the coral that is closest to ready. Returns false if none is growing.
function ReefService.speedUp(player: Player): boolean
	local data = PlayerStore.get(player)
	local plot = ReefService.getPlot(player)
	if not data or not plot then
		return false
	end
	local now = os.time()
	local bestKey, bestLeft = nil, math.huge
	for key, coral in data.corals do
		local left = ReefMath.secondsUntilReady(coral.plantedAt, now, Balance.corals[coral.type].growSeconds)
		if left > 0 and left < bestLeft then
			bestKey, bestLeft = key, left
		end
	end
	if not bestKey then
		return false
	end
	local coral = data.corals[bestKey]
	local grow = Balance.corals[coral.type].growSeconds
	coral.plantedAt = now - grow
	coral.bornAt = math.min(coral.bornAt or coral.plantedAt, now - grow)
	local tile = plot:FindFirstChild("Slot" .. bestKey) :: BasePart?
	if tile then
		setCoral(tile, coral)
		effectRemote:FireAllClients("plant", tile, 0, player.UserId)
	end
	return true
end

-- Slot cap for this player (the Extra Plot Slots pass raises it).
function ReefService.maxSlots(player: Player): number
	return Balance.maxSlots + (player:GetAttribute("BonusSlots") :: number? or 0)
end

-- Mutation chance multipliers registered by other systems (events, creatures).
local mutationSources: { [string]: (Player) -> number } = {}
function ReefService.addMutationSource(name: string, source: (Player) -> number)
	mutationSources[name] = source
end

local mutationRng = Random.new()

-- Rolls the rarest mutation first, so each keeps its own odds.
function ReefService.rollMutation(player: Player): any
	local factor = 1
	for _, source in mutationSources do
		factor *= source(player)
	end
	for i = #Balance.mutations, 1, -1 do
		local mutation = Balance.mutations[i]
		if mutationRng:NextNumber() < mutation.chance * factor then
			return mutation
		end
	end
	return nil
end

function ReefService.mutationMultiplierFor(mutationId: string?): number
	for _, mutation in Balance.mutations do
		if mutation.id == mutationId then
			return mutation.multiplier
		end
	end
	return 1
end

-- Moves coral timers forward (events and creature boosts make corals grow
-- faster). `extraFor(coralType)` returns the extra seconds of growth.
function ReefService.advanceGrowth(player: Player, extraFor: (string) -> number)
	local data = PlayerStore.get(player)
	local plot = ReefService.getPlot(player)
	if not data or not plot then
		return
	end
	for key, coral in data.corals do
		local extra = extraFor(coral.type)
		if extra > 0 then
			coral.plantedAt -= extra
			coral.bornAt = (coral.bornAt or coral.plantedAt) - extra
			local tile = plot:FindFirstChild("Slot" .. key) :: BasePart?
			if tile then
				setCoral(tile, coral)
			end
		end
	end
end

-- Adds one slot for free (level rewards). Returns false if the reef is full.
function ReefService.grantSlot(player: Player): boolean
	local state = states[player]
	local data = PlayerStore.get(player)
	if not state or not data or data.slots >= ReefService.maxSlots(player) then
		return false
	end
	data.slots += 1
	player:SetAttribute("Slots", data.slots)
	createSlot(player, state, data.slots)
	updatePad(player, state)
	refreshHealth(player)
	local tile = state.plot:FindFirstChild("Slot" .. data.slots)
	effectRemote:FireAllClients("slot", tile, 0, player.UserId)
	return true
end

function ReefService.refreshPad(player: Player)
	local state = states[player]
	if state then
		updatePad(player, state)
	end
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
		ReefService.harvestTile(player, part, false)
		return
	end

	local coralType = state.selected
	local def = Balance.corals[coralType]
	if not canBuy(coralType, data) then
		toast(player, def.displayName .. " is out of stock")
		return
	end
	local fromInventory = (data.inventory[coralType] or 0) > 0
	if not fromInventory then
		if data.slots < def.unlockSlots then
			toast(player, def.displayName .. " unlocks at " .. def.unlockSlots .. " slots")
			return
		end
		if data.pearls < def.cost then
			toast(player, "Need " .. def.cost .. " pearls for " .. def.displayName)
			return
		end
	end
	local planted: PlayerStore.CoralSave = { type = coralType, plantedAt = now, bornAt = now }
	-- A small chance the new coral grows mutated, worth much more.
	local mutation = ReefService.rollMutation(player)
	if mutation then
		planted.mutation = mutation.id
		toast(player, string.format("Your %s grew %s! It earns x%d pearls.", def.displayName, mutation.text, mutation.multiplier), "unlock")
		ReefService.activity(player, "mutation", 1)
		effectRemote:FireClient(player, "rare", nil, 0, player.UserId)
	end
	data.corals[key] = planted
	setCoral(part, planted)
	effectRemote:FireAllClients("plant", part, 0, player.UserId)
	if fromInventory then
		data.inventory[coralType] -= 1
		-- Plant tradeable copies first, so Robux-bought ones stay locked to the owner.
		data.untradeable[coralType] = math.min(data.untradeable[coralType] or 0, data.inventory[coralType])
		syncInventory(player)
		if data.inventory[coralType] <= 0 and not Balance.corals[coralType].inShop then
			state.selected = Balance.starterCoral
			player:SetAttribute("SelectedCoral", state.selected)
		end
	else
		setPearls(player, data.pearls - def.cost)
		logPearls(player, Enum.AnalyticsEconomyFlowType.Sink, def.cost, data.pearls, "Plant_" .. coralType)
	end
	if ReefService.discover(player, "corals", coralType) then
		toast(player, "New coral in your book: " .. def.displayName .. "!", "unlock")
	end
	if data.stats.planted == 0 then
		logOnboarding(player, ONBOARDING.firstPlant)
	end
	data.stats.planted += 1
	refreshHealth(player)
	ReefService.activity(player, "plant", 1)
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
	if data.slots >= ReefService.maxSlots(player) then
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
	ReefService.activity(player, "slot", 1)
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
	if not canBuy(coralType, PlayerStore.get(player)) then
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
	setShells(player, data.shells)
	syncInventory(player)
	for _, found in data.discovered do
		for id in found do
			player:SetAttribute("Found_" .. id, true)
		end
	end

	if data.stats.planted == 0 and data.stats.harvests == 0 then
		logOnboarding(player, ONBOARDING.joined)
	end

	-- Spawn the player at their own reef. Roblox places a new character at
	-- the SpawnLocation after CharacterAdded fires, so wait until it's really
	-- in the world, move it, then check again a moment later.
	local function moveToPlot(character: Model)
		local base = state.plot.PrimaryPart :: BasePart
		local target = base.CFrame * CFrame.new(0, 5, -(base.Size.Z / 2 + 8)) * CFrame.Angles(0, math.pi, 0)
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
			while root and not character:IsDescendantOf(workspace) and character.Parent ~= nil do
				task.wait()
			end
			for _ = 1, 3 do
				if not root or not character:IsDescendantOf(workspace) then
					return
				end
				if (root.Position - target.Position).Magnitude > 20 then
					character:PivotTo(target)
				end
				task.wait(0.5)
			end
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

-- Extra income factors registered by other systems (prestige, friends,
-- passes). Each returns a multiplier for the player.
local multiplierSources: { [string]: (Player) -> number } = {}
function ReefService.addMultiplier(name: string, source: (Player) -> number)
	multiplierSources[name] = source
end

-- Total harvest multiplier: reef health times every registered source.
function ReefService.incomeMultiplier(player: Player): number
	local total = player:GetAttribute("HealthMultiplier") :: number? or 1
	for _, source in multiplierSources do
		total *= source(player)
	end
	player:SetAttribute("IncomeMultiplier", total)
	return total
end

-- Tide Reset: clears the plot back to a fresh start. Shells, inventory,
-- discoveries, book rewards, and prestige level are kept by the caller.
function ReefService.resetReef(player: Player)
	local state = states[player]
	local data = PlayerStore.get(player)
	if not state or not data then
		return
	end
	for _, child in state.plot:GetChildren() do
		if CollectionService:HasTag(child, SLOT_TAG) or CollectionService:HasTag(child, "ReefCreature") then
			child:Destroy()
		end
	end
	local now = os.time()
	data.pearls = Balance.startingPearls
	data.slots = Balance.startingSlots
	data.corals = { ["1"] = { type = Balance.starterCoral, plantedAt = now, bornAt = now } }
	for slot = 1, data.slots do
		createSlot(player, state, slot)
	end
	updatePad(player, state)
	setPearls(player, data.pearls)
	player:SetAttribute("Slots", data.slots)
	refreshHealth(player)
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
