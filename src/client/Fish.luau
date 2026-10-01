-- Client-side schools of fish. A few circle the spawn garden, and each reef
-- gets more fish as its owner plants more coral, so a growing reef visibly
-- comes alive. All fish move in one BulkMoveTo call per frame.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MAX_FISH_PER_REEF = 10
local CORALS_PER_FISH = 2
local SPAWN_FISH = 8
local ANIMATE_DISTANCE = 220
local REBALANCE_SECONDS = 3
local SCATTER_RADIUS = 9

local PALETTES = {
	{ body = Color3.fromRGB(255, 140, 40), stripe = Color3.fromRGB(255, 255, 255) }, -- clownfish
	{ body = Color3.fromRGB(60, 120, 255), stripe = Color3.fromRGB(255, 220, 60) }, -- blue tang
	{ body = Color3.fromRGB(255, 220, 60), stripe = Color3.fromRGB(40, 40, 40) }, -- butterflyfish
	{ body = Color3.fromRGB(240, 90, 160), stripe = Color3.fromRGB(255, 200, 230) }, -- pink wrasse
	{ body = Color3.fromRGB(80, 210, 190), stripe = Color3.fromRGB(20, 90, 120) }, -- teal chromis
}

type Fish = {
	parts: { BasePart },
	offsets: { CFrame }, -- body-relative frames; the tail (index 2) is posed separately
	scale: number,
	center: () -> Vector3?,
	radius: number,
	height: number,
	speed: number,
	phase: number,
	direction: number,
	scatter: Vector3, -- pushed away when a player swims close; decays back to 0
}

local Fish = {}

local folder = Instance.new("Folder")
folder.Name = "Fish"

local fishes: { Fish } = {}
local reefFish: { [Model]: { Fish } } = {}

local function newPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = folder
	return part
end

local function ellipsoid(size: Vector3, color: Color3): Part
	local part = newPart({ Size = size, Color = color })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Fish face -Z. Parts: body, tail, stripe, fin, two eyes.
local function makeFish(rng: Random, center: () -> Vector3?, radius: number): Fish
	local palette = PALETTES[rng:NextInteger(1, #PALETTES)]
	local scale = rng:NextNumber(0.7, 1.2)
	local parts = {
		ellipsoid(Vector3.new(0.5, 0.9, 1.6) * scale, palette.body),
		ellipsoid(Vector3.new(0.1, 0.8, 0.6) * scale, palette.body),
		ellipsoid(Vector3.new(0.52, 0.85, 0.22) * scale, palette.stripe),
		ellipsoid(Vector3.new(0.08, 0.45, 0.7) * scale, palette.stripe),
		newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.18 * scale, Color = Color3.new(0, 0, 0) }),
		newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.18 * scale, Color = Color3.new(0, 0, 0) }),
	}
	return {
		parts = parts,
		scale = scale,
		offsets = {
			CFrame.identity,
			CFrame.identity,
			CFrame.new(0, 0, -0.15 * scale),
			CFrame.new(0, 0.45 * scale, 0.1 * scale),
			CFrame.new(0.2 * scale, 0.12 * scale, -0.55 * scale),
			CFrame.new(-0.2 * scale, 0.12 * scale, -0.55 * scale),
		},
		center = center,
		radius = radius,
		height = rng:NextNumber(3, 9),
		speed = rng:NextNumber(3, 6),
		phase = rng:NextNumber(0, math.pi * 2),
		direction = if rng:NextNumber() < 0.5 then 1 else -1,
		scatter = Vector3.zero,
	}
end

local function destroyFish(fish: Fish)
	for _, part in fish.parts do
		part:Destroy()
	end
	local index = table.find(fishes, fish)
	if index then
		table.remove(fishes, index)
	end
end

local function coralCount(reef: Model): number
	local count = 0
	for _, child in reef:GetChildren() do
		local coralType = child:GetAttribute("CoralType")
		if coralType and coralType ~= "" then
			count += 1
		end
	end
	return count
end

local rng = Random.new()

-- Adds or removes fish so each reef has as many as its coral count earns.
local function rebalance(reefs: Instance)
	for reef, list in reefFish do
		if reef.Parent ~= reefs then
			for _, fish in list do
				destroyFish(fish)
			end
			reefFish[reef] = nil
		end
	end
	for _, reef in reefs:GetChildren() do
		if not reef:IsA("Model") then
			continue
		end
		local list = reefFish[reef] or {}
		reefFish[reef] = list
		local wanted = math.min(MAX_FISH_PER_REEF, coralCount(reef) // CORALS_PER_FISH)
		while #list < wanted do
			local model = reef
			local fish = makeFish(rng, function()
				local base = model.PrimaryPart
				return base and base.Position
			end, rng:NextNumber(8, 22))
			table.insert(list, fish)
			table.insert(fishes, fish)
		end
		while #list > wanted do
			destroyFish(table.remove(list) :: Fish)
		end
	end
end

function Fish.start()
	folder.Parent = workspace
	local spawnCenter = Vector3.new(0, 0, 0)
	for _ = 1, SPAWN_FISH do
		table.insert(fishes, makeFish(rng, function()
			return spawnCenter
		end, rng:NextNumber(10, 22)))
	end

	local reefs = workspace:WaitForChild("Reefs")
	task.spawn(function()
		while true do
			rebalance(reefs)
			task.wait(REBALANCE_SECONDS)
		end
	end)

	local camera = workspace.CurrentCamera
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cameraPosition = camera.CFrame.Position
		table.clear(parts)
		table.clear(frames)
		for _, fish in fishes do
			local center = fish.center()
			if not center or (center - cameraPosition).Magnitude > ANIMATE_DISTANCE + fish.radius then
				continue
			end
			-- Circle the center, drifting up and down a little, facing along the path.
			local angle = fish.phase + fish.direction * t * fish.speed / fish.radius
			local y = fish.height + math.sin(t * 0.8 + fish.phase) * 0.8
			local position = center + Vector3.new(math.cos(angle) * fish.radius, y, math.sin(angle) * fish.radius)
			-- Scatter: dart away from the player, then drift back into the school.
			if root then
				local away = (position + fish.scatter) - root.Position
				local distance = away.Magnitude
				if distance < SCATTER_RADIUS and distance > 0.01 then
					fish.scatter += away.Unit * (SCATTER_RADIUS - distance) * 0.25
				end
			end
			fish.scatter *= 0.96
			position += fish.scatter
			local heading = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * fish.direction
			local body = CFrame.lookAt(position, position + heading)
			-- The tail hinges just behind the body and swishes side to side.
			local wiggle = CFrame.Angles(0, math.sin(t * 9 + fish.phase) * 0.5, 0)
			local tail = body * CFrame.new(0, 0, 0.6 * fish.scale) * wiggle * CFrame.new(0, 0, 0.35 * fish.scale)
			for i, part in fish.parts do
				parts[#parts + 1] = part
				frames[#frames + 1] = if i == 2 then tail else body * fish.offsets[i]
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)

	Players.LocalPlayer.CharacterAdded:Connect(function()
		rebalance(reefs)
	end)
end

return Fish
