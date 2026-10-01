-- Deep zones: the Kelp Forest, the Shipwreck, and the Deep Sea, unlocked by
-- reef level. Each zone has a market stall selling its own corals for
-- pearls (they go to your inventory, to plant at home) and a pad that takes
-- you back to your reef. Clients draw the scenery around each stall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local ReefLevel = require(ReplicatedStorage.Shared.ReefLevel)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local MARKET_REACH = 40

local ZoneService = {}

local stalls: { [string]: BasePart } = {}
local marketRemote: RemoteEvent
local lastRequest: { [Player]: number } = {}

local function throttled(player: Player): boolean
	if os.clock() - (lastRequest[player] or 0) < 0.5 then
		return true
	end
	lastRequest[player] = os.clock()
	return false
end

local function unlocked(player: Player, zoneId: string): boolean
	local data = PlayerStore.get(player)
	local at = ReefLevel.levelFor("zone", zoneId, Balance.levels)
	return data ~= nil and at ~= nil and data.level >= at
end

local function center(zoneId: string): Vector3
	local c = Balance.zones[zoneId].center
	return Vector3.new(c[1], 0, c[2])
end

local function teleport(player: Player, position: Vector3, facing: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.lookAt(position + Vector3.new(0, 4, 0), position + Vector3.new(facing.X, 4, facing.Z)))
	end
end

local function onTravel(player: Player, zoneId: unknown)
	if throttled(player) or type(zoneId) ~= "string" then
		return
	end
	if zoneId == "home" then
		player:SetAttribute("VisitingId", nil)
		local plot = ReefService.getPlot(player)
		local base = plot and plot.PrimaryPart
		if base then
			teleport(player, (base.CFrame * CFrame.new(0, 0.5, -(base.Size.Z / 2 + 8))).Position, base.Position)
		end
		return
	end
	if not Balance.zones[zoneId] then
		return
	end
	if not unlocked(player, zoneId) then
		local at = ReefLevel.levelFor("zone", zoneId, Balance.levels)
		ReefService.toast(player, string.format("%s unlocks at reef level %d", Balance.zones[zoneId].name, at or 0))
		return
	end
	-- Arrive a little in front of the market stall.
	local stall = center(zoneId)
	local arrive = stall + (Vector3.zero - stall).Unit * 18
	teleport(player, arrive, stall)
	ReefService.toast(player, "Welcome to the " .. Balance.zones[zoneId].name .. "!", "unlock")
	ReefService.activity(player, "zone", 1)
end

local function onBuy(player: Player, zoneId: unknown, coralId: unknown)
	if throttled(player) or type(zoneId) ~= "string" or type(coralId) ~= "string" then
		return
	end
	local zone = Balance.zones[zoneId]
	local data = PlayerStore.get(player)
	local stall = stalls[zoneId]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not zone or not data or not stall or not root or not table.find(zone.market, coralId) then
		return
	end
	if not unlocked(player, zoneId) or (root.Position - stall.Position).Magnitude > MARKET_REACH then
		return
	end
	local def = Balance.corals[coralId]
	if data.pearls < def.cost then
		ReefService.toast(player, string.format("Need %d pearls", def.cost))
		return
	end
	ReefService.addCurrency(player, -def.cost, 0, "Zone_" .. coralId)
	ReefService.addInventory(player, coralId, 1)
	if ReefService.discover(player, "corals", coralId) then
		ReefService.toast(player, "New coral in your book: " .. def.displayName .. "!", "unlock")
	end
	ReefService.toast(player, def.displayName .. " added to your corals. Plant it at home!", "unlock")
end

local function newPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.Wood
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function buildStall(zoneId: string)
	local zone = Balance.zones[zoneId]
	local position = center(zoneId)
	local facing = CFrame.lookAt(position, Vector3.new(0, 0, 0))
	local model = Instance.new("Model")
	model.Name = zone.name .. " Market"

	local counter = newPart({
		Name = "Counter",
		Size = Vector3.new(12, 3, 4),
		CFrame = facing * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(150, 100, 60),
	})
	counter.Parent = model
	for _, x in { -5.5, 5.5 } do
		newPart({ Size = Vector3.new(0.6, 9, 0.6), CFrame = facing * CFrame.new(x, 4.5, 1.6), Color = Color3.fromRGB(120, 80, 50) }).Parent = model
	end
	local tint = zone.tint
	newPart({
		Size = Vector3.new(13, 0.6, 5),
		CFrame = facing * CFrame.new(0, 9.2, 0.8) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = Color3.fromRGB(tint[1], tint[2], tint[3]):Lerp(Color3.fromRGB(255, 120, 120), 0.4),
		Material = Enum.Material.Fabric,
	}).Parent = model

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 60)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	sign.MaxDistance = 160
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 230, 150)
	label.TextStrokeTransparency = 0
	label.Text = zone.name .. " Market\nTap the counter"
	label.Parent = sign
	sign.Parent = counter

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = MARKET_REACH
	click.MouseClick:Connect(function(player)
		if unlocked(player, zoneId) then
			marketRemote:FireClient(player, zoneId)
		end
	end)
	click.Parent = counter

	-- A glowing pad that takes you home.
	local pad = newPart({
		Name = "HomePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 7, 7),
		CFrame = facing * CFrame.new(10, 0.3, -8) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(120, 230, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local padSign = sign:Clone()
	padSign.StudsOffsetWorldSpace = Vector3.new(0, 4, 0);
	(padSign:FindFirstChildOfClass("TextLabel") :: TextLabel).Text = "Tap to go home"
	padSign.Parent = pad
	local padClick = Instance.new("ClickDetector")
	padClick.MaxActivationDistance = MARKET_REACH
	padClick.MouseClick:Connect(function(player)
		onTravel(player, "home")
	end)
	padClick.Parent = pad
	pad.Parent = model

	model.Parent = workspace
	stalls[zoneId] = counter
end

function ZoneService.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local travel = Instance.new("RemoteEvent")
	travel.Name = "TravelZone"
	travel.Parent = remotes
	travel.OnServerEvent:Connect(onTravel)
	local buy = Instance.new("RemoteEvent")
	buy.Name = "BuyZoneCoral"
	buy.Parent = remotes
	buy.OnServerEvent:Connect(onBuy)
	marketRemote = Instance.new("RemoteEvent")
	marketRemote.Name = "OpenZoneMarket"
	marketRemote.Parent = remotes

	for zoneId in Balance.zones do
		buildStall(zoneId)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ZoneService
