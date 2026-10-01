-- Places to explore, built on the client: the Market plaza at spawn (stalls,
-- awnings, lanterns, crates, a shopkeeper), a sunken ruin, a lighthouse on a
-- rock island, a whale skeleton, hydrothermal vents, a giant clam that opens
-- to show its pearl, boats drifting on the surface, and a whale silhouette
-- far overhead. Far-away landmarks are hidden to keep the frame rate up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)

local WORLD = Balance.world
local SURFACE = WORLD.surfaceHeight
local HIDE_DISTANCE = 420 -- landmarks farther than this from the camera are hidden
local LOD_CHECK_SECONDS = 1

local Landmarks = {}

local root = Instance.new("Folder")
root.Name = "Landmarks"

type Group = { model: Model, center: Vector3, alwaysShown: boolean }
local groups: { Group } = {}

local function spot(angleDeg: number, radius: number): Vector3
	local a = math.rad(angleDeg)
	return Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end

local function group(name: string, center: Vector3, alwaysShown: boolean?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = root
	table.insert(groups, { model = model, center = center, alwaysShown = alwaysShown == true })
	return model
end

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function ellipsoid(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, { Size = size, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function cylinderBetween(parent: Instance, a: Vector3, b: Vector3, radius: number, color: Color3, material: Enum.Material?): Part
	local direction = b - a
	local up = if math.abs(direction.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return part(parent, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(direction.Magnitude, radius * 2, radius * 2),
		CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function light(p: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Parent = p
end

-- A floating name sign `width` studs wide. It is sized in studs, not pixels,
-- so far-away signs shrink instead of piling on top of each other.
local function sign(p: BasePart, text: string, height: number, color: Color3, width: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width, width * 0.21)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 140
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = p
end

local function bubbles(p: BasePart, rate: number, color: Color3?)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color or Color3.fromRGB(230, 250, 255))
	e.Transparency = NumberSequence.new(0.3, 1)
	e.Size = NumberSequence.new(0.3, 0.8)
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = rate
	e.Speed = NumberRange.new(4, 7)
	e.SpreadAngle = Vector2.new(10, 10)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = p
	return e
end

-- Market plaza ---------------------------------------------------------------

local WOOD = Color3.fromRGB(130, 90, 55)
local DARK_WOOD = Color3.fromRGB(95, 65, 40)
local AWNINGS = {
	{ Color3.fromRGB(240, 96, 110), Color3.fromRGB(255, 240, 225) },
	{ Color3.fromRGB(38, 172, 186), Color3.fromRGB(255, 240, 225) },
	{ Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 240, 225) },
	{ Color3.fromRGB(140, 92, 222), Color3.fromRGB(255, 240, 225) },
}

local openMarket: () -> () = function() end

local function promptOn(p: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Market"
	prompt.ObjectText = "Coral Market"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
	prompt.Triggered:Connect(function()
		openMarket()
	end)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 60
	click.MouseClick:Connect(function()
		openMarket()
	end)
	click.Parent = p
end

local function stall(parent: Instance, frame: CFrame, colors: { Color3 }, title: string)
	local counter = part(parent, { Name = "Counter", Size = Vector3.new(10, 3, 3.5), CFrame = frame * CFrame.new(0, 1.5, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, CanCollide = true, CanQuery = true })
	part(parent, { Size = Vector3.new(10.4, 0.4, 3.9), CFrame = frame * CFrame.new(0, 3.1, 0), Color = DARK_WOOD, Material = Enum.Material.Wood })
	for _, x in { -4.8, 4.8 } do
		for _, z in { -1.6, 3.4 } do
			part(parent, { Size = Vector3.new(0.5, 8, 0.5), CFrame = frame * CFrame.new(x, 4, z), Color = DARK_WOOD, Material = Enum.Material.Wood })
		end
	end
	-- A striped awning, tilted toward the customers.
	for i = 0, 7 do
		part(parent, {
			Size = Vector3.new(1.4, 0.25, 6.2),
			CFrame = frame * CFrame.new(-4.9 + i * 1.4, 8.3, 0.9) * CFrame.Angles(math.rad(-14), 0, 0),
			Color = colors[i % 2 + 1],
			Material = Enum.Material.Fabric,
		})
	end
	-- Hanging lantern.
	local lantern = part(parent, { Size = Vector3.new(0.8, 1.1, 0.8), CFrame = frame * CFrame.new(4.2, 6.7, -1.8), Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon })
	light(lantern, Color3.fromRGB(255, 210, 140), 14, 1.4)
	-- Goods on the counter: little coral balls and shells.
	for i = 1, 4 do
		ellipsoid(parent, Vector3.new(1, 0.8, 1), frame * CFrame.new(-3.6 + i * 1.5, 3.7, 0.2), colors[1]:Lerp(Color3.fromRGB(255, 255, 255), i * 0.12))
	end
	-- Crates and a barrel beside the stall.
	part(parent, { Size = Vector3.one * 2.2, CFrame = frame * CFrame.new(-6.6, 1.1, 1) * CFrame.Angles(0, 0.3, 0), Color = Color3.fromRGB(160, 115, 70), Material = Enum.Material.WoodPlanks, CanCollide = true })
	part(parent, { Size = Vector3.one * 1.6, CFrame = frame * CFrame.new(-6.4, 3, 1.1) * CFrame.Angles(0, -0.2, 0), Color = Color3.fromRGB(175, 125, 80), Material = Enum.Material.WoodPlanks })
	part(parent, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 2, 2), CFrame = frame * CFrame.new(6.6, 1.3, 1) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood, CanCollide = true })
	sign(counter, title, 8.5, Color3.fromRGB(255, 230, 150), 9)
	promptOn(counter)
end

-- A friendly blocky shopkeeper who bobs and waves.
local shopkeeper: { parts: { BasePart }, offsets: { CFrame }, base: CFrame, arm: number }? = nil

local function buildShopkeeper(parent: Instance, frame: CFrame)
	local skin = Color3.fromRGB(240, 200, 160)
	local parts, offsets = {}, {}
	local function add(p: BasePart, offset: CFrame)
		table.insert(parts, p)
		table.insert(offsets, offset)
	end
	add(part(parent, { Size = Vector3.new(2, 2, 1), Color = Color3.fromRGB(38, 140, 160) }), CFrame.new(0, 3, 0))
	add(part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Color = skin }), CFrame.new(0, 4.8, 0))
	add(part(parent, { Size = Vector3.new(0.9, 2, 1), Color = Color3.fromRGB(60, 70, 110) }), CFrame.new(-0.5, 1, 0))
	add(part(parent, { Size = Vector3.new(0.9, 2, 1), Color = Color3.fromRGB(60, 70, 110) }), CFrame.new(0.5, 1, 0))
	add(part(parent, { Size = Vector3.new(0.8, 2, 0.8), Color = skin }), CFrame.new(-1.45, 3, 0))
	local armIndex = #parts + 1
	add(part(parent, { Size = Vector3.new(0.8, 2, 0.8), Color = skin }), CFrame.new(1.45, 3, 0))
	add(ellipsoid(parent, Vector3.new(2.8, 0.3, 2.8), CFrame.identity, Color3.fromRGB(240, 210, 120)), CFrame.new(0, 5.5, 0))
	add(ellipsoid(parent, Vector3.new(1.4, 0.9, 1.4), CFrame.identity, Color3.fromRGB(240, 210, 120)), CFrame.new(0, 5.8, 0))
	add(part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.25, Color = Color3.new(0, 0, 0) }), CFrame.new(-0.35, 5, -0.72))
	add(part(parent, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.25, Color = Color3.new(0, 0, 0) }), CFrame.new(0.35, 5, -0.72))
	local name = part(parent, { Size = Vector3.one * 0.2, Transparency = 1 })
	add(name, CFrame.new(0, 6.5, 0))
	sign(name, "Marina the Merchant", 1.2, Color3.fromRGB(255, 255, 255), 6)
	shopkeeper = { parts = parts, offsets = offsets, base = frame, arm = armIndex }
end

local function buildPlaza()
	local center = spot(WORLD.plaza.angle, WORLD.plaza.radius)
	local model = group("MarketPlaza", center, true)
	local facing = CFrame.lookAt(center, Vector3.new(0, 0, 0))
	-- A round tiled floor with a sandstone rim.
	part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 56, 56), CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(215, 195, 160), Material = Enum.Material.Pavement })
	part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 18, 18), CFrame = CFrame.new(center + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(38, 172, 186), Material = Enum.Material.Pavement })
	-- Four stalls in an arc behind the plaza center, facing spawn.
	local titles = { "Coral Market", "Rare Corals", "Daily Deal", "Decor & Trade" }
	-- Spaced far enough apart that awnings and signs don't overlap.
	for i = 1, 4 do
		local angle = math.rad(-72 + (i - 1) * 48)
		local frame = facing * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, 20)
		frame = CFrame.lookAt(frame.Position, center) -- counters face the plaza center
		stall(model, frame * CFrame.Angles(0, math.pi, 0), AWNINGS[i], titles[i])
		if i == 2 then
			-- Behind the counter (+Z of the stall frame faces the customers), facing them.
			buildShopkeeper(model, frame * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0.5, -3) * CFrame.Angles(0, math.pi, 0))
		end
	end
	-- Lantern posts at the entrance.
	for _, side in { -1, 1 } do
		local base = (facing * CFrame.new(side * 10, 0, -26)).Position
		part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 0.5, 0.5), CFrame = CFrame.new(base + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = DARK_WOOD, Material = Enum.Material.Wood })
		local glow = part(model, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = CFrame.new(base + Vector3.new(0, 7.4, 0)), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon })
		light(glow, Color3.fromRGB(255, 210, 140), 16, 1.6)
	end
end

-- Sunken ruin -------------------------------------------------------------

local function buildRuin()
	local cfg = WORLD.landmarks.ruin
	local center = spot(cfg.angle, cfg.radius)
	local model = group("SunkenRuin", center)
	local stone = Color3.fromRGB(170, 175, 165)
	local mossy = Color3.fromRGB(110, 140, 110)
	local base = CFrame.lookAt(center, Vector3.zero)
	part(model, { Size = Vector3.new(44, 1.5, 30), CFrame = base * CFrame.new(0, 0.75, 0), Color = stone:Lerp(mossy, 0.3), Material = Enum.Material.Cobblestone, CanCollide = true })
	-- Columns, some broken off at different heights, one toppled.
	for i = 0, 5 do
		local x = -17.5 + i * 7
		for _, z in { -11, 11 } do
			local height = if (i + (if z > 0 then 1 else 0)) % 3 == 0 then 6 else 14
			part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 2.4, 2.4), CFrame = base * CFrame.new(x, 1.5 + height / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = stone, Material = Enum.Material.Marble, CanCollide = true })
			part(model, { Size = Vector3.new(3.2, 1, 3.2), CFrame = base * CFrame.new(x, 2, z), Color = stone:Lerp(mossy, 0.4), Material = Enum.Material.Marble })
		end
	end
	part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(13, 2.4, 2.4), CFrame = base * CFrame.new(4, 2.7, 3) * CFrame.Angles(0, 0.6, 0), Color = stone, Material = Enum.Material.Marble, CanCollide = true })
	-- Two arches made of curved block segments.
	for _, x in { -10, 10 } do
		for k = 0, 8 do
			local a = k / 8 * math.pi
			part(model, {
				Size = Vector3.new(2.4, 2.2, 3),
				CFrame = base * CFrame.new(x, 1.5, 0) * CFrame.new(math.cos(a) * 6, math.sin(a) * 9 + 0.5, 0) * CFrame.Angles(0, 0, a - math.pi / 2),
				Color = stone:Lerp(mossy, (k % 3) * 0.15),
				Material = Enum.Material.Marble,
				CanCollide = true,
			})
		end
	end
	-- A cracked statue head lying in the sand, overgrown with kelp-green moss.
	ellipsoid(model, Vector3.new(6, 7, 6), base * CFrame.new(-14, 3, 4) * CFrame.Angles(0.4, 0.8, 0.3), stone, Enum.Material.Marble)
	ellipsoid(model, Vector3.new(6.4, 3, 6.4), base * CFrame.new(-14, 5.5, 4) * CFrame.Angles(0.4, 0.8, 0.3), mossy, Enum.Material.Grass)
end

-- Lighthouse on a rock island that breaks the surface ---------------------

local lighthouseBeam: BasePart? = nil
local lighthousePivot = CFrame.identity

local function buildLighthouse()
	local cfg = WORLD.landmarks.lighthouse
	local center = spot(cfg.angle, cfg.radius)
	local model = group("Lighthouse", center, true)
	local rock = Color3.fromRGB(80, 95, 110)
	-- A tapered rock pillar from the seafloor to just above the water.
	local tiers = 6
	for i = 0, tiers - 1 do
		local w = 34 - i * 4
		part(model, { Size = Vector3.new(w, (SURFACE + 6) / tiers, w * 0.9), CFrame = CFrame.new(center + Vector3.new(i * 0.6, (i + 0.5) * (SURFACE + 6) / tiers, 0)) * CFrame.Angles(0, i * 0.3, 0), Color = rock:Lerp(Color3.fromRGB(110, 130, 140), i / tiers), Material = Enum.Material.Slate, CanCollide = true })
	end
	local top = center + Vector3.new(3, SURFACE + 6, 0)
	-- The tower: white with red bands, a glass lamp room, and a red cap.
	for i = 0, 5 do
		part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 7 - i * 0.4, 7 - i * 0.4), CFrame = CFrame.new(top + Vector3.new(0, 2 + i * 4, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = if i % 2 == 0 then Color3.fromRGB(245, 245, 240) else Color3.fromRGB(200, 60, 60) })
	end
	local lamp = part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 4.4, 4.4), CFrame = CFrame.new(top + Vector3.new(0, 25.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 240, 180), Material = Enum.Material.Neon, Transparency = 0.2 })
	light(lamp, Color3.fromRGB(255, 240, 180), 40, 3)
	ellipsoid(model, Vector3.new(5.6, 3, 5.6), CFrame.new(top + Vector3.new(0, 28, 0)), Color3.fromRGB(200, 60, 60))
	-- A sweeping light beam (a long faint neon wedge) that rotates.
	lighthousePivot = CFrame.new(top + Vector3.new(0, 25.5, 0))
	lighthouseBeam = part(model, { Size = Vector3.new(60, 2.5, 0.2), CFrame = lighthousePivot, Color = Color3.fromRGB(255, 245, 200), Material = Enum.Material.Neon, Transparency = 0.75 })
end

-- Whale skeleton ----------------------------------------------------------

local function buildWhale()
	local cfg = WORLD.landmarks.whale
	local center = spot(cfg.angle, cfg.radius)
	local model = group("WhaleSkeleton", center)
	local bone = Color3.fromRGB(235, 228, 205)
	local base = CFrame.lookAt(center, Vector3.zero) * CFrame.Angles(0, math.rad(70), 0)
	-- Spine: a gently curving row of vertebrae half-buried in the sand.
	local previous: Vector3? = nil
	for i = 0, 16 do
		local z = -24 + i * 3
		local p = (base * CFrame.new(math.sin(i * 0.35) * 2, 1.4 - math.abs(i - 6) * 0.05, z)).Position
		ellipsoid(model, Vector3.new(1.6, 1.4, 1.6), CFrame.new(p), bone)
		if previous then
			cylinderBetween(model, previous, p, 0.45, bone)
		end
		previous = p
		-- Ribs arch up and over along the front half.
		if i >= 3 and i <= 11 then
			local height = 7 - math.abs(i - 7) * 0.8
			for _, side in { -1, 1 } do
				local mid = p + (base.RightVector * side * 5) + Vector3.new(0, height, 0)
				local tip = p + (base.RightVector * side * 7.5) + Vector3.new(0, 0.4, 0)
				cylinderBetween(model, p + Vector3.new(0, 0.6, 0), mid, 0.3, bone)
				cylinderBetween(model, mid, tip, 0.28, bone)
			end
		end
	end
	-- Skull and jaw.
	ellipsoid(model, Vector3.new(7, 3.5, 9), base * CFrame.new(0, 2, -29), bone)
	cylinderBetween(model, (base * CFrame.new(-2.5, 0.6, -26)).Position, (base * CFrame.new(-1.5, 0.6, -35)).Position, 0.5, bone)
	cylinderBetween(model, (base * CFrame.new(2.5, 0.6, -26)).Position, (base * CFrame.new(1.5, 0.6, -35)).Position, 0.5, bone)
end

-- Hydrothermal vents --------------------------------------------------------

local function buildVents()
	local cfg = WORLD.landmarks.vents
	local center = spot(cfg.angle, cfg.radius)
	local model = group("Vents", center)
	local rock = Color3.fromRGB(45, 45, 55)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9)
		local height = 4 + (i % 3) * 3
		local chimney = part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 3.2, 3.2), CFrame = CFrame.new(p + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rock, Material = Enum.Material.Basalt, CanCollide = true })
		local mouth = part(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.2, 2.2), CFrame = CFrame.new(p + Vector3.new(0, height + 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon })
		light(mouth, Color3.fromRGB(255, 130, 60), 12, 1.2)
		bubbles(chimney, 6)
		-- Heat shimmer: soft, wobbling translucent puffs rising from the vent.
		local shimmer = Instance.new("ParticleEmitter")
		shimmer.Texture = "rbxasset://textures/particles/smoke_main.dds"
		shimmer.Color = ColorSequence.new(Color3.fromRGB(255, 200, 160), Color3.fromRGB(180, 200, 210))
		shimmer.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.4, 0.85), NumberSequenceKeypoint.new(1, 1) })
		shimmer.Size = NumberSequence.new(1.5, 4)
		shimmer.Lifetime = NumberRange.new(2, 3.5)
		shimmer.Rate = 10
		shimmer.Speed = NumberRange.new(3, 5)
		shimmer.RotSpeed = NumberRange.new(-40, 40)
		shimmer.SpreadAngle = Vector2.new(15, 15)
		shimmer.EmissionDirection = Enum.NormalId.Right -- up along the cylinder's axis
		shimmer.Parent = mouth
		ellipsoid(model, Vector3.new(6, 2, 6), CFrame.new(p + Vector3.new(0, 0.5, 0)), Color3.fromRGB(70, 60, 55), Enum.Material.Basalt)
	end
end

-- Giant clam that opens and closes ------------------------------------------

type Clam = { lid: { BasePart }, offsets: { CFrame }, hinge: CFrame }
local clam: Clam? = nil

local function buildClam()
	local cfg = WORLD.landmarks.clam
	local center = spot(cfg.angle, cfg.radius)
	local model = group("GiantClam", center)
	local shell = Color3.fromRGB(150, 120, 200)
	local base = CFrame.lookAt(center, Vector3.zero)
	ellipsoid(model, Vector3.new(14, 4, 11), base * CFrame.new(0, 1.2, 0), shell)
	ellipsoid(model, Vector3.new(12, 1.5, 9), base * CFrame.new(0, 2.6, 0), Color3.fromRGB(230, 120, 160))
	local pearl = part(model, { Shape = Enum.PartType.Ball, Size = Vector3.one * 3, CFrame = base * CFrame.new(0, 4, -0.5), Color = Color3.fromRGB(255, 250, 245), Material = Enum.Material.Neon })
	light(pearl, Color3.fromRGB(255, 235, 250), 16, 2)
	-- The lid hinges along the back edge.
	local hinge = base * CFrame.new(0, 2.8, 5)
	local lidParts, offsets = {}, {}
	for _, p in {
		ellipsoid(model, Vector3.new(14, 4, 11), CFrame.identity, shell:Lerp(Color3.fromRGB(255, 255, 255), 0.1)),
		ellipsoid(model, Vector3.new(12.5, 1.2, 9.5), CFrame.identity, Color3.fromRGB(230, 120, 160)),
	} do
		table.insert(lidParts, p)
	end
	table.insert(offsets, CFrame.new(0, 1.2, -5))
	table.insert(offsets, CFrame.new(0, -0.6, -5))
	clam = { lid = lidParts, offsets = offsets, hinge = hinge }
end

-- Boats on the surface and a whale overhead ---------------------------------

type Mover = { parts: { BasePart }, offsets: { CFrame }, radius: number, height: number, speed: number, phase: number }
local movers: { Mover } = {}

local function makeMover(parts: { BasePart }, radius: number, height: number, speed: number, phase: number)
	local offsets = {}
	for _, p in parts do
		table.insert(offsets, p.CFrame)
	end
	table.insert(movers, { parts = parts, offsets = offsets, radius = radius, height = height, speed = speed, phase = phase })
end

local function buildSkyTraffic()
	local model = group("SurfaceTraffic", Vector3.zero, true)
	for i = 1, 3 do
		-- Boat hulls seen from below: a long dark hull with a keel.
		local hull = ellipsoid(model, Vector3.new(6, 2.4, 18), CFrame.identity, Color3.fromRGB(70, 50, 40))
		local keel = part(model, { Size = Vector3.new(0.6, 1.4, 12), Color = Color3.fromRGB(50, 35, 28) })
		hull.CFrame = CFrame.identity
		keel.CFrame = CFrame.new(0, -1.3, 0)
		makeMover({ hull, keel }, 160 + i * 90, SURFACE + 0.4, 0.012 + i * 0.004, i * 2.1)
	end
	-- A whale silhouette gliding far overhead.
	local dark = Color3.fromRGB(30, 45, 60)
	local body = ellipsoid(model, Vector3.new(14, 11, 52), CFrame.identity, dark)
	local tail = ellipsoid(model, Vector3.new(20, 1.5, 7), CFrame.identity, dark)
	local finL = ellipsoid(model, Vector3.new(14, 1, 4), CFrame.identity, dark)
	local finR = ellipsoid(model, Vector3.new(14, 1, 4), CFrame.identity, dark)
	for _, p in { body, tail, finL, finR } do
		p.Transparency = 0.25
	end
	tail.CFrame = CFrame.new(0, 0, 28)
	finL.CFrame = CFrame.new(-9, -2, -6) * CFrame.Angles(0, 0, 0.3)
	finR.CFrame = CFrame.new(9, -2, -6) * CFrame.Angles(0, 0, -0.3)
	makeMover({ body, tail, finL, finR }, 420, SURFACE - 22, 0.006, 0)
end

-- Animation and level-of-detail ------------------------------------------------

function Landmarks.start(onOpenMarket: () -> ())
	openMarket = onOpenMarket
	buildPlaza()
	buildRuin()
	buildLighthouse()
	buildWhale()
	buildVents()
	buildClam()
	buildSkyTraffic()
	root.Parent = workspace

	local camera = workspace.CurrentCamera
	-- Hide landmarks that are far from the camera; checked once a second.
	task.spawn(function()
		while true do
			local position = camera.CFrame.Position
			for _, g in groups do
				if not g.alwaysShown then
					local near = (Vector3.new(position.X, 0, position.Z) - g.center).Magnitude < HIDE_DISTANCE
					g.model.Parent = if near then root else nil
				end
			end
			task.wait(LOD_CHECK_SECONDS)
		end
	end)

	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		table.clear(parts)
		table.clear(frames)
		-- Boats and the whale circle the reef.
		for _, mover in movers do
			local angle = mover.phase + t * mover.speed
			local position = Vector3.new(math.cos(angle) * mover.radius, mover.height + math.sin(t * 0.5 + mover.phase) * 0.4, math.sin(angle) * mover.radius)
			local heading = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			local frame = CFrame.lookAt(position, position - heading)
			for i, p in mover.parts do
				parts[#parts + 1] = p
				frames[#frames + 1] = frame * mover.offsets[i]
			end
		end
		-- The clam opens slowly, holds, and closes (an 8-second loop).
		if clam and clam.lid[1]:IsDescendantOf(workspace) then
			local cycle = (t % 8) / 8
			local open = math.clamp(math.sin(cycle * math.pi * 2) * 1.6, 0, 1)
			local hinge = clam.hinge * CFrame.Angles(open * 0.9, 0, 0)
			for i, p in clam.lid do
				parts[#parts + 1] = p
				frames[#frames + 1] = hinge * clam.offsets[i]
			end
		end
		-- The shopkeeper bobs and waves now and then.
		if shopkeeper then
			local bob = CFrame.new(0, math.sin(t * 2) * 0.08, 0)
			for i, p in shopkeeper.parts do
				local offset = shopkeeper.offsets[i]
				if i == shopkeeper.arm then
					local wave = math.max(0, math.sin(t * 0.8)) * (1.6 + math.sin(t * 8) * 0.35)
					offset = CFrame.new(1.45, 3.9, 0) * CFrame.Angles(0, 0, wave) * CFrame.new(0, -0.9, 0)
				end
				parts[#parts + 1] = p
				frames[#frames + 1] = shopkeeper.base * bob * offset
			end
		end
		if lighthouseBeam then
			local beam = lighthouseBeam :: BasePart
			parts[#parts + 1] = beam
			frames[#frames + 1] = lighthousePivot * CFrame.Angles(0, t * 0.6, 0) * CFrame.new(30, 0, 0)
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

-- Spots other systems should keep clear of: { center, radius }.
function Landmarks.footprints(): { { center: Vector3, radius: number } }
	local list = { { center = spot(WORLD.plaza.angle, WORLD.plaza.radius), radius = WORLD.plaza.size } }
	for _, cfg in WORLD.landmarks do
		table.insert(list, { center = spot(cfg.angle, cfg.radius), radius = cfg.size })
	end
	return list
end

return Landmarks
