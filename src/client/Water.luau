-- Moving light on the seafloor (caustics) and a rippling water surface seen
-- from below. Uses the textures in assets/textures once their IDs are in
-- src/shared/Textures.json; until then, soft drifting light patches stand in
-- for the caustics. Everything follows the camera, so the cost stays fixed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local Textures = require(ReplicatedStorage.Shared.Textures)

local SURFACE = Balance.world.surfaceHeight
local CAUSTIC_SIZE = 220 -- studs of seafloor covered around the camera
local CAUSTIC_TILE = 28
-- The planes follow the camera in steps that every tile size divides evenly,
-- so the patterns never jump.
local SNAP = CAUSTIC_TILE * 4
local PATCHES = 26 -- fallback light patches

local Water = {}

local function textureId(name: string): string?
	local id = (Textures :: any)[name]
	return if type(id) == "number" and id ~= 0 then "rbxassetid://" .. id else nil
end

local function plane(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Parent = workspace
	return p
end

local function texture(parent: BasePart, id: string, face: Enum.NormalId, tile: number, transparency: number, color: Color3): Texture
	local t = Instance.new("Texture")
	t.Texture = id
	t.Face = face
	t.StudsPerTileU = tile
	t.StudsPerTileV = tile
	t.Transparency = transparency
	t.Color3 = color
	t.Parent = parent
	return t
end

function Water.start()
	local camera = workspace.CurrentCamera
	local causticId = textureId("caustics")
	local rippleId = textureId("water_ripple")

	-- Caustics: two layers drifting in different directions make the light dance.
	-- They're painted straight onto the seafloor; a separate plane hovering just
	-- above the sand flickered against it.
	local seafloor = workspace:WaitForChild("Seafloor", 5) :: BasePart?
	local floorPlane = seafloor or plane("Caustics", Vector3.new(CAUSTIC_SIZE, 0.05, CAUSTIC_SIZE))
	local layers: { Texture } = {}
	if causticId then
		table.insert(layers, texture(floorPlane, causticId, Enum.NormalId.Top, CAUSTIC_TILE, 0.82, Color3.fromRGB(200, 255, 245)))
		table.insert(layers, texture(floorPlane, causticId, Enum.NormalId.Top, CAUSTIC_TILE * 2, 0.9, Color3.fromRGB(180, 240, 255)))
	end

	-- Fallback: soft neon patches that drift and pulse near the camera.
	type Patch = { part: BasePart, offset: Vector2, speed: Vector2, phase: number }
	local patches: { Patch } = {}
	if not causticId then
		for i = 1, PATCHES do
			local p = plane("CausticPatch", Vector3.new(0.05, math.random(5, 11), math.random(5, 11)))
			p.Shape = Enum.PartType.Cylinder
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(190, 250, 240)
			p.Transparency = 0.9
			table.insert(patches, {
				part = p,
				offset = Vector2.new(math.random(-60, 60), math.random(-60, 60)),
				speed = Vector2.new(math.random(-20, 20) / 10, math.random(-20, 20) / 10),
				phase = i,
			})
		end
	end

	-- The surface seen from below: a ripple texture drifting across it.
	local surfacePlane = plane("SurfaceRipples", Vector3.new(CAUSTIC_SIZE * 2, 0.05, CAUSTIC_SIZE * 2))
	local ripples: { Texture } = {}
	if rippleId then
		table.insert(ripples, texture(surfacePlane, rippleId, Enum.NormalId.Bottom, CAUSTIC_TILE * 2, 0.5, Color3.fromRGB(220, 250, 255)))
		table.insert(ripples, texture(surfacePlane, rippleId, Enum.NormalId.Bottom, CAUSTIC_TILE * 4, 0.65, Color3.fromRGB(200, 240, 255)))
	end

	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local position = camera.CFrame.Position
		local snapX = math.floor(position.X / SNAP) * SNAP
		local snapZ = math.floor(position.Z / SNAP) * SNAP
		if not seafloor then
			floorPlane.CFrame = CFrame.new(snapX, 0.3, snapZ)
		end
		surfacePlane.CFrame = CFrame.new(snapX, SURFACE - 0.6, snapZ)
		for i, layer in layers do
			local direction = if i == 1 then Vector2.new(1, 0.4) else Vector2.new(-0.5, 1)
			layer.OffsetStudsU = t * 1.6 * direction.X
			layer.OffsetStudsV = t * 1.6 * direction.Y
			layer.Transparency = (if i == 1 then 0.82 else 0.9) + math.sin(t * 0.7 + i) * 0.04
		end
		for i, ripple in ripples do
			ripple.OffsetStudsU = t * (if i == 1 then 2 else -1.3)
			ripple.OffsetStudsV = t * (if i == 1 then 0.8 else 1.7)
		end
		for _, patch in patches do
			local o = patch.offset + patch.speed * t
			local x = (o.X + 90) % 180 - 90
			local z = (o.Y + 90) % 180 - 90
			patch.part.CFrame = CFrame.new(position.X + x, 0.25, position.Z + z) * CFrame.Angles(0, 0, math.pi / 2)
			patch.part.Transparency = 0.86 + math.sin(t * 1.3 + patch.phase) * 0.05
		end
	end)
end

return Water
