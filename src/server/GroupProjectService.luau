-- Server-wide reef restoration projects. Everyone on the server works toward
-- one shared goal; when it's done, every contributor gets Shells and a coral,
-- and a new project starts. Progress is per server and not saved.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local ReefService = require(script.Parent.ReefService)

local CONFIG = Balance.groupProject

local GroupProjectService = {}

local index = 0
local current: { text: string, activity: string, target: number }? = nil
local progress = 0
local contributors: { [Player]: number } = {}

local function publish()
	if not current then
		return
	end
	ReplicatedStorage:SetAttribute("ProjectText", string.format(current.text, current.target))
	ReplicatedStorage:SetAttribute("ProjectProgress", progress)
	ReplicatedStorage:SetAttribute("ProjectTarget", current.target)
end

local function nextProject()
	index = index % #CONFIG.projects + 1
	local template = CONFIG.projects[index]
	-- Bigger servers get bigger goals.
	local scale = math.max(1, #Players:GetPlayers() * CONFIG.perPlayerScale)
	current = { text = template.text, activity = template.activity, target = math.ceil(template.target * scale) }
	progress = 0
	contributors = {}
	publish()
end

local function complete()
	local coralName = Balance.corals[CONFIG.rewardCoral].displayName
	for player in contributors do
		if player.Parent then
			ReefService.addCurrency(player, 0, CONFIG.rewardShells, "GroupProject")
			ReefService.addInventory(player, CONFIG.rewardCoral, 1)
			ReefService.toast(player, string.format("Reef project complete! +%d shells and a %s", CONFIG.rewardShells, coralName), "unlock")
		end
	end
	nextProject()
end

local function onActivity(player: Player, kind: string, amount: number)
	if not current or kind ~= current.activity then
		return
	end
	progress += amount
	contributors[player] = (contributors[player] or 0) + amount
	if progress >= current.target then
		complete()
	else
		publish()
	end
end

function GroupProjectService.start()
	nextProject()
	ReefService.Activity:Connect(onActivity)
	Players.PlayerRemoving:Connect(function(player)
		contributors[player] = nil
	end)
end

return GroupProjectService
