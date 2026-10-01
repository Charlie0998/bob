--!strict
-- Procedural creature models built from parts. Every model faces -Z, has its
-- pivot at its center, and keeps its moving bits (tail, fins, tentacles)
-- named so CreatureRenderer can animate them.

local CreatureModels = {}

local BLACK = Color3.new(0, 0, 0)

local function newPart(model: Model, props: { [string]: any }): Part
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
	part.Parent = model
	return part
end

local function ellipsoid(model: Model, size: Vector3, cframe: CFrame, color: Color3, name: string?): Part
	local part = newPart(model, { Name = name or "Part", Size = size, CFrame = cframe, Color = color })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function eyes(model: Model, x: number, y: number, z: number, size: number)
	for _, side in { -1, 1 } do
		newPart(model, {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			CFrame = CFrame.new(x * side, y, z),
			Color = BLACK,
		})
	end
end

type Builder = (model: Model, body: Color3, accent: Color3) -> ()
local builders: { [string]: Builder } = {}

builders.fish = function(model, body, accent)
	ellipsoid(model, Vector3.new(0.6, 1.1, 1.9), CFrame.identity, body, "Body")
	ellipsoid(model, Vector3.new(0.62, 1.0, 0.28), CFrame.new(0, 0, -0.2), accent)
	ellipsoid(model, Vector3.new(0.1, 0.6, 0.9), CFrame.new(0, 0.55, 0.15), accent)
	ellipsoid(model, Vector3.new(0.12, 1.0, 0.7), CFrame.new(0, 0, 1.15), body, "Tail")
	eyes(model, 0.24, 0.15, -0.6, 0.2)
end

builders.shark = function(model, body, accent)
	ellipsoid(model, Vector3.new(1.4, 1.5, 5), CFrame.identity, body, "Body")
	ellipsoid(model, Vector3.new(1.2, 0.6, 4.4), CFrame.new(0, -0.45, 0), accent)
	-- Pale spots
	for i = -2, 2 do
		ellipsoid(model, Vector3.new(1.45, 0.25, 0.25), CFrame.new(0, 0.35, i * 0.8), accent)
	end
	newPart(model, { Size = Vector3.new(0.15, 1.1, 0.9), CFrame = CFrame.new(0, 1, 0.2) * CFrame.Angles(-0.5, 0, 0), Color = body })
	for _, side in { -1, 1 } do
		ellipsoid(model, Vector3.new(1.6, 0.12, 0.7), CFrame.new(side * 1.2, -0.3, -0.6) * CFrame.Angles(0, 0, side * -0.3), body, "Fin")
	end
	ellipsoid(model, Vector3.new(0.15, 2, 1), CFrame.new(0, 0.2, 2.9), body, "Tail")
	eyes(model, 0.6, 0.1, -2.1, 0.22)
end

builders.puffer = function(model, body, accent)
	ellipsoid(model, Vector3.new(1.5, 1.4, 1.6), CFrame.identity, body, "Body")
	ellipsoid(model, Vector3.new(1.3, 0.7, 1.4), CFrame.new(0, -0.4, 0), Color3.new(1, 1, 1))
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		newPart(model, {
			Size = Vector3.new(0.08, 0.35, 0.08),
			CFrame = CFrame.Angles(a, 0, 0) * CFrame.new(0, 0.75, 0),
			Color = accent,
		})
	end
	ellipsoid(model, Vector3.new(0.1, 0.5, 0.4), CFrame.new(0, 0, 0.9), body, "Tail")
	eyes(model, 0.4, 0.25, -0.6, 0.24)
end

builders.crab = function(model, body, accent)
	ellipsoid(model, Vector3.new(1.6, 0.6, 1.1), CFrame.new(0, 0.4, 0), body, "Body")
	for _, side in { -1, 1 } do
		for leg = -1, 1 do
			newPart(model, {
				Name = "Leg",
				Size = Vector3.new(0.9, 0.12, 0.12),
				CFrame = CFrame.new(side * 0.9, 0.2, leg * 0.35) * CFrame.Angles(0, 0, side * 0.6),
				Color = body,
			})
		end
		ellipsoid(model, Vector3.new(0.45, 0.35, 0.6), CFrame.new(side * 0.7, 0.45, -0.8), accent, "Claw")
		newPart(model, { Size = Vector3.new(0.08, 0.4, 0.08), CFrame = CFrame.new(side * 0.25, 0.85, -0.35), Color = body })
		newPart(model, { Shape = Enum.PartType.Ball, Size = Vector3.one * 0.18, CFrame = CFrame.new(side * 0.25, 1.05, -0.35), Color = BLACK })
	end
end

builders.star = function(model, body, accent)
	ellipsoid(model, Vector3.new(0.7, 0.3, 0.7), CFrame.new(0, 0.15, 0), accent, "Body")
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		ellipsoid(model, Vector3.new(0.45, 0.22, 1.3), CFrame.Angles(0, a, 0) * CFrame.new(0, 0.12, -0.65), body, "Arm")
	end
end

builders.turtle = function(model, body, accent)
	ellipsoid(model, Vector3.new(2.2, 0.9, 2.6), CFrame.new(0, 0.15, 0), accent, "Body")
	ellipsoid(model, Vector3.new(2, 0.5, 2.4), CFrame.new(0, -0.2, 0), body)
	ellipsoid(model, Vector3.new(0.7, 0.6, 0.9), CFrame.new(0, 0.05, -1.55), body)
	for _, side in { -1, 1 } do
		ellipsoid(model, Vector3.new(1.4, 0.15, 0.6), CFrame.new(side * 1.3, -0.1, -0.6) * CFrame.Angles(0, side * 0.4, 0), body, "Fin")
		ellipsoid(model, Vector3.new(0.6, 0.12, 0.4), CFrame.new(side * 0.8, -0.15, 1.1), body)
	end
	eyes(model, 0.25, 0.2, -1.85, 0.15)
end

builders.ray = function(model, body, accent)
	ellipsoid(model, Vector3.new(4, 0.35, 2.4), CFrame.identity, body, "Body")
	ellipsoid(model, Vector3.new(3.6, 0.3, 2), CFrame.new(0, -0.05, 0.1), accent)
	for _, side in { -1, 1 } do
		ellipsoid(model, Vector3.new(1.6, 0.2, 1.2), CFrame.new(side * 1.7, 0, 0.1), body, "Fin")
	end
	newPart(model, { Name = "Tail", Size = Vector3.new(0.1, 0.1, 2.6), CFrame = CFrame.new(0, 0, 2.4), Color = body })
	eyes(model, 0.4, 0.2, -0.9, 0.16)
end

builders.jelly = function(model, body, accent)
	local bell = ellipsoid(model, Vector3.new(1.8, 1.2, 1.8), CFrame.new(0, 0.6, 0), body, "Body")
	bell.Transparency = 0.35
	bell.Material = Enum.Material.Neon
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local tentacle = newPart(model, {
			Name = "Tentacle",
			Size = Vector3.new(0.08, 2, 0.08),
			CFrame = CFrame.new(math.cos(a) * 0.5, -0.6, math.sin(a) * 0.5),
			Color = accent,
			Transparency = 0.3,
		})
		tentacle.Material = Enum.Material.Neon
	end
	local light = Instance.new("PointLight")
	light.Color = body
	light.Range = 8
	light.Brightness = 1
	light.Parent = bell
end

builders.octopus = function(model, body, accent)
	ellipsoid(model, Vector3.new(1.4, 1.6, 1.4), CFrame.new(0, 0.8, 0.2), body, "Body")
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		ellipsoid(model, Vector3.new(0.3, 0.3, 1.5), CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.9) * CFrame.Angles(-0.3, 0, 0), accent, "Tentacle")
	end
	eyes(model, 0.35, 0.6, -0.5, 0.22)
end

builders.seahorse = function(model, body, accent)
	ellipsoid(model, Vector3.new(0.6, 1.6, 0.8), CFrame.new(0, 0.3, 0) * CFrame.Angles(-0.15, 0, 0), body, "Body")
	ellipsoid(model, Vector3.new(0.5, 0.55, 0.7), CFrame.new(0, 1.25, -0.15), body)
	ellipsoid(model, Vector3.new(0.18, 0.18, 0.6), CFrame.new(0, 1.2, -0.6), body)
	ellipsoid(model, Vector3.new(0.08, 0.6, 0.4), CFrame.new(0, 0.5, 0.4), accent, "Fin")
	ellipsoid(model, Vector3.new(0.3, 0.8, 0.3), CFrame.new(0, -0.7, 0.15) * CFrame.Angles(0.5, 0, 0), body, "Tail")
	eyes(model, 0.2, 1.3, -0.3, 0.14)
end

builders.dolphin = function(model, body, accent)
	ellipsoid(model, Vector3.new(1.3, 1.4, 4.2), CFrame.identity, body, "Body")
	ellipsoid(model, Vector3.new(1.1, 0.7, 3.6), CFrame.new(0, -0.4, 0), accent)
	ellipsoid(model, Vector3.new(0.45, 0.4, 1.1), CFrame.new(0, -0.15, -2.4), body)
	newPart(model, { Size = Vector3.new(0.15, 0.9, 0.8), CFrame = CFrame.new(0, 0.85, 0.2) * CFrame.Angles(-0.6, 0, 0), Color = body })
	for _, side in { -1, 1 } do
		ellipsoid(model, Vector3.new(1.1, 0.12, 0.5), CFrame.new(side * 0.8, -0.4, -0.8) * CFrame.Angles(0, 0, side * -0.4), body, "Fin")
	end
	ellipsoid(model, Vector3.new(1.8, 0.12, 0.7), CFrame.new(0, 0, 2.35), body, "Tail")
	eyes(model, 0.55, 0.15, -1.5, 0.16)
end

-- Builds a creature model. Colors are {r, g, b} in 0-255.
function CreatureModels.build(kind: string, color: { number }, accent: { number }): Model
	local model = Instance.new("Model")
	model.Name = kind
	local root = newPart(model, { Name = "Root", Size = Vector3.one * 0.2, Transparency = 1 })
	model.PrimaryPart = root
	local builder = builders[kind] or builders.fish
	builder(model, Color3.fromRGB(color[1], color[2], color[3]), Color3.fromRGB(accent[1], accent[2], accent[3]))
	return model
end

-- Crawlers sit on the sand; everything else swims.
function CreatureModels.isCrawler(kind: string): boolean
	return kind == "crab" or kind == "star"
end

return CreatureModels
