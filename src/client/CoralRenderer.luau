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
	readyFx: ParticleEmitter?,
	scale: number,
	animating: boolean,
}

local CoralRenderer = {}

local entries: { [BasePart]: Entry } = {}

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
	local entry: Entry = { model = nil, readyFx = nil, scale = 1, animating = false }
	entries[tile] = entry
	rebuild(tile, entry)
	tile:GetAttributeChangedSignal("CoralType"):Connect(function()
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

function CoralRenderer.topOf(tile: BasePart): Vector3
	local entry = entries[tile]
	local height = if entry and entry.model then 3.5 * entry.scale else 1
	return uprightFrame(tile).Position + Vector3.new(0, height, 0)
end

function CoralRenderer.start()
	CollectionService:GetInstanceAddedSignal("ReefSlot"):Connect(onTileAdded)
	CollectionService:GetInstanceRemovedSignal("ReefSlot"):Connect(onTileRemoved)
	for _, tile in CollectionService:GetTagged("ReefSlot") do
		onTileAdded(tile)
	end
end

return CoralRenderer
