-- Collection book rewards. A page pays its Shells once, after every entry on
-- it has been discovered. Clients only ask; the server checks everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local BookService = {}

local lastClaim: { [Player]: number } = {}

local function onClaim(player: Player, pageId: unknown)
	if type(pageId) ~= "string" or os.clock() - (lastClaim[player] or 0) < 0.5 then
		return
	end
	lastClaim[player] = os.clock()
	local data = PlayerStore.get(player)
	if not data or data.bookClaimed[pageId] then
		return
	end
	for _, page in Balance.book do
		if page.id == pageId then
			local entries, kind = page.entries, page.kind
			for _, id in entries do
				if not data.discovered[kind][id] then
					return
				end
			end
			data.bookClaimed[pageId] = true
			player:SetAttribute("Claimed_" .. pageId, true)
			ReefService.addCurrency(player, 0, page.rewardShells, "Book_" .. pageId)
			ReefService.toast(player, string.format("%s page complete: +%d shells!", page.title, page.rewardShells), "unlock")
			return
		end
	end
end

function BookService.start()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "ClaimBookPage"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote.OnServerEvent:Connect(onClaim)
	PlayerStore.Loaded:Connect(function(player)
		local data = PlayerStore.get(player)
		if data then
			for pageId in data.bookClaimed do
				player:SetAttribute("Claimed_" .. pageId, true)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)
end

return BookService
