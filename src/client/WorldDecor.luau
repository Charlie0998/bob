-- Builds the decorative seafloor locally on each client: a coral garden at
-- spawn, rocks, swaying kelp, sunbeams, bubble vents, drifting plankton, and
-- the water surface. None of it is replicated, so it costs the server nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CoralModels = require(ReplicatedStorage.Shared.CoralModels)

local SEED = 2026
local SURFACE_HEIGHT = 95
local KELP_ANIMATE_DISTANCE = 180
local KELP_FPS = 20

-- Must match the plot layout in ReefService.luau.
local PLOT_RING = 8
local PLOT_RADII = { 70, 130 }
local PLOT_CLEARANCE = 36

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

local function isClear(position: Vector3, margin: number): boolean
	if Vector3.new(position.X, 0, position.Z).Magnitude < 10 + margin then
		return false -- keep the spawn point open
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
			Transparency = 0.94,
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
	newPart({
		Name = "WaterSurface",
		Size = Vector3.new(2048, 1, 2048),
		CFrame = CFrame.new(0, SURFACE_HEIGHT, 0),
		Color = Color3.fromRGB(130, 210, 235),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		CastShadow = false,
	})
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
			beam.part.Transparency = 0.93 + math.sin(t * 0.4 + beam.phase) * 0.03
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
