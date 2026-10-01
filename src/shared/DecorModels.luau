--!strict
-- Reef decorations unlocked by reef level, built from parts. Each model's
-- pivot is at its base, facing -Z.

local DecorModels = {}

local GOLD = Color3.fromRGB(255, 200, 70)
local WOOD = Color3.fromRGB(130, 85, 50)
local STONE = Color3.fromRGB(150, 150, 160)

local function newPart(model: Model, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = model
	return part
end

local function ellipsoid(model: Model, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = newPart(model, { Size = size, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function light(part: BasePart, color: Color3, range: number)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Range = range
	pointLight.Brightness = 1.5
	pointLight.Parent = part
end

local function bubbles(part: BasePart, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(230, 250, 255))
	emitter.Transparency = NumberSequence.new(0.3, 1)
	emitter.Size = NumberSequence.new(0.3, 0.6)
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(3, 5)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.Parent = part
end

type Builder = (model: Model) -> ()
local builders: { [string]: Builder } = {}

builders.TreasureChest = function(model)
	newPart(model, { Size = Vector3.new(3, 1.6, 2), CFrame = CFrame.new(0, 0.8, 0), Color = WOOD, Material = Enum.Material.Wood })
	-- Open lid, tilted back.
	newPart(model, { Size = Vector3.new(3, 0.3, 2), CFrame = CFrame.new(0, 2, 1.1) * CFrame.Angles(math.rad(-65), 0, 0), Color = WOOD, Material = Enum.Material.Wood })
	for _, x in { -1.3, 1.3 } do
		newPart(model, { Size = Vector3.new(0.2, 1.7, 2.1), CFrame = CFrame.new(x, 0.85, 0), Color = GOLD, Material = Enum.Material.Metal })
	end
	local coins = ellipsoid(model, Vector3.new(2.6, 0.7, 1.6), CFrame.new(0, 1.6, 0), GOLD, Enum.Material.Neon)
	light(coins, GOLD, 8)
end

builders.SeaLantern = function(model)
	newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 0.3, 0.3), CFrame = CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = STONE })
	local glass = newPart(model, { Size = Vector3.new(1.2, 1.4, 1.2), CFrame = CFrame.new(0, 4.6, 0), Color = Color3.fromRGB(150, 255, 230), Material = Enum.Material.Neon, Transparency = 0.2 })
	newPart(model, { Size = Vector3.new(1.5, 0.25, 1.5), CFrame = CFrame.new(0, 5.4, 0), Color = STONE })
	newPart(model, { Size = Vector3.new(1.5, 0.25, 1.5), CFrame = CFrame.new(0, 3.85, 0), Color = STONE })
	light(glass, Color3.fromRGB(150, 255, 230), 14)
end

builders.ShellArch = function(model)
	for i = 0, 8 do
		local a = i / 8 * math.pi
		ellipsoid(
			model,
			Vector3.new(1.4, 1.4, 1.1),
			CFrame.new(math.cos(a) * 3, math.sin(a) * 3 + 0.5, 0) * CFrame.Angles(0, 0, a),
			Color3.fromRGB(255, 220, 230):Lerp(Color3.fromRGB(255, 170, 190), i / 8)
		)
	end
end

builders.Anchor = function(model)
	local iron = Color3.fromRGB(80, 85, 95)
	newPart(model, { Size = Vector3.new(0.5, 4, 0.5), CFrame = CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, 0.25), Color = iron, Material = Enum.Material.Metal })
	newPart(model, { Size = Vector3.new(2.2, 0.4, 0.5), CFrame = CFrame.new(-0.4, 3.9, 0) * CFrame.Angles(0, 0, 0.25), Color = iron, Material = Enum.Material.Metal })
	newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1.1, 1.1), CFrame = CFrame.new(-0.65, 4.95, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = iron, Material = Enum.Material.Metal })
	for _, side in { -1, 1 } do
		newPart(model, { Size = Vector3.new(1.8, 0.45, 0.5), CFrame = CFrame.new(0.5 + side * 0.8, 0.8 + side * -0.2, 0) * CFrame.Angles(0, 0, side * 0.7), Color = iron, Material = Enum.Material.Metal })
	end
end

builders.CoralStatue = function(model)
	newPart(model, { Size = Vector3.new(2.4, 1, 2.4), CFrame = CFrame.new(0, 0.5, 0), Color = STONE, Material = Enum.Material.Marble })
	ellipsoid(model, Vector3.new(1.2, 2.6, 1), CFrame.new(0, 2.3, 0), STONE, Enum.Material.Marble)
	newPart(model, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = CFrame.new(0, 4, 0), Color = STONE, Material = Enum.Material.Marble })
	ellipsoid(model, Vector3.new(0.2, 1.3, 1.6), CFrame.new(0, 1.1, 0.7) * CFrame.Angles(0.6, 0, 0), STONE, Enum.Material.Marble)
	for _, side in { -1, 1 } do
		newPart(model, { Size = Vector3.new(0.35, 1.6, 0.35), CFrame = CFrame.new(side * 0.8, 3.4, 0) * CFrame.Angles(0, 0, side * -0.5), Color = STONE, Material = Enum.Material.Marble })
	end
end

builders.BubbleFountain = function(model)
	newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 3.4, 3.4), CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = STONE, Material = Enum.Material.Marble })
	local spout = newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 0.7, 0.7), CFrame = CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = STONE, Material = Enum.Material.Marble })
	ellipsoid(model, Vector3.new(1.4, 0.6, 1.4), CFrame.new(0, 2.7, 0), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	bubbles(spout, 12)
end

builders.GoldenTrident = function(model)
	newPart(model, { Size = Vector3.new(0.35, 6, 0.35), CFrame = CFrame.new(0, 3, 0), Color = GOLD, Material = Enum.Material.Metal })
	newPart(model, { Size = Vector3.new(2.2, 0.35, 0.35), CFrame = CFrame.new(0, 6, 0), Color = GOLD, Material = Enum.Material.Metal })
	for _, x in { -1, 0, 1 } do
		local prong = newPart(model, { Size = Vector3.new(0.3, 1.6, 0.3), CFrame = CFrame.new(x, 6.9, 0), Color = GOLD, Material = Enum.Material.Neon })
		if x == 0 then
			light(prong, GOLD, 12)
		end
	end
end

function DecorModels.build(id: string): Model
	local model = Instance.new("Model")
	model.Name = id
	local root = newPart(model, { Name = "Root", Size = Vector3.one * 0.2, Transparency = 1, CanQuery = false })
	model.PrimaryPart = root
	local builder = builders[id]
	if builder then
		builder(model)
	end
	return model
end

DecorModels.names = {
	TreasureChest = "Treasure Chest",
	SeaLantern = "Sea Lantern",
	ShellArch = "Shell Arch",
	Anchor = "Anchor",
	CoralStatue = "Coral Statue",
	BubbleFountain = "Bubble Fountain",
	GoldenTrident = "Golden Trident",
}

return DecorModels
