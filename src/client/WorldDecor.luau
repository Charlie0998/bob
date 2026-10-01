-- Builds the decorative seafloor locally on each client: a coral garden at
-- spawn, rocks, swaying kelp, sunbeams, bubble vents, drifting plankton, and
-- the water surface. None of it is replicated, so it costs the server nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CoralModels = require(ReplicatedStorage.Shared.CoralModels)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)

local SEED = 2026
local SURFACE_HEIGHT = 95
local KELP_ANIMATE_DISTANCE = 180

-- Underwater mountains: a far ring of stepped peaks and some closer low hills.
local MOUNTAIN_COUNT = 22
local MOUNTAIN_MIN_RADIUS = 610
local MOUNTAIN_MAX_RADIUS = 770
local HILL_COUNT = 12
local HILL_MIN_RADIUS = 290
local HILL_MAX_RADIUS = 400
local PEAK_CLEARANCE = 10 -- keep every peak this far below the water surface
local ZONE_CLEARANCE = 110 -- radius around each deep zone's center to keep clear
local PLACEMENT_TRIES = 25
local KELP_FPS = 20

-- Must match the plot layout in ReefService.luau.
local PLOT_RING = 8
local PLOT_RADII = { 100, 180 }
local PLOT_CLEARANCE = 40

local WorldDecor = {}

local folder = Instance.new("Folder")
folder.Name = "Decor"

local function newPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = folder
	return part
end

local plotCenters: { Vector3 } = {}
for _, radius in PLOT_RADII do
	for i = 0, PLOT_RING - 1 do
		local angle = i / PLOT_RING * math.pi * 2
		table.insert(plotCenters, Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
	end
end

-- The Market plaza and landmarks (Balance.json > world), kept clear of decor.
local landmarkSpots: { { center: Vector3, radius: number } } = {}
do
	local function add(cfg: any)
		local a = math.rad(cfg.angle)
		table.insert(landmarkSpots, { center = Vector3.new(math.cos(a) * cfg.radius, 0, math.sin(a) * cfg.radius), radius = cfg.size })
	end
	add(Balance.world.plaza)
	for _, cfg in Balance.world.landmarks do
		add(cfg)
	end
end

local function isClear(position: Vector3, margin: number): boolean
	if Vector3.new(position.X, 0, position.Z).Magnitude < 10 + margin then
		return false -- keep the spawn point open
	end
	for _, spot in landmarkSpots do
		if (Vector3.new(position.X, 0, position.Z) - spot.center).Magnitude < spot.radius + margin + 4 then
			return false
		end
	end
	for _, center in plotCenters do
		if (Vector3.new(position.X, 0, position.Z) - center).Magnitude < PLOT_CLEARANCE + margin then
			return false
		end
	end
	return true
end

local function randomClearSpot(rng: Random, minRadius: number, maxRadius: number, margin: number): Vector3?
	for _ = 1, 30 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(minRadius, maxRadius)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if isClear(position, margin) then
			return position
		end
	end
	return nil
end

local function buildGarden(rng: Random)
	local types = {}
	for name in Balance.corals do
		table.insert(types, name)
	end
	table.sort(types)
	for i = 1, 16 do
		local angle = i / 16 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local radius = rng:NextNumber(13, 24)
		local coralType = types[rng:NextInteger(1, #types)]
		local model = CoralModels.build(coralType, Balance.corals[coralType].color, SEED + i)
		model:PivotTo(CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		model:ScaleTo(rng:NextNumber(0.9, 1.5))
		model.Parent = folder
	end
end

local function buildRocks(rng: Random)
	for _ = 1, 80 do
		local spot = randomClearSpot(rng, 20, 280, 2)
		if not spot then
			continue
		end
		local size = rng:NextNumber(2, 7)
		newPart({
			Name = "Rock",
			Size = Vector3.new(size * rng:NextNumber(1, 1.8), size * rng:NextNumber(0.5, 0.9), size),
			CFrame = CFrame.new(spot) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
			Color = Color3.fromRGB(95, 110, 125):Lerp(Color3.fromRGB(150, 140, 120), rng:NextNumber()),
			Material = Enum.Material.Slate,
			CanCollide = true,
		})
	end
end

type Kelp = { parts: { BasePart }, base: CFrame, segment: number, phase: number, sway: number }
local kelps: { Kelp } = {}

local function buildKelp(rng: Random)
	local greens = { Color3.fromRGB(70, 140, 70), Color3.fromRGB(95, 160, 80), Color3.fromRGB(120, 150, 60) }
	for _ = 1, 16 do
		local center = randomClearSpot(rng, 30, 260, 6)
		if not center then
			continue
		end
		for _ = 1, rng:NextInteger(4, 7) do
			local offset = Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
			local segment = rng:NextNumber(1.6, 2.2)
			local kelp: Kelp = {
				parts = {},
				base = CFrame.new(center + offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				segment = segment,
				phase = rng:NextNumber(0, math.pi * 2),
				sway = rng:NextNumber(0.06, 0.12),
			}
			local color = greens[rng:NextInteger(1, #greens)]
			for s = 1, rng:NextInteger(6, 11) do
				table.insert(
					kelp.parts,
					newPart({
						Name = "Kelp",
						Size = Vector3.new(0.15, segment, 0.9 - s * 0.03),
						Color = color:Lerp(Color3.fromRGB(170, 200, 90), s * 0.04),
						CastShadow = false,
					})
				)
			end
			table.insert(kelps, kelp)
		end
	end
end

-- Each segment bends a little more than the one below it, so stalks wave.
local function kelpFrames(kelp: Kelp, t: number, out: { CFrame })
	local cf = kelp.base
	for i = 1, #kelp.parts do
		local bend = math.sin(t * 1.3 + kelp.phase + i * 0.45) * kelp.sway
		cf = cf * CFrame.Angles(bend, 0, bend * 0.5)
		out[#out + 1] = cf * CFrame.new(0, kelp.segment / 2, 0)
		cf = cf * CFrame.new(0, kelp.segment, 0)
	end
end

type Beam = { part: BasePart, phase: number }
local beams: { Beam } = {}
local isNight = false
local surfacePart: BasePart? = nil

local function buildSunbeams(rng: Random)
	for _ = 1, 18 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(10, 220)
		local height = SURFACE_HEIGHT * 1.1
		local part = newPart({
			Name = "Sunbeam",
			Size = Vector3.new(rng:NextNumber(6, 14), height, 0.2),
			CFrame = CFrame.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				* CFrame.Angles(0, 0, math.rad(18)),
			Color = Color3.fromRGB(200, 245, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.96,
			CastShadow = false,
		})
		table.insert(beams, { part = part, phase = rng:NextNumber(0, math.pi * 2) })
	end
end

local function bubbleEmitter(parent: BasePart, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Size = NumberSequence.new(0.25, 0.6)
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(4, 7)
	emitter.SpreadAngle = Vector2.new(8, 8)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.3
	emitter.Parent = parent
end

local function buildBubbleVents(rng: Random)
	for _ = 1, 10 do
		local spot = randomClearSpot(rng, 20, 200, 3)
		if not spot then
			continue
		end
		local vent = newPart({
			Name = "BubbleVent",
			Size = Vector3.new(3, 1.6, 3),
			CFrame = CFrame.new(spot + Vector3.new(0, 0.5, 0)),
			Color = Color3.fromRGB(80, 90, 100),
			Material = Enum.Material.Basalt,
		})
		bubbleEmitter(vent, rng:NextNumber(2, 5))
	end
end

-- A box of tiny specks that follows the camera, so the water always feels full.
local plankton: BasePart

local function buildPlankton()
	plankton = newPart({
		Name = "Plankton",
		Size = Vector3.new(70, 30, 70),
		Transparency = 1,
		CastShadow = false,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(210, 245, 240))
	emitter.LightEmission = 0.6
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Size = NumberSequence.new(0.12)
	emitter.Lifetime = NumberRange.new(5, 8)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = plankton
end

local function buildSurface()
	surfacePart = newPart({
		Name = "WaterSurface",
		Size = Vector3.new(2048, 1, 2048),
		CFrame = CFrame.new(0, SURFACE_HEIGHT, 0),
		Color = Color3.fromRGB(130, 210, 235),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		CastShadow = false,
	})
end

-- One kelp stalk; it joins the shared sway animation.
local function addKelp(rng: Random, position: Vector3, segments: number, color: Color3)
	local segment = rng:NextNumber(1.6, 2.2)
	local kelp: Kelp = {
		parts = {},
		base = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		segment = segment,
		phase = rng:NextNumber(0, math.pi * 2),
		sway = rng:NextNumber(0.05, 0.1),
	}
	for s = 1, segments do
		table.insert(
			kelp.parts,
			newPart({
				Name = "Kelp",
				Size = Vector3.new(0.15, segment, math.max(0.4, 1.1 - s * 0.03)),
				Color = color:Lerp(Color3.fromRGB(170, 200, 90), s / segments * 0.5),
				CastShadow = false,
			})
		)
	end
	table.insert(kelps, kelp)
end

local function zoneCenter(zoneId: string): Vector3
	local c = Balance.zones[zoneId].center
	return Vector3.new(c[1], 0, c[2])
end

-- A random spot in a zone, keeping the market stall area open.
local function zoneSpot(rng: Random, center: Vector3, radius: number): Vector3
	for _ = 1, 20 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, radius)
		local spot = center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		if (spot - center).Magnitude > 22 then
			return spot
		end
	end
	return center + Vector3.new(radius, 0, 0)
end

local function rock(rng: Random, position: Vector3, size: number, color: Color3, material: Enum.Material)
	newPart({
		Name = "Rock",
		Size = Vector3.new(size * rng:NextNumber(1, 1.7), size * rng:NextNumber(0.5, 1), size),
		CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
		Color = color,
		Material = material,
		CanCollide = true,
	})
end

local function buildKelpForest(rng: Random)
	local center = zoneCenter("KelpForest")
	local greens = { Color3.fromRGB(60, 130, 60), Color3.fromRGB(90, 150, 70), Color3.fromRGB(120, 140, 50) }
	for _ = 1, 90 do
		addKelp(rng, zoneSpot(rng, center, 85), rng:NextInteger(12, 20), greens[rng:NextInteger(1, #greens)])
	end
	for _ = 1, 20 do
		rock(rng, zoneSpot(rng, center, 85), rng:NextNumber(2, 6), Color3.fromRGB(90, 110, 90), Enum.Material.Slate)
	end
	for i = 1, 8 do
		local model = CoralModels.build(if i % 2 == 0 then "SeaGrape" else "KelpBloom", Balance.corals[if i % 2 == 0 then "SeaGrape" else "KelpBloom"].color, SEED + 100 + i)
		model:PivotTo(CFrame.new(zoneSpot(rng, center, 60)))
		model:ScaleTo(rng:NextNumber(1, 1.6))
		model.Parent = folder
	end
end

local function buildShipwreck(rng: Random)
	local center = zoneCenter("Shipwreck")
	local wood = Color3.fromRGB(105, 75, 50)
	local dark = Color3.fromRGB(70, 50, 35)
	-- The ship lies on its side behind the market, half sunk in the sand.
	local ship = CFrame.lookAt(center, Vector3.zero) * CFrame.new(0, 0, 45) * CFrame.Angles(0, math.rad(70), math.rad(18))
	local function plank(size: Vector3, offset: CFrame, color: Color3?)
		newPart({ Name = "Wreck", Size = size, CFrame = ship * offset, Color = color or wood, Material = Enum.Material.WoodPlanks, CanCollide = true })
	end
	plank(Vector3.new(44, 3, 14), CFrame.new(0, 1, 0)) -- hull bottom
	plank(Vector3.new(44, 8, 1.5), CFrame.new(0, 5, 7)) -- side
	plank(Vector3.new(44, 8, 1.5), CFrame.new(0, 4, -7) * CFrame.Angles(0.3, 0, 0), dark)
	plank(Vector3.new(14, 9, 1.5), CFrame.new(-22, 5, 0) * CFrame.Angles(0, math.pi / 2, 0)) -- stern
	plank(Vector3.new(10, 6, 12), CFrame.new(-16, 9, 0), dark) -- cabin
	plank(Vector3.new(30, 0.8, 13), CFrame.new(4, 8.5, 0)) -- deck
	-- Broken mast and a tattered sail.
	newPart({ Name = "Mast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(26, 1.2, 1.2), CFrame = ship * CFrame.new(6, 18, 2) * CFrame.Angles(0, 0, math.rad(70)), Color = dark, Material = Enum.Material.Wood })
	newPart({ Name = "Sail", Size = Vector3.new(0.2, 9, 11), CFrame = ship * CFrame.new(9, 20, 6) * CFrame.Angles(0.3, 0, 0.2), Color = Color3.fromRGB(220, 210, 180), Material = Enum.Material.Fabric, Transparency = 0.15 })
	-- Scattered barrels, crates, cannons, and treasure.
	for _ = 1, 14 do
		local spot = zoneSpot(rng, center, 55)
		local roll = rng:NextNumber()
		if roll < 0.4 then
			newPart({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2, 2), CFrame = CFrame.new(spot + Vector3.new(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), math.pi / 2 * (if rng:NextNumber() < 0.5 then 1 else 0)), Color = Color3.fromRGB(130, 90, 55), Material = Enum.Material.Wood, CanCollide = true })
		elseif roll < 0.75 then
			newPart({ Name = "Crate", Size = Vector3.one * 2.2, CFrame = CFrame.new(spot + Vector3.new(0, 1, 0)) * CFrame.Angles(0.1, rng:NextNumber(0, 6), 0.1), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks, CanCollide = true })
		elseif roll < 0.9 then
			newPart({ Name = "Cannon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.2, 1.2), CFrame = CFrame.new(spot + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Metal })
		else
			local chest = DecorModels.build("TreasureChest")
			chest:PivotTo(CFrame.new(spot) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
			chest.Parent = folder
		end
	end
	for _ = 1, 10 do
		rock(rng, zoneSpot(rng, center, 80), rng:NextNumber(2, 5), Color3.fromRGB(110, 110, 100), Enum.Material.Slate)
	end
	for i = 1, 6 do
		local kind = if i % 2 == 0 then "AnchorSponge" else "TreasureCoral"
		local model = CoralModels.build(kind, Balance.corals[kind].color, SEED + 200 + i)
		model:PivotTo(CFrame.new(zoneSpot(rng, center, 50)))
		model.Parent = folder
	end
end

local function buildDeepSea(rng: Random)
	local center = zoneCenter("DeepSea")
	for _ = 1, 30 do
		rock(rng, zoneSpot(rng, center, 85), rng:NextNumber(3, 9), Color3.fromRGB(40, 45, 60), Enum.Material.Basalt)
	end
	-- Glowing mushrooms in blues, teals, and purples.
	local glows = { Color3.fromRGB(90, 240, 220), Color3.fromRGB(120, 140, 255), Color3.fromRGB(200, 110, 255) }
	for i = 1, 26 do
		local spot = zoneSpot(rng, center, 75)
		local height = rng:NextNumber(1.5, 4)
		local color = glows[rng:NextInteger(1, #glows)]
		newPart({ Name = "Stalk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 0.5, 0.5), CFrame = CFrame.new(spot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(200, 200, 210) })
		local cap = newPart({ Name = "Cap", Size = Vector3.new(2.4, 0.9, 2.4), CFrame = CFrame.new(spot + Vector3.new(0, height, 0)), Color = color, Material = Enum.Material.Neon })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = cap
		if i % 3 == 0 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 14
			light.Brightness = 1.5
			light.Parent = cap
		end
	end
	for i = 1, 6 do
		local kind = if i % 2 == 0 then "LanternAnemone" else "BlackCoral"
		local model = CoralModels.build(kind, Balance.corals[kind].color, SEED + 300 + i)
		model:PivotTo(CFrame.new(zoneSpot(rng, center, 55)))
		model:ScaleTo(rng:NextNumber(1, 1.5))
		model.Parent = folder
	end
	for _ = 1, 4 do
		local vent = newPart({ Name = "Vent", Size = Vector3.new(3, 1.6, 3), CFrame = CFrame.new(zoneSpot(rng, center, 70) + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Basalt })
		bubbleEmitter(vent, 4)
	end
end

local MOUNTAIN_COLORS = {
	Color3.fromRGB(62, 86, 116), -- slate blue
	Color3.fromRGB(56, 104, 116), -- deep teal
	Color3.fromRGB(78, 104, 130), -- lighter slate
}

-- True if a footprint of `radius` at `position` stays clear of the player
-- plots, the spawn area, and every deep zone.
local function clearOfPlotsAndZones(position: Vector3, radius: number): boolean
	if not isClear(position, radius) then
		return false
	end
	for zoneId in Balance.zones do
		local flat = Vector3.new(position.X, 0, position.Z)
		if (flat - zoneCenter(zoneId)).Magnitude < ZONE_CLEARANCE + radius + 20 then
			return false
		end
	end
	return true
end

-- A spot on a ring between two radii that passes clearOfPlotsAndZones,
-- preferring `angle` and searching wider around it each time it's blocked.
local function ringSpot(rng: Random, angle: number, minRadius: number, maxRadius: number, footprint: number): Vector3?
	for attempt = 0, PLACEMENT_TRIES do
		local spread = 0.25 * (1 + attempt / 5)
		local a = angle + (if attempt == 0 then 0 else rng:NextNumber(-spread, spread))
		local r = rng:NextNumber(minRadius, maxRadius)
		local spot = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if clearOfPlotsAndZones(spot, footprint) then
			return spot
		end
	end
	return nil
end

-- A stepped mountain: stacked slabs that shrink toward a peak below the surface.
local function buildMountain(rng: Random, base: Vector3)
	local tiers = rng:NextInteger(4, 6)
	local maxHeight = SURFACE_HEIGHT - PEAK_CLEARANCE
	local height = rng:NextNumber(maxHeight * 0.55, maxHeight)
	local width = rng:NextNumber(70, 110)
	local depth = width * rng:NextNumber(0.75, 1)
	local tierHeight = height / tiers
	local y = 0
	local center = base
	local color = MOUNTAIN_COLORS[rng:NextInteger(1, #MOUNTAIN_COLORS)]
	for tier = 1, tiers do
		local w = width * (1 - (tier - 1) / tiers * 0.82)
		local d = depth * (1 - (tier - 1) / tiers * 0.82)
		newPart({
			Name = "Mountain",
			Size = Vector3.new(w, tierHeight, d),
			CFrame = CFrame.new(center.X, y + tierHeight / 2, center.Z) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0),
			-- Lighter toward the peak, like light falling from above.
			Color = color:Lerp(Color3.fromRGB(110, 150, 165), (tier - 1) / tiers * 0.5),
			Material = Enum.Material.Slate,
			CanCollide = true,
		})
		y += tierHeight
		center += Vector3.new(rng:NextNumber(-w, w) * 0.06, 0, rng:NextNumber(-d, d) * 0.06)
	end
	-- A few kelp stalks around the base.
	for _ = 1, rng:NextInteger(2, 4) do
		local a = rng:NextNumber(0, math.pi * 2)
		local spot = base + Vector3.new(math.cos(a) * (width / 2 + 3), 0, math.sin(a) * (depth / 2 + 3))
		addKelp(rng, spot, rng:NextInteger(6, 10), Color3.fromRGB(70, 140, 80))
	end
	return width / 2
end

-- A low terraced hill: 2-3 stacked discs, round so collisions match the look.
local function buildHill(rng: Random, base: Vector3)
	local tiers = rng:NextInteger(2, 3)
	local diameter = rng:NextNumber(50, 90)
	local tierHeight = rng:NextNumber(4, 7)
	local color = MOUNTAIN_COLORS[rng:NextInteger(1, #MOUNTAIN_COLORS)]:Lerp(Color3.fromRGB(120, 150, 140), 0.25)
	for tier = 1, tiers do
		local d = diameter * (1 - (tier - 1) * 0.3)
		newPart({
			Name = "Hill",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(tierHeight, d, d),
			CFrame = CFrame.new(base.X, (tier - 0.5) * tierHeight, base.Z) * CFrame.Angles(0, 0, math.pi / 2),
			Color = color:Lerp(Color3.fromRGB(140, 170, 165), (tier - 1) * 0.15),
			Material = Enum.Material.Slate,
			CanCollide = true,
		})
	end
	addKelp(rng, base + Vector3.new(diameter / 2 + 2, 0, 0), rng:NextInteger(5, 8), Color3.fromRGB(80, 150, 85))
end

local function buildMountains(rng: Random)
	for i = 1, MOUNTAIN_COUNT do
		local angle = i / MOUNTAIN_COUNT * math.pi * 2 + rng:NextNumber(-0.08, 0.08)
		local spot = ringSpot(rng, angle, MOUNTAIN_MIN_RADIUS, MOUNTAIN_MAX_RADIUS, 55)
		if spot then
			buildMountain(rng, spot)
		end
	end
	for i = 1, HILL_COUNT do
		local angle = i / HILL_COUNT * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local spot = ringSpot(rng, angle, HILL_MIN_RADIUS, HILL_MAX_RADIUS, 45)
		if spot then
			buildHill(rng, spot)
		end
	end
end

-- Each zone tints the water while you're in it; the Deep Sea is dark.
local function runZoneMood()
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "ZoneTint"
	tint.Parent = game:GetService("Lighting")
	local TweenService = game:GetService("TweenService")
	local current = ""
	while true do
		task.wait(0.5)
		local character = game:GetService("Players").LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inside = ""
		if root then
			for zoneId in Balance.zones do
				if (Vector3.new(root.Position.X, 0, root.Position.Z) - zoneCenter(zoneId)).Magnitude < 110 then
					inside = zoneId
				end
			end
		end
		if inside ~= current then
			current = inside
			local zone = Balance.zones[inside]
			local goal = if zone
				then { TintColor = Color3.fromRGB(zone.tint[1], zone.tint[2], zone.tint[3]), Brightness = if inside == "DeepSea" then -0.12 else 0 }
				else { TintColor = Color3.new(1, 1, 1), Brightness = 0 }
			TweenService:Create(tint, TweenInfo.new(1.5), goal):Play()
		end
	end
end

-- Night: kelp tips glow softly (bioluminescence), sunbeams fade, and the
-- surface overhead goes dark.
function WorldDecor.setNight(night: boolean)
	isNight = night
	for _, kelp in kelps do
		local tip = kelp.parts[#kelp.parts]
		if tip then
			tip.Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
			if night then
				tip:SetAttribute("DayColor", tip:GetAttribute("DayColor") or tip.Color)
				tip.Color = Color3.fromRGB(110, 255, 210)
			elseif tip:GetAttribute("DayColor") then
				tip.Color = tip:GetAttribute("DayColor")
			end
		end
	end
	if surfacePart then
		surfacePart.Color = if night then Color3.fromRGB(20, 40, 70) else Color3.fromRGB(130, 210, 235)
	end
end

function WorldDecor.start()
	local rng = Random.new(SEED)
	buildGarden(rng)
	buildRocks(rng)
	buildKelp(rng)
	buildSunbeams(rng)
	buildBubbleVents(rng)
	buildPlankton()
	buildSurface()
	buildKelpForest(rng)
	buildShipwreck(rng)
	buildDeepSea(rng)
	buildMountains(rng)
	task.spawn(runZoneMood)
	folder.Parent = workspace

	local camera = workspace.CurrentCamera
	local accumulator = 0
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}

	RunService.Heartbeat:Connect(function(dt)
		local cameraPosition = camera.CFrame.Position
		plankton.CFrame = CFrame.new(cameraPosition)

		accumulator += dt
		if accumulator < 1 / KELP_FPS then
			return
		end
		accumulator = 0
		local t = os.clock()

		-- Move every nearby kelp segment in one bulk call.
		table.clear(parts)
		table.clear(frames)
		for _, kelp in kelps do
			if (kelp.base.Position - cameraPosition).Magnitude < KELP_ANIMATE_DISTANCE then
				for _, part in kelp.parts do
					parts[#parts + 1] = part
				end
				kelpFrames(kelp, t, frames)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- Sunbeams slowly brighten and fade.
		for _, beam in beams do
			beam.part.Transparency = if isNight then 1 else 0.955 + math.sin(t * 0.4 + beam.phase) * 0.02
		end
	end)

	-- Place kelp once right away, so stalks far from the camera are not left at the origin.
	local allParts, allFrames = {}, {}
	for _, kelp in kelps do
		for _, part in kelp.parts do
			allParts[#allParts + 1] = part
		end
		kelpFrames(kelp, 0, allFrames)
	end
	workspace:BulkMoveTo(allParts, allFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

return WorldDecor
