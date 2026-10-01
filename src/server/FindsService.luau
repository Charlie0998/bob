-- Floating message bottles and hidden treasure chests around the map. Each
-- player can claim each one once for a small Shell reward; every 20 minutes
-- they all move to new spots. Placement and rewards are decided here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local ReefService = require(script.Parent.ReefService)

local CONFIG = Balance.finds
local REACH = 14

local FindsService = {}

local folder = Instance.new("Folder")
folder.Name = "Finds"
local claimed: { [Player]: { [string]: boolean } } = {}
local rng = Random.new()
local generation = 0

local function spotClear(position: Vector3): boolean
	for _, zone in Balance.zones do
		if (position - Vector3.new(zone.center[1], 0, zone.center[2])).Magnitude < 130 then
			return false
		end
	end
	for _, radius in { 100, 180 } do
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			if (position - Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)).Magnitude < 40 then
				return false
			end
		end
	end
	return true
end

local function randomSpot(): Vector3
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(CONFIG.minRadius, CONFIG.maxRadius)
		local position = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if spotClear(position) then
			return position
		end
	end
	return Vector3.new(0, 0, CONFIG.minRadius)
end

-- Chests hide near landmarks; bottles drift anywhere.
local function chestSpot(): Vector3
	local names = {}
	for name in Balance.world.landmarks do
		if name ~= "lighthouse" then
			table.insert(names, name)
		end
	end
	local cfg = Balance.world.landmarks[names[rng:NextInteger(1, #names)]]
	local a = math.rad(cfg.angle)
	local center = Vector3.new(math.cos(a) * cfg.radius, 0, math.sin(a) * cfg.radius)
	local around = rng:NextNumber(0, math.pi * 2)
	return center + Vector3.new(math.cos(around), 0, math.sin(around)) * (cfg.size + rng:NextNumber(2, 8))
end

local function publishClaims(player: Player)
	local list = {}
	local map: { [string]: boolean } = claimed[player] or {}
	for id in map do
		table.insert(list, id)
	end
	player:SetAttribute("ClaimedFinds", table.concat(list, ","))
end

local function place(kind: "bottle" | "chest", index: number)
	local id = string.format("%s%d_%d", kind, index, generation)
	local position = if kind == "chest" then chestSpot() else randomSpot()
	local anchor = Instance.new("Part")
	anchor.Name = id
	anchor.Size = Vector3.new(3, 3, 3)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(position + Vector3.new(0, if kind == "bottle" then rng:NextNumber(4, 9) else 0.8, 0))
	anchor:SetAttribute("FindId", id)
	anchor:SetAttribute("Kind", kind)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = if kind == "bottle" then "Read message" else "Open chest"
	prompt.ObjectText = if kind == "bottle" then "Message in a bottle" else "Hidden treasure"
	prompt.HoldDuration = if kind == "chest" then 0.6 else 0
	prompt.MaxActivationDistance = REACH
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		local mine = claimed[player]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not mine or mine[id] or not root or (root.Position - anchor.Position).Magnitude > REACH + 4 then
			return
		end
		mine[id] = true
		local range = if kind == "bottle" then CONFIG.bottleShells else CONFIG.chestShells
		local shells = rng:NextInteger(range[1], range[2])
		ReefService.addCurrency(player, 0, shells, "Find_" .. kind)
		ReefService.toast(player, if kind == "bottle" then string.format("The message reads: 'Shells for a friend!' +%d shells", shells) else string.format("Hidden treasure! +%d shells", shells), "unlock")
		ReefService.effect("feed", anchor, shells, player.UserId)
		ReefService.effect("rare", nil, 0, player.UserId)
		publishClaims(player)
	end)
	CollectionService:AddTag(anchor, "ReefFind")
	anchor.Parent = folder
end

local function respawn()
	generation += 1
	folder:ClearAllChildren()
	for i = 1, CONFIG.bottles do
		place("bottle", i)
	end
	for i = 1, CONFIG.chests do
		place("chest", i)
	end
	for player, map in claimed do
		table.clear(map)
		publishClaims(player)
	end
end

function FindsService.start()
	folder.Parent = workspace
	Players.PlayerAdded:Connect(function(player)
		claimed[player] = {}
		publishClaims(player)
	end)
	for _, player in Players:GetPlayers() do
		claimed[player] = {}
	end
	Players.PlayerRemoving:Connect(function(player)
		claimed[player] = nil
	end)
	task.spawn(function()
		while true do
			respawn()
			task.wait(CONFIG.respawnSeconds)
		end
	end)
end

return FindsService
