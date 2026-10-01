-- Draws the server's message bottles (bobbing and turning in the water) and
-- hidden treasure chests (half-buried, sparkling). Finds this player has
-- already claimed are hidden.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DecorModels = require(ReplicatedStorage.Shared.DecorModels)

local player = Players.LocalPlayer

local FindsRenderer = {}

type Find = { anchor: BasePart, model: Model, parts: { BasePart }, offsets: { CFrame }, bottle: boolean, phase: number }
local finds: { [BasePart]: Find } = {}
local folder = Instance.new("Folder")
folder.Name = "Finds"

local function newPart(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = model
	return p
end

local function bottleModel(): Model
	local model = Instance.new("Model")
	local root = newPart(model, { Name = "Root", Size = Vector3.one * 0.2, Transparency = 1 })
	model.PrimaryPart = root
	newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 1, 1), CFrame = CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(120, 200, 150), Material = Enum.Material.Glass, Transparency = 0.35 })
	newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 0.45, 0.45), CFrame = CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(120, 200, 150), Material = Enum.Material.Glass, Transparency = 0.35 })
	newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 0.42, 0.42), CFrame = CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.Wood })
	local paper = newPart(model, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 0.4, 0.4), CFrame = CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 170)
	light.Range = 8
	light.Parent = paper
	return model
end

local function isClaimed(id: string): boolean
	for claimed in string.gmatch(player:GetAttribute("ClaimedFinds") or "", "[^,]+") do
		if claimed == id then
			return true
		end
	end
	return false
end

local function onAdded(anchor: Instance)
	if not anchor:IsA("BasePart") or finds[anchor] then
		return
	end
	local bottle = anchor:GetAttribute("Kind") == "bottle"
	local model = if bottle then bottleModel() else DecorModels.build("TreasureChest")
	if not bottle then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new(0.5, 0)
		sparkle.Rate = 4
		sparkle.Speed = NumberRange.new(1, 3)
		sparkle.Parent = model.PrimaryPart
	end
	local root = (model.PrimaryPart :: BasePart).CFrame
	local find: Find = { anchor = anchor, model = model, parts = {}, offsets = {}, bottle = bottle, phase = math.random() * 6 }
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = false
			table.insert(find.parts, p)
			table.insert(find.offsets, root:ToObjectSpace(p.CFrame))
		end
	end
	model.Parent = if isClaimed(anchor:GetAttribute("FindId") :: string? or "") then nil else folder
	finds[anchor] = find
end

local function onRemoved(anchor: Instance)
	local find = finds[anchor :: BasePart]
	if find then
		finds[anchor :: BasePart] = nil
		find.model:Destroy()
	end
end

function FindsRenderer.start()
	folder.Parent = workspace
	CollectionService:GetInstanceAddedSignal("ReefFind"):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal("ReefFind"):Connect(onRemoved)
	for _, anchor in CollectionService:GetTagged("ReefFind") do
		onAdded(anchor)
	end
	player:GetAttributeChangedSignal("ClaimedFinds"):Connect(function()
		for anchor, find in finds do
			find.model.Parent = if isClaimed(anchor:GetAttribute("FindId") :: string? or "") then nil else folder
		end
	end)

	local camera = workspace.CurrentCamera
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		table.clear(parts)
		table.clear(frames)
		for anchor, find in finds do
			if not find.model.Parent or (anchor.Position - camera.CFrame.Position).Magnitude > 250 then
				continue
			end
			local frame = if find.bottle
				then CFrame.new(anchor.Position + Vector3.new(0, math.sin(t * 1.4 + find.phase) * 0.6, 0)) * CFrame.Angles(0.5 + math.sin(t + find.phase) * 0.2, t * 0.4, 0)
				else CFrame.new(anchor.Position - Vector3.new(0, 1.2, 0)) * CFrame.Angles(0.12, find.phase, 0.08)
			for i, p in find.parts do
				parts[#parts + 1] = p
				frames[#frames + 1] = frame * find.offsets[i]
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return FindsRenderer
