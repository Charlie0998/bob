-- Draws visiting creatures at the server's tappable anchor parts and animates
-- them: swimmers circle and bob with wiggling tails and fins, crawlers wander
-- on the sand. All parts move in one BulkMoveTo call per frame.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)

local ARRIVE_SECONDS = 1.2
local LEAVE_SECONDS = 1.1

type Entry = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
	roles: { string },
	crawler: boolean,
	ground: number,
	phase: number,
	born: number,
	leaving: number?,
	hop: number,
}

local CreatureRenderer = {}

local entries: { [BasePart]: Entry } = {}
local folder = Instance.new("Folder")
folder.Name = "Creatures"

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- Skip invisible non-solid parts such as the slots' tap boxes.
rayParams.RespectCanCollide = true

local function onAdded(instance: Instance)
	if not instance:IsA("BasePart") or entries[instance] then
		return
	end
	local anchor = instance :: BasePart
	local def = Balance.creatures[anchor:GetAttribute("CreatureId")]
	if not def then
		return
	end
	local model = CreatureModels.build(def.kind, def.color, def.accent)
	local root = model.PrimaryPart :: BasePart
	local entry: Entry = {
		model = model,
		parts = {},
		offsets = {},
		roles = {},
		crawler = CreatureModels.isCrawler(def.kind),
		ground = anchor.Position.Y,
		phase = math.random() * math.pi * 2,
		born = os.clock(),
		leaving = nil,
		hop = 0,
	}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(entry.parts, part)
			table.insert(entry.offsets, root.CFrame:ToObjectSpace(part.CFrame))
			table.insert(entry.roles, part.Name)
		end
	end
	if entry.crawler then
		rayParams.FilterDescendantsInstances = { folder, anchor }
		local hit = workspace:Raycast(anchor.Position, Vector3.new(0, -12, 0), rayParams)
		entry.ground = if hit then hit.Position.Y else anchor.Position.Y - 2
	end
	model.Parent = folder
	entries[anchor] = entry
end

local function onRemoved(instance: Instance)
	local entry = entries[instance :: BasePart]
	if entry then
		entries[instance :: BasePart] = nil
		entry.model:Destroy()
	end
end

local function rootFrame(anchor: BasePart, entry: Entry, t: number): CFrame
	local age = t - entry.born
	local arrive = 1 - math.clamp(age / ARRIVE_SECONDS, 0, 1) -- 1 -> 0 while arriving
	local leave = if entry.leaving then math.clamp((t - entry.leaving) / LEAVE_SECONDS, 0, 1) else 0
	local center = anchor.Position
	if entry.crawler then
		-- Shuffle side to side on the sand.
		local x = math.sin(t * 0.6 + entry.phase) * 1.2
		local base = Vector3.new(center.X + x, entry.ground + entry.hop, center.Z)
		local facing = if math.cos(t * 0.6 + entry.phase) >= 0 then -1 else 1
		return CFrame.new(base + Vector3.new(0, arrive * 4 + leave * 4, 0)) * CFrame.Angles(0, facing * math.pi / 2, 0)
	end
	-- Circle the anchor, bobbing gently; arrive from above, leave upward.
	local angle = entry.phase + t * 0.7
	local radius = 1.4
	local position = center
		+ Vector3.new(math.cos(angle) * radius, math.sin(t * 1.3 + entry.phase) * 0.4 + entry.hop, math.sin(angle) * radius)
		+ Vector3.new(0, arrive * 8 + leave * 12, 0)
	local heading = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	return CFrame.lookAt(position, position + heading)
end

local function poseFor(role: string, t: number, phase: number): CFrame
	if role == "Tail" then
		return CFrame.Angles(0, math.sin(t * 8 + phase) * 0.45, 0)
	elseif role == "Fin" then
		return CFrame.Angles(0, 0, math.sin(t * 3 + phase) * 0.35)
	elseif role == "Tentacle" or role == "Leg" then
		return CFrame.Angles(math.sin(t * 4 + phase) * 0.25, 0, 0)
	end
	return CFrame.identity
end

-- Played by Effects when someone feeds a creature.
function CreatureRenderer.hop(anchor: BasePart)
	local entry = entries[anchor]
	if entry then
		task.spawn(function()
			for i = 1, 10 do
				entry.hop = math.sin(i / 10 * math.pi) * 1.2
				task.wait(0.03)
			end
			entry.hop = 0
		end)
	end
end

function CreatureRenderer.leave(anchor: BasePart)
	local entry = entries[anchor]
	if entry then
		entry.leaving = os.clock()
	end
end

function CreatureRenderer.start()
	folder.Parent = workspace
	CollectionService:GetInstanceAddedSignal("ReefCreature"):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal("ReefCreature"):Connect(onRemoved)
	for _, anchor in CollectionService:GetTagged("ReefCreature") do
		onAdded(anchor)
	end

	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		table.clear(parts)
		table.clear(frames)
		for anchor, entry in entries do
			local root = rootFrame(anchor, entry, t)
			for i, part in entry.parts do
				parts[#parts + 1] = part
				frames[#frames + 1] = root * entry.offsets[i] * poseFor(entry.roles[i], t, entry.phase)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return CreatureRenderer
