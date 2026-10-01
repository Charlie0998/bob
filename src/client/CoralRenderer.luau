-- Draws a coral model on every slot tile from the tile's attributes, scales it
-- with growth, and sparkles it when it's ready to harvest. Everything here is
-- local to this client; the server only sets attributes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CoralModels = require(ReplicatedStorage.Shared.CoralModels)
local ReefMath = require(ReplicatedStorage.Shared.ReefMath)

local MIN_SCALE = 0.35 -- size of a freshly planted fragment
local SCALE_STEP = 0.02 -- only rescale when growth moves this much

type Entry = {
	model: Model?,
	rainbow: { BasePart }?,
	readyFx: ParticleEmitter?,
	readyGlow: { light: PointLight, ring: BasePart }?,
	ready: boolean,
	scale: number,
	animating: boolean,
}

local CoralRenderer = {}

local entries: { [BasePart]: Entry } = {}
local nightGlow = false

local function addNightLight(model: Model)
	local root = model.PrimaryPart
	if root and not root:FindFirstChild("NightGlow") then
		local light = Instance.new("PointLight")
		light.Name = "NightGlow"
		light.Range = 9
		light.Brightness = 1.2
		local first = model:FindFirstChildWhichIsA("BasePart")
		light.Color = if first then first.Color else Color3.new(1, 1, 1)
		light.Parent = root
	end
end

-- Mutated corals look special: Glowing turns neon, Rainbow cycles through
-- colors, Crystalline turns to sparkling glass.
local function applyMutation(model: Model, mutation: string, entry: Entry)
	local parts = {}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Root" and part.Name ~= "Mound" then
			table.insert(parts, part)
		end
	end
	local root = model.PrimaryPart :: BasePart
	if mutation == "Glowing" then
		for _, part in parts do
			part.Material = Enum.Material.Neon
		end
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 2
		light.Color = if parts[1] then parts[1].Color else Color3.new(1, 1, 1)
		light.Parent = root
	elseif mutation == "Rainbow" then
		for _, part in parts do
			part.Material = Enum.Material.Neon
		end
		entry.rainbow = parts
	elseif mutation == "Crystalline" then
		for _, part in parts do
			part.Material = Enum.Material.Glass
			part.Transparency = math.max(part.Transparency, 0.3)
			part.Color = part.Color:Lerp(Color3.fromRGB(220, 250, 255), 0.6)
		end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.4, 0)
		emitter.Lifetime = NumberRange.new(1, 1.6)
		emitter.Rate = 6
		emitter.Speed = NumberRange.new(1, 2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = root
	end
end

-- Tiles are cylinders turned on their side; this is the upright frame on top.
local function uprightFrame(tile: BasePart): CFrame
	return tile.CFrame * CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(0, tile.Size.X / 2, 0)
end

local function targetScale(tile: BasePart, now: number): number
	local def = Balance.corals[tile:GetAttribute("CoralType")]
	local bornAt = tile:GetAttribute("BornAt") or now
	local progress = math.clamp((now - bornAt) / def.growSeconds, 0, 1)
	local scale = MIN_SCALE + (1 - MIN_SCALE) * progress
	return math.floor(scale / SCALE_STEP) * SCALE_STEP
end

local function setScale(entry: Entry, scale: number)
	local model = entry.model
	if model and model.Parent and scale > 0 then
		model:ScaleTo(scale)
		entry.scale = scale
	end
end

-- Animates the model's scale with an easing curve, then hands control back to
-- the regular growth update.
local function animateScale(entry: Entry, from: number, to: number, duration: number, style: Enum.EasingStyle)
	entry.animating = true
	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = math.min(1, (os.clock() - started) / duration)
		setScale(entry, from + (to - from) * TweenService:GetValue(alpha, style, Enum.EasingDirection.Out))
		if alpha >= 1 or not entry.model then
			connection:Disconnect()
			entry.animating = false
		end
	end)
end

local function makeReadyFx(model: Model): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ReadySparkle"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Rate = 8
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Enabled = false
	emitter.Parent = model.PrimaryPart
	return emitter
end

local function rebuild(tile: BasePart, entry: Entry)
	if entry.model then
		entry.model:Destroy()
		entry.model = nil
		entry.readyFx = nil
	end
	local coralType = tile:GetAttribute("CoralType")
	local def = Balance.corals[coralType]
	if not def then
		return
	end
	local ownerId = tile:GetAttribute("OwnerId") :: number? or 0
	local slot = tile:GetAttribute("Slot") :: number? or 0
	local seed = ownerId * 64 + slot
	local model = CoralModels.build(coralType, def.color, seed)
	model.Name = "CoralVisual"
	model:PivotTo(uprightFrame(tile))
	entry.readyFx = makeReadyFx(model)
	-- Ready-to-harvest glow: a soft light and a glowing ring at the base that pulse.
	local ring = Instance.new("Part")
	ring.Name = "ReadyRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.1, 4.6, 4.6)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 230, 120)
	ring.Transparency = 1
	ring.CFrame = uprightFrame(tile) * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 225, 140)
	light.Range = 9
	light.Brightness = 0
	light.Parent = model.PrimaryPart
	entry.readyGlow = { light = light, ring = ring }
	entry.ready = false
	entry.rainbow = nil
	local mutation = tile:GetAttribute("Mutation")
	if type(mutation) == "string" and mutation ~= "" then
		applyMutation(model, mutation, entry)
	end
	if nightGlow then
		addNightLight(model)
	end
	model.Parent = tile
	entry.model = model
	entry.scale = 1
	setScale(entry, targetScale(tile, workspace:GetServerTimeNow()))
end

local function onTileAdded(instance: Instance)
	if not instance:IsA("BasePart") or entries[instance] then
		return
	end
	local tile = instance :: BasePart
	local entry: Entry = { model = nil, rainbow = nil, readyFx = nil, readyGlow = nil, ready = false, scale = 1, animating = false }
	entries[tile] = entry
	rebuild(tile, entry)
	tile:GetAttributeChangedSignal("CoralType"):Connect(function()
		rebuild(tile, entry)
	end)
	tile:GetAttributeChangedSignal("Mutation"):Connect(function()
		rebuild(tile, entry)
	end)
end

local function onTileRemoved(instance: Instance)
	local entry = entries[instance :: BasePart]
	if entry then
		entries[instance :: BasePart] = nil
		if entry.model then
			entry.model:Destroy()
		end
	end
end

-- Called a few times a second from the client's main loop.
function CoralRenderer.update(now: number)
	for tile, entry in entries do
		if not entry.model then
			continue
		end
		local def = Balance.corals[tile:GetAttribute("CoralType")]
		if not entry.animating then
			local target = targetScale(tile, now)
			if math.abs(target - entry.scale) >= SCALE_STEP / 2 then
				setScale(entry, target)
			end
		end
		local plantedAt = tile:GetAttribute("PlantedAt") or now
		local cycles = ReefMath.readyCycles(plantedAt, now, def.growSeconds, Balance.offlineCapSeconds)
		entry.ready = cycles > 0
		if entry.readyFx then
			entry.readyFx.Enabled = cycles > 0
		end
	end
end

-- Fragment springs up out of the sand.
function CoralRenderer.pop(tile: BasePart)
	local entry = entries[tile]
	if entry and entry.model then
		animateScale(entry, 0.05, targetScale(tile, workspace:GetServerTimeNow()), 0.45, Enum.EasingStyle.Back)
	end
end

-- Quick squash-and-stretch when harvested.
function CoralRenderer.pulse(tile: BasePart)
	local entry = entries[tile]
	if entry and entry.model and not entry.animating then
		local scale = entry.scale
		animateScale(entry, scale * 1.18, scale, 0.35, Enum.EasingStyle.Elastic)
	end
end

-- Tops of corals that are ready to harvest (cleaner fish gather there).
function CoralRenderer.readyTops(): { Vector3 }
	local list = {}
	for tile, entry in entries do
		if entry.ready and entry.model then
			table.insert(list, CoralRenderer.topOf(tile))
		end
	end
	return list
end

function CoralRenderer.topOf(tile: BasePart): Vector3
	local entry = entries[tile]
	local height = if entry and entry.model then 3.5 * entry.scale else 1
	return uprightFrame(tile).Position + Vector3.new(0, height, 0)
end

-- Night Glow event: every coral gets a soft light in its own color.
function CoralRenderer.setNightGlow(on: boolean)
	nightGlow = on
	for _, entry in entries do
		local model = entry.model
		if model then
			if on then
				addNightLight(model)
			else
				local root = model.PrimaryPart
				local light = root and root:FindFirstChild("NightGlow")
				if light then
					light:Destroy()
				end
			end
		end
	end
end

function CoralRenderer.start()
	-- Rainbow corals cycle their hue smoothly.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 20 then
			return
		end
		accumulator = 0
		local t = os.clock()
		for _, entry in entries do
			-- Ready corals pulse.
			if entry.readyGlow then
				local pulse = (math.sin(t * 3.2) + 1) / 2
				entry.readyGlow.light.Brightness = if entry.ready then 0.6 + pulse * 1.4 else 0
				entry.readyGlow.ring.Transparency = if entry.ready then 0.55 + (1 - pulse) * 0.35 else 1
			end
			if entry.rainbow then
				for i, part in entry.rainbow do
					part.Color = Color3.fromHSV((t * 0.15 + i * 0.07) % 1, 0.6, 1)
				end
			end
		end
	end)
	CollectionService:GetInstanceAddedSignal("ReefSlot"):Connect(onTileAdded)
	CollectionService:GetInstanceRemovedSignal("ReefSlot"):Connect(onTileRemoved)
	for _, tile in CollectionService:GetTagged("ReefSlot") do
		onTileAdded(tile)
	end
end

return CoralRenderer
