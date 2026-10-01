--!strict
-- Procedural coral models built from parts, so no uploaded meshes are needed.
-- Each model's pivot is at its base, facing up. The same seed always builds
-- the same shape, so a slot's coral looks the same for every player.

local CoralModels = {}

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local function shade(color: Color3, amount: number): Color3
	return if amount < 0 then color:Lerp(BLACK, -amount) else color:Lerp(WHITE, amount)
end

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

-- An ellipsoid: a block with a sphere mesh, which stretches with the part size.
local function ellipsoid(model: Model, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = newPart(model, { Size = size, CFrame = cframe, Color = color, Material = material or Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function ball(model: Model, center: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
	return newPart(model, {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		CFrame = CFrame.new(center),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- A cylinder from a to b. Roblox cylinders run along their X axis.
local function limb(model: Model, a: Vector3, b: Vector3, radius: number, color: Color3, material: Enum.Material?): Part
	local direction = b - a
	local up = if math.abs(direction.Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	return newPart(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(direction.Magnitude, radius * 2, radius * 2),
		CFrame = CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

-- A direction tilted `tilt` radians away from straight up, turned `yaw` around Y.
local function tilted(yaw: number, tilt: number): Vector3
	return Vector3.new(math.sin(tilt) * math.cos(yaw), math.cos(tilt), math.sin(tilt) * math.sin(yaw))
end

local function glow(model: Model, color: Color3, range: number, brightness: number)
	local root = model.PrimaryPart :: BasePart
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = root
end

local function shimmer(model: Model, color: Color3, rate: number)
	local root = model.PrimaryPart :: BasePart
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = root
end

type Builder = (model: Model, rng: Random, color: Color3) -> ()

local builders: { [string]: Builder } = {}

-- Antler-like branches that spread outward and up, with pale tips.
builders.Staghorn = function(model, rng, color)
	local tip = shade(color, 0.45)
	local count = 5
	for i = 1, count do
		local yaw = (i / count) * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local start = Vector3.new(0, 0.3, 0)
		local elbow = start + tilted(yaw, rng:NextNumber(0.7, 1.0)) * rng:NextNumber(1.1, 1.5)
		limb(model, start, elbow, 0.26, color)
		ball(model, elbow, 0.52, color)
		-- Each branch turns upward and may fork.
		for f = 1, rng:NextInteger(1, 2) do
			local forkYaw = yaw + (if f == 1 then rng:NextNumber(-0.3, 0.3) else rng:NextNumber(0.6, 1.0))
			local tipPos = elbow + tilted(forkYaw, rng:NextNumber(0.15, 0.45)) * rng:NextNumber(1.1, 1.8)
			limb(model, elbow, tipPos, 0.21, color)
			ball(model, tipPos, 0.46, tip)
		end
	end
end

-- A squat dome covered in meandering ridges that follow its surface.
builders.Brain = function(model, rng, color)
	local radius, height, centerY = 1.7, 1.15, 0.9
	local dome = ellipsoid(model, Vector3.new(radius * 2, height * 2, radius * 2), CFrame.new(0, centerY, 0), color)
	dome.Material = Enum.Material.Slate
	local ridge = shade(color, -0.3)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local function surface(x: number, z: number): Vector3
		local inside = math.max(0, 1 - (x * x + z * z) / (radius * radius))
		return yaw * Vector3.new(x, centerY + height * math.sqrt(inside) - 0.04, z)
	end
	for r = -2, 2 do
		local offset = r * 0.55
		local reach = math.sqrt(radius * radius - offset * offset) * 0.8
		local phase = rng:NextNumber(0, math.pi * 2)
		local previous: Vector3? = nil
		for k = 0, 4 do
			local t = -reach + (k / 4) * reach * 2
			local point = surface(offset + math.sin(t * 2.2 + phase) * 0.14, t)
			if previous then
				limb(model, previous, point, 0.17, ridge)
			end
			previous = point
		end
	end
end

-- A flat sea fan: a lattice of branches with a thin see-through membrane.
local function seaFan(model: Model, rng: Random, color: Color3, frame: CFrame, scale: number)
	local branch = shade(color, -0.15)
	local trunkTop = frame * Vector3.new(0, 0.7 * scale, 0)
	limb(model, frame.Position, trunkTop, 0.16 * scale, branch)
	local rays = 6
	local inner: { Vector3 } = {}
	for i = 1, rays do
		local angle = math.rad(-58 + (i - 1) * (116 / (rays - 1)) + rng:NextNumber(-5, 5))
		local length = rng:NextNumber(2.1, 2.5) * scale
		local tip = frame * Vector3.new(math.sin(angle) * length, 0.7 * scale + math.cos(angle) * length, 0)
		limb(model, trunkTop, tip, 0.07 * scale, branch)
		table.insert(inner, trunkTop + (tip - trunkTop) * 0.6)
	end
	-- A cross-strand ties the rays together into a lattice.
	for i = 1, rays - 1 do
		limb(model, inner[i], inner[i + 1], 0.05 * scale, branch)
	end
	local membrane = ellipsoid(
		model,
		Vector3.new(3.8, 2.8, 0.06) * scale,
		frame * CFrame.new(0, (0.7 + 1.35) * scale, 0),
		shade(color, 0.15)
	)
	membrane.Transparency = 0.35
end

builders.Fan = function(model, rng, color)
	local yaw = rng:NextNumber(0, math.pi * 2)
	seaFan(model, rng, color, CFrame.Angles(0, yaw, 0) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, 0), 1)
	seaFan(model, rng, shade(color, 0.2), CFrame.Angles(0, yaw + 0.9, 0) * CFrame.new(0.5, 0, 0.3) * CFrame.Angles(0.15, 0, 0), 0.6)
end

-- A cluster of glowing tubes.
builders.GlowingTube = function(model, rng, color)
	local body = shade(color, -0.35)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local radius = if i == 1 then 0 else rng:NextNumber(0.6, 1.1)
		local base = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local height = rng:NextNumber(1.6, 3.2)
		local top = base + tilted(angle, radius * 0.15) * height
		local width = rng:NextNumber(0.32, 0.45)
		limb(model, base, top, width, body)
		local rim = limb(model, top - (top - base).Unit * 0.15, top + (top - base).Unit * 0.05, width + 0.06, color, Enum.Material.Neon)
		rim.Name = "Rim"
	end
	glow(model, color, 10, 1.5)
	shimmer(model, color, 2)
end

-- Faceted crystal shards around a glowing core.
builders.Crystal = function(model, rng, color)
	newPart(model, {
		Size = Vector3.new(0.7, 3.6, 0.7),
		CFrame = CFrame.new(0, 1.8, 0) * CFrame.Angles(0, math.pi / 4, 0),
		Color = color,
		Material = Enum.Material.Neon,
	})
	for i = 1, 7 do
		local yaw = (i / 7) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local height = rng:NextNumber(1.8, 3.4)
		local shard = newPart(model, {
			Size = Vector3.new(rng:NextNumber(0.6, 0.9), height, rng:NextNumber(0.6, 0.9)),
			Color = shade(color, rng:NextNumber(-0.15, 0.25)),
			Material = Enum.Material.Glass,
			Transparency = 0.25,
		})
		shard.CFrame = CFrame.Angles(0, yaw, 0)
			* CFrame.new(0.7, 0, 0)
			* CFrame.Angles(0, 0, -rng:NextNumber(0.2, 0.55))
			* CFrame.new(0, height / 2, 0)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	end
	glow(model, color, 14, 2.5)
	shimmer(model, WHITE, 5)
end

-- An open oyster shell holding a glowing pearl (VIP coral).
builders.Pearlescent = function(model, rng, color)
	local shell = shade(color, -0.1)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local frame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, yaw, 0)
	ellipsoid(model, Vector3.new(3, 0.7, 2.6), frame, shell)
	ellipsoid(model, Vector3.new(3, 0.6, 2.6), frame * CFrame.new(0, 0.3, 0.9) * CFrame.Angles(-1.0, 0, 0) * CFrame.new(0, 0, -1.1), shade(color, 0.1))
	ball(model, (frame * CFrame.new(0, 0.6, -0.1)).Position, 1, Color3.fromRGB(255, 250, 245), Enum.Material.Neon)
	glow(model, Color3.fromRGB(255, 230, 250), 10, 2)
	shimmer(model, Color3.fromRGB(255, 240, 250), 3)
end

-- Kelp Forest: clusters of little green grapes on short stems.
builders.SeaGrape = function(model, rng, color)
	for i = 1, 7 do
		local yaw = i / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local top = Vector3.new(0, 0.3, 0) + tilted(yaw, rng:NextNumber(0.2, 0.6)) * rng:NextNumber(1.2, 2.2)
		limb(model, Vector3.new(0, 0.3, 0), top, 0.1, shade(color, -0.3))
		for g = 0, 2 do
			ball(model, top + Vector3.new(rng:NextNumber(-0.25, 0.25), g * 0.32, rng:NextNumber(-0.25, 0.25)), 0.42, shade(color, g * 0.1))
		end
	end
end

-- Kelp Forest: tall leaning blades with glowing bulbs.
builders.KelpBloom = function(model, rng, color)
	for i = 1, 5 do
		local yaw = i / 5 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local height = rng:NextNumber(2.6, 3.8)
		local lean = rng:NextNumber(0.1, 0.3)
		local blade = ellipsoid(model, Vector3.new(0.5, height, 0.12), CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, height / 2 + 0.2, 0.3), shade(color, -0.25))
		blade.Name = "Blade"
		ball(model, (CFrame.Angles(0, yaw, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, height + 0.2, 0.3)).Position, 0.5, shade(color, 0.3), Enum.Material.Neon)
	end
end

-- Shipwreck: chunky orange tube sponges with dark openings.
builders.AnchorSponge = function(model, rng, color)
	for i = 1, 4 do
		local angle = i / 4 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local base = Vector3.new(math.cos(angle) * 0.7, 0, math.sin(angle) * 0.7)
		local height = rng:NextNumber(1.6, 2.8)
		local top = base + tilted(angle, 0.2) * height
		limb(model, base, top, 0.5, color, Enum.Material.Sand)
		limb(model, top - (top - base).Unit * 0.05, top + (top - base).Unit * 0.02, 0.32, shade(color, -0.7))
	end
end

-- Shipwreck: gleaming gold branches tipped with coins.
builders.TreasureCoral = function(model, rng, color)
	for i = 1, 5 do
		local yaw = i / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local elbow = Vector3.new(0, 0.3, 0) + tilted(yaw, rng:NextNumber(0.4, 0.8)) * rng:NextNumber(1, 1.4)
		limb(model, Vector3.new(0, 0.3, 0), elbow, 0.22, color, Enum.Material.Metal)
		local tip = elbow + tilted(yaw, 0.2) * rng:NextNumber(1, 1.5)
		limb(model, elbow, tip, 0.18, color, Enum.Material.Metal)
		newPart(model, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 0.6, 0.6),
			CFrame = CFrame.new(tip) * CFrame.Angles(0, yaw, math.pi / 2 + 0.3),
			Color = shade(color, 0.3),
			Material = Enum.Material.Neon,
		})
	end
	shimmer(model, Color3.fromRGB(255, 230, 120), 3)
end

-- Deep Sea: a glowing bulb on a stalk, ringed by tentacles.
builders.LanternAnemone = function(model, rng, color)
	limb(model, Vector3.new(0, 0, 0), Vector3.new(0, 2.2, 0), 0.3, shade(color, -0.5))
	ball(model, Vector3.new(0, 2.7, 0), 1.2, color, Enum.Material.Neon)
	for i = 1, 8 do
		local yaw = i / 8 * math.pi * 2
		limb(model, Vector3.new(0, 2.2, 0), Vector3.new(0, 2.2, 0) + tilted(yaw, rng:NextNumber(1.0, 1.4)) * 1.1, 0.07, shade(color, 0.2), Enum.Material.Neon)
	end
	glow(model, color, 12, 2)
end

-- Deep Sea: thin dark spiky branches dotted with white polyps.
builders.BlackCoral = function(model, rng, color)
	local polyp = Color3.fromRGB(240, 240, 250)
	for i = 1, 6 do
		local yaw = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local start = Vector3.new(0, 0.3, 0)
		local tip = start + tilted(yaw, rng:NextNumber(0.2, 0.5)) * rng:NextNumber(2.4, 3.4)
		limb(model, start, tip, 0.09, color)
		for k = 1, 3 do
			ball(model, start + (tip - start) * (k / 3.3), 0.22, polyp, Enum.Material.Neon)
		end
	end
end

-- A plain blob for any coral type without its own builder yet.
local function fallback(model: Model, _rng: Random, color: Color3)
	ellipsoid(model, Vector3.new(2.6, 2.4, 2.6), CFrame.new(0, 1.2, 0), color)
end

-- Builds a coral model with its pivot at its base. `color` is {r, g, b} in 0-255.
function CoralModels.build(coralType: string, color: { number }, seed: number): Model
	local model = Instance.new("Model")
	model.Name = coralType
	local root = newPart(model, {
		Name = "Root",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
	})
	model.PrimaryPart = root

	local rng = Random.new(seed)
	local base = Color3.fromRGB(color[1], color[2], color[3])
	-- A small rock mound grounds every coral.
	ellipsoid(model, Vector3.new(2.4, 0.7, 2.4), CFrame.new(0, 0.05, 0), Color3.fromRGB(125, 125, 135), Enum.Material.Slate).Name = "Mound"
	local builder: Builder = builders[coralType] or fallback
	builder(model, rng, base)
	return model
end

return CoralModels
