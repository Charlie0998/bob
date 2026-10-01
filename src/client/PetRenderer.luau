-- Draws every player's pet (chosen in the collection book) following them
-- just behind the shoulder: it trails smoothly, bobs, and faces where it's
-- going. Everyone sees everyone's pets; all parts move in one bulk call.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)

local FOLLOW_OFFSET = Vector3.new(2.4, 2.2, 2.2) -- right, up, behind
local FOLLOW_SPEED = 5
local VISIBLE_DISTANCE = 150

type Pet = {
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
	roles: { string },
	position: Vector3,
	facing: Vector3,
	phase: number,
}

local PetRenderer = {}

local pets: { [Player]: Pet } = {}
local folder = Instance.new("Folder")
folder.Name = "Pets"

local function clear(player: Player)
	local pet = pets[player]
	if pet then
		pets[player] = nil
		pet.model:Destroy()
	end
end

local function refresh(player: Player)
	clear(player)
	local id = player:GetAttribute("Pet")
	local def = type(id) == "string" and Balance.creatures[id]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not def or not root then
		return
	end
	local model = CreatureModels.build(def.kind, def.color, def.accent)
	model:ScaleTo(Balance.pets.scale * (if def.kind == "shark" or def.kind == "ray" then 0.5 else 1))
	local base = (model.PrimaryPart :: BasePart).CFrame
	local pet: Pet = {
		model = model,
		parts = {},
		offsets = {},
		roles = {},
		position = root.Position + FOLLOW_OFFSET,
		facing = root.CFrame.LookVector,
		phase = math.random() * math.pi * 2,
	}
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(pet.parts, part)
			table.insert(pet.offsets, base:ToObjectSpace(part.CFrame))
			table.insert(pet.roles, part.Name)
		end
	end
	model.Parent = folder
	pets[player] = pet
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Pet"):Connect(function()
		refresh(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		refresh(player)
	end)
	player.CharacterRemoving:Connect(function()
		clear(player)
	end)
	if player.Character then
		task.spawn(refresh, player)
	end
end

function PetRenderer.start()
	folder.Parent = workspace
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	local camera = workspace.CurrentCamera
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		table.clear(parts)
		table.clear(frames)
		for player, pet in pets do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or (root.Position - camera.CFrame.Position).Magnitude > VISIBLE_DISTANCE then
				continue
			end
			local target = (root.CFrame * CFrame.new(FOLLOW_OFFSET)).Position
			local previous = pet.position
			pet.position = previous:Lerp(target, math.min(1, dt * FOLLOW_SPEED))
			local moved = pet.position - previous
			if moved.Magnitude > 0.02 then
				pet.facing = pet.facing:Lerp(moved.Unit, math.min(1, dt * 6))
			else
				pet.facing = pet.facing:Lerp(root.CFrame.LookVector, math.min(1, dt * 2))
			end
			local flat = Vector3.new(pet.facing.X, 0, pet.facing.Z)
			if flat.Magnitude < 0.01 then
				flat = root.CFrame.LookVector
			end
			local bob = Vector3.new(0, math.sin(t * 2 + pet.phase) * 0.3, 0)
			local body = CFrame.lookAt(pet.position + bob, pet.position + bob + flat)
			local wiggle = math.sin(t * 8 + pet.phase)
			for i, part in pet.parts do
				local role = pet.roles[i]
				local pose = if role == "Tail" then CFrame.Angles(0, wiggle * 0.45, 0)
					elseif role == "Fin" then CFrame.Angles(0, 0, wiggle * 0.3)
					elseif role == "Tentacle" then CFrame.Angles(wiggle * 0.25, 0, 0)
					else CFrame.identity
				parts[#parts + 1] = part
				frames[#frames + 1] = body * pet.offsets[i] * pose
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return PetRenderer
